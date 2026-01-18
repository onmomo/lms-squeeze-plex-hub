package Slim::Schema;
use strict;

our @UPDATE_CALLS;

sub updateOrCreate {
    my ( $class, $args ) = @_;
    push @UPDATE_CALLS, $args;
    return bless { %$args }, 'Slim::Schema::Track';
}

sub reset { @UPDATE_CALLS = (); }

1;
