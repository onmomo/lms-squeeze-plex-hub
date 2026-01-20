package Slim::Utils::Log;
use strict;
use Exporter 'import';
our @EXPORT = qw(logger);

our @DEBUG;
our @INFO;
our @WARN;
our @ERROR;

sub logger { bless {}, 'Slim::Utils::Log::Logger' }

sub reset { @DEBUG=@INFO=@WARN=@ERROR=(); }

package Slim::Utils::Log::Logger;
use strict;

sub debug { push @Slim::Utils::Log::DEBUG, $_[1] }
sub info  { push @Slim::Utils::Log::INFO,  $_[1] }
sub warn  { push @Slim::Utils::Log::WARN,  $_[1] }
sub error { push @Slim::Utils::Log::ERROR, $_[1] }

1;
