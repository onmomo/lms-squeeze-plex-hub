package Slim::Music::Info;
use strict;

our @CALLS;

sub setRemoteMetadata {
    my ( $url, $meta ) = @_;
    push @CALLS, [ $url, $meta ];
    return 1;
}

sub reset_calls { @CALLS = (); }

1;
