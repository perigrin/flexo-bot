package Flexo;
use Moses;
use namespace::autoclean;

server 'irc.perl.org';
channels '#orlando';

use Flexo::Invite;

plugins(
    FlexoInvite => 'Flexo::Invite',
    FlexoDahut  => 'Flexo::Dahut',
    FlexoBarfly => 'Flexo::Barfly',
);

__PACKAGE__->run unless caller;

1;
__END__
