package Flexo::Config;
use 5.10.1;
use Moose;
use namespace::autoclean;
use Bread::Board::Declare;

has channels => (
    isa   => 'ArrayRef',
    is    => 'ro',
    block => sub {
        return ['#orlando'];
    }
);

has autojoin_plugin => (
    isa          => 'POE::Component::IRC::Plugin::AutoJoin',
    is           => 'ro',
    dependencies => { Channels => 'channels' }
);

has nickreclaim_poll => (
    isa   => 'Int',
    is    => 'ro',
    value => 30
);

has nickreclaim_plugin => (
    isa          => 'POE::Component::IRC::Plugin::NickReclaim',
    is           => 'ro',
    dependencies => { poll => 'nickreclaim_poll', }
);

has trust_file => (
    isa   => 'Str',
    is    => 'ro',
    value => 'trust.yml'
);

has model => (
    isa          => 'Flexo::Trust::Simple',
    is           => 'ro',
    dependencies => { filename => 'trust_file' },
);

has trust_plugin => (
    isa          => 'Flexo::Plugin::Trust',
    is           => 'ro',
    lifecycle    => 'Singleton',
    dependencies => [qw(model bot)]
);

has plugins => (
    isa       => 'HashRef',
    is        => 'ro',
    lifecycle => 'Singleton',
    block     => sub {
        my ( $s, $self ) = @_;
        return {

            # core plugins
            'Core::Connector'    => 'POE::Component::IRC::Plugin::Connector',
            'Core::BotAddressed' => 'POE::Component::IRC::Plugin::BotAddressed',
            'Core::AutoJoin'     => $s->param('autojoin_plugin'),
            'Core::NickReclaim'  => $s->param('nickreclaim_plugin'),

            # Flexo Specific Plugins
            'Flexo::Plugin::Barfly'   => 'Flexo::Plugin::Barfly',
            'Flexo::Plugin::Dahut'    => 'Flexo::Plugin::Dahut',
            'Flexo::Plugin::Invite'   => 'Flexo::Plugin::Invite',
            'Flexo::Plugin::Roshambo' => 'Flexo::Plugin::Roshambo',
            'Flexo::Plugin::Trust'    => $s->param('trust_plugin'),
        };
    },
    dependencies => [qw(autojoin_plugin nickreclaim_plugin trust_plugin)],
);

has bot => (
    isa          => 'Flexo',
    is           => 'ro',
    lifecycle    => 'Singleton',
    dependencies => [qw(channels plugins)],
);

1;
__END__
