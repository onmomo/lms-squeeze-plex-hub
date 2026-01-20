package Slim::Control::Request;
use strict;
our @NOTIFY;

sub notifyFromArray { push @NOTIFY, [ @_ ]; 1 }
sub reset { @NOTIFY = (); }

1;
