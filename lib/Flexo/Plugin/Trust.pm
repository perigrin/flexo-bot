package Flexo::Plugin::Trust;
use Moses::Plugin;
use namespace::autoclean;

use MooseX::Aliases;
use Regexp::Common qw(IRC pattern);

has model => (
    does    => 'Flexo::Trust::API',
    handles => 'Flexo::Trust::API',
);

sub S_nick_sync {
    my ( $self, $nickstr, $channel ) = @_[ OBJECT, ARG0, ARG1 ];
    ( $nickstr, $channel ) = ( $$nickstr, $$channel );
    my $ret = $self->check_trust(
        {
            target  => $nickstr,
            channel => $channel->[0],
        }
    );
    if ( $ret->{return_value} ) {
        $self->bot->yield( mode => $nickstr => $channel => '+o' );
    }
    return PCI_EAT_NONE;
}

sub S_chan_sync {
    $_[OBJECT]->spread_ops( { channel => $$_[ARG0]->[0] } );
    return PCI_EAT_NONE;
}

sub S_bot_addressed {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    return PCI_EAT_NONE unless $$msg;

    my $command = $self->get_command( $$nickstr, $$channel->[0], $$msg );
    return PCI_EAT_NONE unless $command;

    if ( my $return = $self->run_command($command) ) {
        $self->spread_ops( { channel => $$channel->[0] } );
        $self->privmsg( $$channel->[0] => $return );
        return PCI_EAT_PLUGIN;
    }

    return PCI_EAT_NONE;
}

alias S_msg => 'S_bot_addressed';

sub S_public {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    return PCI_EAT_NONE unless $$msg && $$msg =~ s/^opbots[:,]?\s+//i;

    my $command = $self->get_command( $$nickstr, $$channel->[0], $$msg );
    return PCI_EAT_NONE unless $command;

    if ( my $return = $self->run_command($command) ) {
        $self->spread_ops( { channel => $$channel->[0] } );
        $self->privmsg( $$channel->[0] => $return );
        return PCI_EAT_PLUGIN;
    }

    return PCI_EAT_NONE;
}

#
# PARSER
#

# REGEXES
my $NICK            = $RE{IRC}{nick}{-keep}{ -count => 20 };
my $CHANNEL         = $RE{IRC}{channel}{-keep};
my $COMMAND         = q[(?k:trust|distrust|believe|disbelieve)];
my $in_channel      = qq[(?:in\\s+$CHANNEL)?];
my $spread_the_love = q[(?:spread\s+(?:the\s+love|ops))];
my $check           = q[(?:do\\s+you|check)];
pattern
  name   => [qw(COMMAND trust -keep)],
  create => qq[^$COMMAND\\s+$NICK\\s*${in_channel}[?.!]*],
  ;

pattern
  name   => [qw(COMMAND check -keep)],
  create => qq[^$check\\s+$COMMAND\\s+$NICK\\s*${in_channel}[?.!]*],
  ;

pattern
  name   => [qw(COMMAND spread_ops -keep)],
  create => qq[^(?:$spread_the_love|names)\\s*${in_channel}[?.!]*],
  ;

sub get_command {
    my ( $self, $nickstr, $where, $msg ) = @_;
    my $command = { by => $nickstr };
    for ($msg) {
        if ( $_ =~ $RE{COMMAND}{trust}{-keep} ) {
            warn "trust";
            $command->{method}  = $1;
            $command->{target}  = $2;
            $command->{channel} = $3 || $where;
        }
        elsif ( $_ =~ $RE{COMMAND}{check}{-keep} ) {
            warn "check";
            $command->{method}  = "check_${1}";
            $command->{target}  = $2;
            $command->{channel} = $3 || $where;
        }
        elsif ( $_ =~ $RE{COMMAND}{spread_ops}{-keep} ) {
            warn "spread ops";
            $command->{method} = 'spread_ops';
            $command->{channel} = $2 || $where;
        }
        else { warn "$msg doesn't match"; return; }
    }
    return $command;
}

#
# COMMANDS
#

sub run_command {
    my ( $self, $command ) = @_;
    my $method_name   = $command->{method};
    my $method        = $self->can($method_name) || return;
    my $output        = $self->$method($command) || return;
    my $method_output = $self->can("${method_name}_output") || return;
    return $self->$method_output($output);
}

sub trust_output {
    my ( $self, $output ) = @_;
    $self->spread_ops;
    return "Okay I have trusted $output->{target}" if $output->{return_value};
    return "Sorry, I can't trust $output->{target}";
}

sub check_trust_output {
    my ( $self, $output ) = @_;
    return "Yes I trust $output->{target}" if $output->{return_value};
    return "No I don't trust $output->{target}";
}

sub believe_output {
    my ( $self, $output ) = @_;
    $self->spread_ops;
    return "Okay I have voiced $output->{target}" if $output->{return_value};
    return "Sorry, I can't voice $output->{target}";
}

sub check_believe_output {
    my ( $self, $output ) = @_;
    return "Yes I believe $output->{target}" if $output->{return_value};
    return "No I don't believe $output->{target}";
}

# TODO: This can be broken up into being POE Session

sub spread_ops {
    my ( $self, $opt ) = @_;
    return unless $self->irc->is_operator( $self->bot->nick );

    my $channel_matrix = $self->matrix->{ $opt->{channel} };
    my @op_list = grep { !$self->irc->is_operator($_) } keys %$channel_matrix;

    while ( my @nicks = splice( @op_list, 0, 4 ) ) {
        my @modes = map { $channel_matrix->{$_} } @nicks;
        $self->irc->yield( mode => join( ' ', @nicks ) => $opt->{channel} =>
              join( ' ', @modes ) );
    }
}

1;
__END__
