package Flexo::Plugin::Invite;
use Moses::Plugin;
use namespace::autoclean;

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

__PACKAGE__->meta->add_method( S_msg => \&S_bot_addressed );

1;
__END__
