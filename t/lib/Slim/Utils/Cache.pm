package Slim::Utils::Cache;
use strict;

sub new { bless { store => {} }, shift }

sub get {
    my ( $self, $k ) = @_;
    return $self->{store}{$k};
}

sub set {
    my ( $self, $k, $v, $ttl ) = @_;
    $self->{store}{$k} = $v;
    $self->{store}{"__ttl__:$k"} = $ttl;
    return 1;
}

sub ttl_for {
    my ( $self, $k ) = @_;
    return $self->{store}{"__ttl__:$k"};
}

1;
