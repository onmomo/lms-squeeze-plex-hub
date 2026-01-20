package Plugins::SqueezePlexHub::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::SqueezePlexHub::ProtocolHandler;

my $log = Slim::Utils::Log->addLogCategory(
    {
        'category'     => 'plugin.squeezeplexhub',
        'defaultLevel' => 'WARN',
        'description'  => 'PLUGIN_SQUEEZEPLEXHUB'
    }
);
my $prefs = preferences('plugin.squeezeplexhub');

sub initPlugin {
    my $class = shift;

    $class->SUPER::initPlugin();

    $log->info('LMS Squeeze Plex Hub plugin initialized');
    return 1;
}

sub getDisplayName { 'PLUGIN_SQUEEZEPLEXHUB' }

1;
