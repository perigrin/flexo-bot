package Flexo;
use Moses;

use Module::Pluggable (
    search_path => ["Flexo::Plugin"],
    except      => ['Flexo::Plugin::Roshambo'],
    sub_name    => 'plugin_classes',
);

server 'irc.perl.org';
channels qw(
	#chart-clicker
	#moose-dev
	#axkit-dahut
);

sub custom_plugins {
    return { map { $_ => $_ } $_[0]->plugin_classes };
}

no Moses;
1;
__END__
