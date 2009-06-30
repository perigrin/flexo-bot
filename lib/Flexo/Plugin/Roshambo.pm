package Bender::Games::Roshambo;
use strict;
use warnings;
use Carp;

use version; qv(0.03);
use POE::Component::IRC::Plugin qw(:ALL);
use POE::Component::IRC::Common qw( :ALL );
use Regexp::Common qw(IRC);

use Moose;
with qw(Bender::Role::Storage::YAML);

has depends => ( 
	isa => 'ArrayRef', 
	is => 'ro', 
	auto_deref => 1,
	default => sub { [qw(Bender::Core::BotAddressed)] },
);

has lines => (
	isa => 'ArrayRef',
	is => 'ro',
	auto_deref => 1,
	lazy => 1,
	default => sub { [ map { chomp; $_ } <DATA> ] },
);

sub BUILD {
	my ($self) = @_;
	# alias S_public to S_msg because they do the same thing
	$self->meta->alias_method(S_public => \&S_msg);
	# alias S_irc_bot_addressed to S_msg because they do the same thing
	$self->meta->alias_method(S_bot_addressed => \&S_msg);
}

sub read { 
	my ($self, $data) = @_;
	$self->{data} = $data;
}

sub data { 
	my ($self) = @_;
	return $self->{data};
}

my @MOVES = qw( rock paper scissors );

sub PCI_register {
    my ( $self, $irc ) = @_;
    $self->{irc} = $irc;
    $irc->plugin_register( $self, 'SERVER', qw(bot_addressed public msg) );
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = @_;
    delete $self->{irc};
    return 1;
}

sub choose {
    my ( $self, $what, $where, $from ) = @_;
    my $bot    = $self->{irc};
    my $choice = lc $MOVES[ rand @MOVES ];
    my $me     = $bot->nick_name;
    my $win =
        $choice eq $what ? 'nobody'
      : $choice eq 'rock'     && $what eq 'paper'    ? $from
      : $choice eq 'rock'     && $what eq 'scissors' ? $me
      : $choice eq 'paper'    && $what eq 'rock'     ? $me
      : $choice eq 'paper'    && $what eq 'scissors' ? $from
      : $choice eq 'scissors' && $what eq 'rock'     ? $from
      : $choice eq 'scissors' && $what eq 'paper'    ? $me
      :                                                'nobody';
    my @LINES = $self->lines;
    my ( $action, $line ) = split( /\s+/, $LINES[ rand $#LINES ], 2 );
    $line   =~ s/_WINNER_/$win/g;
    $line   =~ s/_CHOICE_/$choice/g;
    $action =~ s/_/ /g;
    $self->record_winner($win);
    $bot->yield( lc($action) => $where => $line );
    return 1;
}

sub record_winner {
    my ( $self, $winner ) = @_;
    $self->{data}{winners}{$winner}++;
    $self->save();
}

sub S_msg {
    my ( $self, $irc, $nickstring, $channels, $message ) = @_;
    ( $message, $channels ) = ( $$message, $$channels );
    $irc->{plugin_debug} = 1;
    my $channel = $channels->[0] || '';
    my $from    = parse_user($$nickstring);
    my $CMD     = qr/^\s*(rock|paper|scissors)\s*$/i;
    if ( $message =~ $CMD ) {
        $self->choose( lc($1), $channel, $from );
        return PCI_EAT_PLUGIN;
    }
    return PCI_EAT_NONE;
}

1;
__DATA__
PRIVMSG I had _CHOICE_, _WINNER_ wins.
PRIVMSG _WINNER_ wins! (I had _CHOICE_.)
PRIVMSG I chose _CHOICE_ ... the winner is _WINNER_.
