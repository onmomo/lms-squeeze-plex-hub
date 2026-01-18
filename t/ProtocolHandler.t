use strict;
use warnings;

use Test::More;
use Test::MockModule;

# Silence "used only once" warnings for test globals
no warnings 'once';

use lib 't/lib';
use lib '.';

require Slim::Schema;    # forces stub load now

# Load the module from the repo layout:
#   SqueezePlexHub/ProtocolHandler.pm
require SqueezePlexHub::ProtocolHandler;

sub reset_state {
    Slim::Music::Info::reset_calls();
    Slim::Utils::Log::reset();

    #Slim::Schema::reset();
}

# Fake client
{

    package t::Client;
    use strict;
    our $UPDATE_COUNT = 0;
    sub new                       { bless {}, shift }
    sub currentPlaylistUpdateTime { $UPDATE_COUNT++; 1 }
    sub reset                     { $UPDATE_COUNT = 0 }
}

# --- _parse_stream_url ---
{
    my $u =
'http://example:32400/library/parts/1/file.flac?X-Plex-Token=abc&squeezePlexHub_rk=57038&foo=1';
    my $r = SqueezePlexHub::ProtocolHandler::_parse_stream_url($u);

    is( $r->{rk},    '57038',                'rk extracted' );
    is( $r->{token}, 'abc',                  'token extracted' );
    is( $r->{base},  'http://example:32400', 'base extracted' );
    like( $r->{clean}, qr/foo=1/, 'clean url keeps other params' );
    unlike( $r->{clean}, qr/squeezePlexHub_rk=/, 'clean url strips rk' );
}

# --- _compose_title ---
{
    reset_state();
    my $t = SqueezePlexHub::ProtocolHandler::_compose_title(
        {
            artist => 'Linkin Park',
            title  => 'H! Vltg3',
        }
    );
    is( $t, 'Linkin Park - H! Vltg3', 'compose title artist - title' );

    my $t2 = SqueezePlexHub::ProtocolHandler::_compose_title(
        {
            title => 'Only Title',
        }
    );
    is( $t2, 'Only Title', 'compose title falls back to title' );
}

# --- explodePlaylist returns clean URL immediately ---
{
    reset_state();
    t::Client::reset();

    my $client = t::Client->new;

    my $uri =
'http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc&squeezePlexHub_rk=57038';
    my $returned;
    SqueezePlexHub::ProtocolHandler->explodePlaylist( $client, $uri,
        sub { $returned = shift } );

    is_deeply(
        $returned,
        ['http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc'],
        'explodePlaylist returns clean URL list'
    );
}

# --- explodePlaylist serves cached metadata, no fetch ---
{
    reset_state();
    t::Client::reset();

    my $client = t::Client->new;

    my $uri =
'http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc&squeezePlexHub_rk=57038';
    my $res = SqueezePlexHub::ProtocolHandler::_parse_stream_url($uri);
    my $key = "sph_meta_$res->{base}_$res->{rk}";

    my $mock = Test::MockModule->new('SqueezePlexHub::ProtocolHandler');
    $mock->redefine(
        '_fetch_plex_track_metadata' => sub { die "fetch should not be called" }
    );

    my $cacheMock = Test::MockModule->new('Slim::Utils::Cache');
    $cacheMock->redefine(
        'get' => sub {
            my ( $self, $k ) = @_;
            return { title => 'CACHED', secs => 1, cover => 'x' } if $k eq $key;
            return undef;
        }
    );

    my $returned;
    SqueezePlexHub::ProtocolHandler->explodePlaylist( $client, $uri,
        sub { $returned = shift } );

    is_deeply(
        $returned,
        ['http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc'],
        'still returns clean url'
    );
    is( scalar(@Slim::Music::Info::CALLS), 1, 'setRemoteMetadata called once' );
    is( $Slim::Music::Info::CALLS[0][1]{title},
        'CACHED', 'cached title applied' );

    $cacheMock->unmock_all();
}

# --- explodePlaylist cache miss -> fetch -> cache set -> metadata set -> schema update ---
{
    reset_state();
    t::Client::reset();

    my $client = t::Client->new;

    my $uri =
'http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc&squeezePlexHub_rk=57038';

    my $mock = Test::MockModule->new('SqueezePlexHub::ProtocolHandler');
    $mock->redefine(
        '_fetch_plex_track_metadata' => sub {
            my ( $cb, $base, $token, $rk ) = @_;

            is( $base,  'http://pms:32400', 'fetch base passed' );
            is( $token, 'abc',              'fetch token passed' );
            is( $rk,    '57038',            'fetch rk passed' );

            $cb->(
                {
                    title    => 'H! Vltg3',
                    artist   => 'Linkin Park',
                    album    => 'Hybrid Theory',
                    year     => '2020',
                    duration => 210,
                    disc     => 2,
                    tracknum => 9,
                    genre    => 'Pop/Rock',
                    icon     =>
'http://pms:32400/library/metadata/57017/thumb/1?X-Plex-Token=abc',
                    cover =>
'http://pms:32400/library/metadata/57017/thumb/1?X-Plex-Token=abc',
                }
            );
        }
    );

    my $cacheSets = [];
    my $cacheMock = Test::MockModule->new('Slim::Utils::Cache');
    $cacheMock->redefine( 'get' => sub { return undef } );
    $cacheMock->redefine(
        'set' => sub {
            my ( $self, $k, $v, $ttl ) = @_;
            push @$cacheSets, [ $k, $v, $ttl ];
            return 1;
        }
    );

    my $returned;
    SqueezePlexHub::ProtocolHandler->explodePlaylist( $client, $uri,
        sub { $returned = shift } );

    is_deeply(
        $returned,
        ['http://pms:32400/library/parts/1/file.flac?X-Plex-Token=abc'],
        'returns clean url'
    );

    is( scalar(@Slim::Music::Info::CALLS), 1, 'setRemoteMetadata called' );
    is(
        $Slim::Music::Info::CALLS[0][1]{title},
        'Linkin Park - H! Vltg3',
        'title composed artist - title'
    );
    is( $Slim::Music::Info::CALLS[0][1]{secs}, 210, 'secs set' );

    ok( @$cacheSets >= 1, 'cache set called' );
    is( $cacheSets->[0][2], 1800, 'cache ttl is 1800' );

    is( scalar(@Slim::Schema::UPDATE_CALLS), 1, 'updateOrCreate called once' );
    my $attrs = $Slim::Schema::UPDATE_CALLS[0]{attributes};
    is( $attrs->{ALBUM},    'Hybrid Theory', 'ALBUM set' );
    is( $attrs->{DISC},     2,               'DISC set' );
    is( $attrs->{TRACKNUM}, 9,               'TRACKNUM set' );
    is( $attrs->{YEAR},     '2020',          'YEAR set' );
    is( $attrs->{GENRE},    'Pop/Rock',      'GENRE set' );

    $cacheMock->unmock_all();
}

# --- _fetch_plex_track_metadata parses genre + masks token in logs ---
{
    reset_state();

    my $xml = <<'XML';
<MediaContainer size="1">
  <Track title="H! Vltg3" grandparentTitle="Linkin Park" parentTitle="Hybrid Theory (20th anniversary edition)"
         index="9" parentIndex="2" parentYear="2020" duration="210733"
         thumb="/library/metadata/57017/thumb/1767442223">
    <Genre tag="Pop/Rock"/>
  </Track>
</MediaContainer>
XML

    # Set response payload
    $Slim::Networking::SimpleAsyncHTTP::NEXT_ERROR   = undef;
    $Slim::Networking::SimpleAsyncHTTP::NEXT_CONTENT = $xml;

    my $got;
    SqueezePlexHub::ProtocolHandler::_fetch_plex_track_metadata(
        sub { $got = shift },
        'http://pms:32400', 'SECRET_TOKEN', '57038' );

    is( $got->{genre}, 'Pop/Rock', 'genre parsed' );
    like( $got->{icon}, qr/X-Plex-Token=SECRET_TOKEN/,
        'icon has token appended' );

    my $dbg = join( "\n", @Slim::Utils::Log::DEBUG );
    like( $dbg, qr/X-Plex-Token=REDACTED/i, 'token masked in debug logs' );
    unlike( $dbg, qr/SECRET_TOKEN/, 'secret token not present in logs' );
}

done_testing;
