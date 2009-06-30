package Flexo::Plugin::Roshambo;
use Moses::Plugin;
use Games::Roshambo;

use namespace::autoclean;

events qw(bot_addressed msg);

has lines => (
    isa        => 'ArrayRef',
    is         => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_lines {
    [
        'I had _CHOICE_, _WINNER_ wins.',
        '_WINNER_ wins! (I had _CHOICE_.)',
        'I chose _CHOICE_ ... the winner is _WINNER_.',
    ];
}

sub line {
    my ( $self, $win, $choice ) = @_;
    my @LINES = $self->lines;
    my $line  = $LINES[ rand $#LINES ];
    $line =~ s/_WINNER_/$win/g;
    $line =~ s/_CHOICE_/$choice/g;
    return $line;
}

has rps => (
    isa        => 'Games::Roshambo',
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw(judge)],
);

sub _build_rps {
    Games::Roshambo->new( numthrows => 101 );
}

sub play {
    my ( $self, $you, $from ) = @_;
    my $me = $self->rps->num_to_name( $self->rps->gen_throw);
    return $self->line( 'nobody',    $me ) if $self->judge( $you, $me ) == 0;
    return $self->line( $from,       $me ) if $self->judge( $you, $me ) == 1;
    return $self->line( $self->nick, $me ) if $self->judge( $you, $me ) == 2;
}

sub S_msg {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my $channel = $$channels->[0] || '';
    if ( $$message =~ qr/^\s*(rock|paper|scissors)\s*$/i ) {
        my $choice = lc($1);
        my $nick   = parse_user($$nickstring);
        $self->privmsg( $channel => $self->play( $choice, $nick ) );
        return PCI_EAT_PLUGIN;
    }
    return PCI_EAT_NONE;
}

__PACKAGE__->meta->add_method( S_bot_addressed => \&S_msg );

1;
__END__
