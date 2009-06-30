package Flexo::Plugin::Roshambo;
use Moses::Plugin;
use Games::Roshambo;
use List::Util qw(shuffle);

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
        'I choose _CHOICE_ ... the winner is _WINNER_.',
    ];
}

sub line {
    my ( $self, $winner, $choice ) = @_;
    my ($line) = shuffle $self->lines;
    $line =~ s/_WINNER_/$winner/g;
    $line =~ s/_CHOICE_/$choice/g;
    return $line;
}

has rps => (
    isa        => 'Games::Roshambo',
    is         => 'ro',
    lazy_build => 1,
    handles    => [qw(judge)],
);

sub _build_rps { Games::Roshambo->new( numthrows => 101 ) }

sub play {
    my ( $self, $you, $from ) = @_;
    my $me = $self->rps->gen_throw;
    my $winner = ( 'nobody', $from, $self->nick )[ $self->judge( $you, $me ) ];
    return $self->line( $winner, $self->rps->num_to_name($me), );
}

sub S_msg {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    my $choice = $self->rps->name_to_num($$message);
    return PCI_EAT_NONE unless $choice;

    my $channel = $$channels->[0] || '';
    my $result = $self->play( $choice, parse_user($$nickstring) );
    $self->privmsg( $channel => $result );
    return PCI_EAT_PLUGIN;
}

__PACKAGE__->meta->add_method( S_bot_addressed => \&S_msg );

1;
__END__
