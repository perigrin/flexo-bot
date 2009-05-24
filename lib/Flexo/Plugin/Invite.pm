package Flexo::Plugin::Invite;
use Moses::Plugin;
use namespace::autoclean;

events qw(invite bot_addressed);

sub S_invite {
    my ( $self, $irc, $nickstr, $channel ) = @_;
    $irc->yield( join => $$channel );
    return PCI_EAT_PLUGIN;
}

sub S_bot_addressed {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    if ( $$msg =~ /^join (\#.*)/ ) {
        $irc->yield( join => $1 );
        return PCI_EAT_PLUGIN;
    }
    return PCI_EAT_NONE;
}

1;
__END__
