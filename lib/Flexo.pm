package Flexo;
use Moses;

use Module::Pluggable (
    search_path => ["Flexo::Plugin"],
    except      => ['Flexo::Plugin::Trust'],
    sub_name    => 'plugin_classes',
);

server 'irc.perl.org';
channels '#orlando';

sub custom_plugins {
    return { map { $_ => $_ } $_[0]->plugin_classes };
}

__PACKAGE__->run unless caller;

no Moses;
1;
__END__
