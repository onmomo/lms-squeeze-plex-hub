package Slim::Networking::SimpleAsyncHTTP;
use strict;

# Test-controlled response payload
our $NEXT_CONTENT = '';
our $NEXT_ERROR   = undef;

sub new {
    my ( $class, $onSuccess, $onError, $opts ) = @_;
    return bless {
        onSuccess => $onSuccess,
        onError   => $onError,
        opts      => $opts || {},
        _content  => '',
        _error    => '',
    }, $class;
}

sub get {
    my ( $self, $url ) = @_;

    if ( defined $NEXT_ERROR ) {
        $self->{_error} = $NEXT_ERROR;
        $self->{onError}->($self);
        return;
    }

    $self->{_content} = $NEXT_CONTENT;
    $self->{onSuccess}->($self);
}

sub content { $_[0]->{_content} }
sub error   { $_[0]->{_error} }

1;
