package Plugins::SqueezePlexHub::ProtocolHandler;

# Protocol handler for URLs with squeezePlexHub_rk: returns cleaned playable URL and asynchronously fetches Plex metadata.
# Parses Plex XML, caches metadata, sets LMS remote metadata and updates playlist item (artwork, album/track info).

use strict;

use base qw(Slim::Formats::RemoteStream);
use Slim::Networking::SimpleAsyncHTTP;

use URI;
use XML::Simple qw(XMLin);
use Slim::Music::Info;
use Time::HiRes ();

use Slim::Utils::Cache;
use Slim::Utils::Log;

my $cache = Slim::Utils::Cache->new();
my $log   = logger('plugin.squeezeplexhub');

# Register our URL handler for URLs containing squeezePlexHub_rk param
use constant SPH_URL_REGEXP => qr/[?&]squeezePlexHub_rk=\d+/i;
Slim::Player::ProtocolHandlers->registerURLHandler( SPH_URL_REGEXP,
    __PACKAGE__ )
  if Slim::Player::ProtocolHandlers->can('registerURLHandler');

sub contentType     { 'sph' }
sub canDirectStream { 0 }

sub requestString {
    my ( $class, $client, $url, $song ) = @_;
    return $url;
}

# Keep the original URL in the playlist (so getMetadataFor keeps working).
sub explodePlaylist {
    my ( $class, $client, $uri, $cb ) = @_;

    my $url_res   = _parse_stream_url($uri);
    my $url_clean = $url_res->{clean};

    unless ( defined $url_clean && $url_clean ne '' ) {
        $log->error(
            "SPH explodePlaylist: clean URL is empty, returning original URI");
        $cb->( [$uri] );
        return;
    }

    # Always return the playable URL immediately
    # Important: use the clean URL without our rk param in order to skip this protocol handler for the actual playback
    $cb->( [$url_clean] );

    my $base  = $url_res->{base} || '';
    my $rk    = $url_res->{rk};
    my $token = $url_res->{token};

    # Not enough info to fetch metadata
    return unless $base && $rk;

    # Cache key per Plex track
    my $metaKey = "sph_meta_${base}_${rk}";

    # Serve cached metadata if available
    if ( my $cached = $cache->get($metaKey) ) {
        if ( ref($cached) eq 'HASH' ) {
            $log->info("SPH: serving cached metadata for rk=$rk, title='"
                  . ( $cached->{title} || '' ) . "'" );
            Slim::Music::Info::setRemoteMetadata( $url_clean, $cached );

            eval {
                $client->currentPlaylistUpdateTime( Time::HiRes::time() )
                  if $client;
                Slim::Control::Request::notifyFromArray( $client,
                    ['newmetadata'] )
                  if $client;
                1;
            };

            return;
        }
    }

    # Fetch metadata async
    _fetch_plex_track_metadata(
        sub {
            my ($m) = @_;
            return unless $m && ref($m) eq 'HASH';

            # setRemoteMetadata supports only certain fields
            my $meta = {
                title => _compose_title($m),

                # seems to have no effect
                year => $m->{year} || '',

                # duration must be in "secs" (seconds, or hh:mm:ss string)
                secs => $m->{duration} || 0,

                # artwork URL
                cover => $m->{cover} || $m->{icon}
            };

            # Cache final LMS metadata
            $cache->set( $metaKey, $meta, 1800 )
              ;    # TTL: 0.5 hours (tune as needed)

            Slim::Music::Info::setRemoteMetadata( $url_clean, $meta );

            # May the LMS gods forgive me for this ... 🙏
            setMetadataForPlaylistItem(
                $url_clean,     $m->{album}, $m->{disc},
                $m->{tracknum}, $m->{year},  $m->{genre}
            );

            eval {
                $client->currentPlaylistUpdateTime( Time::HiRes::time() )
                  if $client;
                Slim::Control::Request::notifyFromArray( $client,
                    ['newmetadata'] )
                  if $client;
                1;
            };
        },
        $base,
        $token,
        $rk
    );
}

sub setMetadataForPlaylistItem {
    my ( $url, $album_name, $disc_number, $track_number, $year, $genre ) = @_;

    my $track = Slim::Schema->updateOrCreate(
        {
            url        => $url,
            attributes => {
                ALBUM    => $album_name,
                TRACKNUM => $track_number,
                DISC     => $disc_number,
                YEAR     => $year,
                GENRE    => $genre                
            },
            readTags => 0,
            commit   => 1
        }
    );

    return $track;
}

# Compose a display title from artist, title, album
sub _compose_title {
    my ($m) = @_;

    my $artist = $m->{artist};
    my $title  = $m->{title} || '';

    my $t = '';

    if ( $artist && $title ) {
        $t = "$artist - $title";
    }
    else {
        $t = $title;
    }

    $log->debug("SPH: composed title: '$t'");
    return $t;
}

sub _parse_stream_url {
    my ($url) = @_;

    my $uri = URI->new($url);
    my %q   = $uri->query_form;

    my $rk    = delete $q{squeezePlexHub_rk};
    my $token = $q{'X-Plex-Token'} || $q{'x-plex-token'};

    # rebuild URL without squeezePlexHub_rk
    $uri->query_form(%q);
    my $clean_url = $uri->as_string;

    my $base = '';
    if ( $url =~ m{^(https?://[^/]+)}i ) {
        $base = $1;
        $base =~ s{/$}{};
    }

    return {
        rk    => $rk,
        token => $token,
        base  => $base,
        clean => $clean_url
    };
}

sub _fetch_plex_track_metadata {
    my ( $cb, $base, $token, $rk ) = @_;

    my $metaUrl = $base . "/library/metadata/$rk";
    if ( $token && $metaUrl !~ /X-Plex-Token=/i ) {
        $metaUrl .= ( $metaUrl =~ /\?/ ? '&' : '?' ) . 'X-Plex-Token=' . $token;
    }

    # Mask token in log output
    my $metaUrlLog = $metaUrl;
    $metaUrlLog =~ s/(X-Plex-Token=)[^&]+/${1}REDACTED/ig;
    $log->debug("SPH: fetching Plex metadata from URL: $metaUrlLog");

    my $http = Slim::Networking::SimpleAsyncHTTP->new(
        sub {
            my ($http) = @_;
            my $content = $http->content || '';

            my $data;
            eval {
                $data = XMLin( $content, ForceArray => 1, KeyAttr => [] );
                1;
            } or do {
                $log->error("SPH: failed to parse Plex XML for rk=$rk: $@");
                $cb->(undef);
                return;
            };

            my $track =
              ( $data->{Track} && ref( $data->{Track} ) eq 'ARRAY' )
              ? $data->{Track}[0]
              : undef;

            if ( !$track ) {
                $cb->(undef);
                return;
            }

            my $title  = $track->{title}            || '';
            my $artist = $track->{grandparentTitle} || '';
            my $album  = $track->{parentTitle}      || '';

            my $tracknum = '';
            $tracknum = $track->{index} if defined $track->{index};

            my $disc = '';
            $disc = $track->{parentIndex} if defined $track->{parentIndex};

            my $year = '';
            if ( defined $track->{parentYear} ) {
                $year = $track->{parentYear};
            }
            elsif ( defined $track->{year} ) {
                $year = $track->{year};
            }

            my $duration = 0;
            if ( $track->{duration} && $track->{duration} =~ /^\d+$/ ) {
                $duration = int( $track->{duration} / 1000 );
            }

            my $thumb = $track->{thumb} || $track->{parentThumb};

            my $icon;
            if ($thumb) {
                $icon = $base . $thumb;
                if ( $token && $icon !~ /X-Plex-Token=/i ) {
                    $icon .=
                      ( $icon =~ /\?/ ? '&' : '?' ) . 'X-Plex-Token=' . $token;
                }
            }

            my $trackMedia =
              ( $track->{Media}
                  && ref( $track->{Media} ) eq 'ARRAY'
                  && @{ $track->{Media} } )
              ? $track->{Media}[0]
              : undef;

            # Parse first Genre tag="..."
            my $genre = '';
            if ( $track->{Genre}
                && ref( $track->{Genre} ) eq 'ARRAY'
                && @{ $track->{Genre} } )
            {
                my $g0 = $track->{Genre}[0];
                if ( ref($g0) eq 'HASH' && defined $g0->{tag} ) {
                    $genre = $g0->{tag} || '';
                }
            }

            # Mask token in icon for logs
            my $iconLog = $icon || '';
            $iconLog =~ s/(X-Plex-Token=)[^&]+/${1}REDACTED/ig;

            $log->debug( "SPH: fetched Plex metadata for rk=$rk: "
                  . "title='$title', artist='$artist', album='$album', "
                  . "year='$year', duration=$duration, tracknum='$tracknum', disc='$disc', "
                  . "genre='$genre', icon='$iconLog'" );

            $cb->(
                {
                    title    => $title,
                    artist   => $artist,
                    album    => $album,
                    year     => $year,
                    duration => $duration,
                    tracknum => $tracknum,
                    disc     => $disc,
                    genre    => $genre,
                    icon     => $icon,
                    cover    => $icon,
                }
            );
        },
        sub {
            my ($http) = @_;
            $log->warn( "SPH: Plex metadata request failed for rk=$rk: "
                  . ( $http->error || 'unknown error' ) );
            $cb->(undef);
        },
        { timeout => 10 }
    );

    $http->get($metaUrl);
}

1;
