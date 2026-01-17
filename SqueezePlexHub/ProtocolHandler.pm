package Plugins::SqueezePlexHub::ProtocolHandler;

use strict;

# Keep squeezePlexHub_rk in the playlist URL for metadata lookup,
# but strip it for the actual stream request.
use base qw(Slim::Formats::RemoteStream);

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
Slim::Player::ProtocolHandlers->registerURLHandler(SPH_URL_REGEXP, __PACKAGE__)
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

    my $url_res     = _parse_stream_url($uri);
    my $url_clean = $url_res->{clean};

    unless (defined $url_clean && $url_clean ne '') {
        $log->error("SPH explodePlaylist: clean URL is empty, returning original URI");
        $cb->([ $uri]);
        return;
    }

    # Always return the playable URL immediately
    # Important: use the clean URL without our rk param in order to skip this protocol handler for the actual playback
    $cb->([ $url_clean ]);    

    # Async fetch metadata to update current track info
    _fetch_plex_track_metadata(sub {
        my ($m) = @_;
        return unless $m && ref($m) eq 'HASH';

        my $tags = {
            title    => $m->{title}    || '',
            artist   => $m->{artist}   || '',
            album    => $m->{album}    || '',
            year     => $m->{year}     || '',
            duration => $m->{duration} || 0,
            cover    => $m->{cover}    || $m->{icon},
            icon     => $m->{icon},
            type     => 'Plex (SqueezePlexHub)',
        };

        # Update current track metadata      
        # TODO consider caching per URL to avoid redundant fetches
        # TODO check if remoteMetadata does support all these tags
        Slim::Music::Info::setRemoteMetadata($url_clean, $tags);

        eval {
            $client->currentPlaylistUpdateTime( Time::HiRes::time() ) if $client;
            Slim::Control::Request::notifyFromArray( $client, [ 'newmetadata' ] ) if $client;
            1;
        };
    }, $url_res->{base}, $url_res->{token}, $url_res->{rk});
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
        rk        => $rk,
        token     => $token,
        base      => $base,
        clean     => $clean_url
    };
}

sub _fetch_plex_track_metadata {
    my ( $cb, $base, $token, $rk ) = @_;

    my $metaUrl = $base . "/library/metadata/$rk";
    if ( $token && $metaUrl !~ /X-Plex-Token=/i ) {
        $metaUrl .= ( $metaUrl =~ /\?/ ? '&' : '?' ) . 'X-Plex-Token=' . $token;
    }

    my $http = Slim::Networking::SimpleAsyncHTTP->new(
        sub {
            my ($http) = @_;
            my $content = $http->content || '';

            my $data;
            eval {
                $data = XMLin( $content, ForceArray => 1, KeyAttr => [] );
                1;
            } or do {
                $log->warn("SPH: failed to parse Plex XML for rk=$rk: $@");
                $cb->(undef);
                return;
            };

            my $track = ($data->{Track} && ref($data->{Track}) eq 'ARRAY') ? $data->{Track}[0] : undef;

            if (!$track) {
                $cb->(undef);
                return;
            }

            my $title  = $track->{title} || '';
            my $artist = $track->{grandparentTitle} || '';
            my $album  = $track->{parentTitle} || '';

            my $tracknum = '';
            $tracknum = $track->{index} if defined $track->{index};

            my $disc = '';
            $disc = $track->{parentIndex} if defined $track->{parentIndex};

            my $year = '';
            if (defined $track->{parentYear}) {
                $year = $track->{parentYear};
            }
            elsif (defined $track->{year}) {
                $year = $track->{year};
            }

            my $duration = 0;
            if ($track->{duration} && $track->{duration} =~ /^\d+$/) {
                $duration = int($track->{duration} / 1000);
            }

            my $thumb = $track->{thumb} || $track->{parentThumb};

            my $icon;
            if ($thumb) {
                $icon = $base . $thumb;
                if ( $token && $icon !~ /X-Plex-Token=/i ) {
                    $icon .= ( $icon =~ /\?/ ? '&' : '?' ) . 'X-Plex-Token=' . $token;
                }
            }

            $log->debug("SPH: fetched Plex metadata for rk=$rk: title='$title', artist='$artist', album='$album', year='$year', duration=$duration, tracknum='$tracknum', disc='$disc', icon='$icon'");

            $cb->({
                title    => $title,
                artist   => $artist,
                album    => $album,
                year     => $year,
                duration => $duration,
                tracknum => $tracknum,
                disc     => $disc,
                icon     => $icon,
                cover    => $icon,
            });
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
