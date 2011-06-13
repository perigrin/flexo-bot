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

has simple_plugins => (
    isa   => 'ArrayRef',
    is    => 'ro',
    block => sub {
        [
            qw(
              Flexo::Plugin::Barfly
              Flexo::Plugin::Dahut
              Flexo::Plugin::Invite
              Flexo::Plugin::Roshambo
              )
        ];
    },
);

has trust_file => (
    isa   => 'Str',
    is    => 'ro',
    value => 'trust.yml'
);

has model => (
    isa          => 'Flexo::Trust::SimpleStorage',
    is           => 'ro',
    dependencies => { filename => 'trust_file' },
);

has trust_plugin => (
    isa          => 'Flexo::Plugin::Trust',
    is           => 'ro',
    lifecycle    => 'Singleton',
    dependencies => [qw(model bot)]
);

has autojoin_plugin => (
    isa          => 'POE::Component::IRC::Plugin::AutoJoin',
    is           => 'ro',
    dependencies => { Channels => 'channels' }
);

use POE::Component::IRC::Plugin::NickReclaim;

has nickreclaim_plugin => (
    isa => 'POE::Component::IRC::Plugin::NickReclaim',
    is  => 'ro',
    block =>
      sub { POE::Component::IRC::Plugin::NickReclaim->new( poll => 30 ), }
);

has plugins => (
    isa       => 'HashRef',
    is        => 'ro',
    lifecycle => 'Singleton',
    block     => sub {
        my ( $s, $self ) = @_;
        my $plugin = {
            'Core::Connector'    => 'POE::Component::IRC::Plugin::Connector',
            'Core::BotAddressed' => 'POE::Component::IRC::Plugin::BotAddressed',
            'Core::AutoJoin'     => $self->autojoin_plugin,
            'Core::NickReclaim'  => $self->nickreclaim_plugin,
            map { $_ => $_ } @{ $self->simple_plugins }
        };

        $plugin->{'Flexo::Plugin::Trust'} = $self->trust_plugin;
        return $plugin;
    },
);

has bot => (
    isa       => 'Flexo',
    is        => 'ro',
    lifecycle => 'Singleton',
    block     => sub {
        my ( $s, $self ) = @_;

        # for some reason this initializer is called twice,
        # despite being a Singleton
        # so we use a state variable here to force a true singleton
        state $bot = Flexo->new(
            channels => $s->param('channels'),
            plugins  => $s->param('plugins'),
        );
        $bot;
    },
    dependencies => [qw(channels plugins)],
);

1;
__END__
