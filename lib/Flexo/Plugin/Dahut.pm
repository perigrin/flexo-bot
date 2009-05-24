package Flexo::Plugin::Dahut;
use Moses::Plugin;
use namespace::autoclean;

events qw(public);

use Acme::Dahut::Call;
use Acme::Dahut::Call::Identifier;

has fauxhut => (
    isa        => 'Acme::Dahut::Call',
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw(call)],
);

sub _build_fauxhut { Acme::Dahut::Call->new() }

has identifier => (
    isa        => 'Acme::Dahut::Call::Identifier',
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw(is_call)],
);

sub _build_identifier { Acme::Dahut::Call::Identifier->new() }

sub S_public {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    if ( $self->is_call($$msg) ) {
        $irc->yield( privmsg => $$channel, $self->call );
        return PCI_EAT_PLUGIN;
    }
    return PCI_EAT_NONE;
}

1;
__END__
