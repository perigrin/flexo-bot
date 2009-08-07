package Flexo::Plugin::Trust;
use 5.10.0;
use Moses::Plugin;
use Regexp::Common qw(IRC pattern);

use namespace::autoclean;

has model => (
    is         => 'ro',
    does       => 'Flexo::Plugin::Trust::API',
    handles    => 'Flexo::Plugin::Trust::API',
    lazy_build => 1,
);

sub _build_model {
    Flexo::Plugin::Trust::SimpleStorage->new_from_trustfile();
}

sub S_bot_addressed {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    return PCI_EAT_NONE unless $$msg;

    my $command = $self->get_command( $$nickstr, $$channel->[0], $$msg );
    return PCI_EAT_NONE unless $command;

    if ( my $return = $self->run_command($command) ) {
        $self->privmsg( $$channel->[0] => $return );
        return PCI_EAT_PLUGIN;
    }

    return PCI_EAT_NONE;
}

__PACKAGE__->meta->add_method( S_msg => \&S_bot_addressed );

sub S_public {
    my ( $self, $irc, $nickstr, $channel, $msg ) = @_;
    return PCI_EAT_NONE unless $$msg && $$msg =~ s/^opbots[:,]?\s+//i;

    my $command = $self->get_command( $$nickstr, $$channel->[0], $$msg );
    return PCI_EAT_NONE unless $command;

    if ( my $return = $self->run_command($command) ) {
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
    given ($msg) {
        when ( $_ =~ $RE{COMMAND}{trust}{-keep} ) {
            warn "trust";
            $command->{method}  = $1;
            $command->{target}  = $2;
            $command->{channel} = $3 // $where;
        }
        when ( $_ =~ $RE{COMMAND}{check}{-keep} ) {
            warn "check";
            $command->{method}  = "check_${1}";
            $command->{target}  = $2;
            $command->{channel} = $3 // $where;
        }
        when ( $_ =~ $RE{COMMAND}{spread_ops}{-keep} ) {
            warn "spread ops";
            $command->{method} = 'spread_ops';
            $command->{channel} = $2 // $where;
        }
        default { warn "$msg doesn't match"; return; };
    }
    return $command;
}

#
# COMMANDS
#

sub run_command {
    my ( $self, $command ) = @_;
    my $method        = $self->can( $command->{method} )        // return;
    my $output        = $self->$method($command)                // return;
    my $method_output = $self->can("$command->{method}_output") // return;
    return $self->$method_output($output);
}

sub trust_output {
    my ( $self, $output ) = @_;
    return "Okay I have trusted $output->{target}" if $output->{return_value};
    return "Sorry, I can't trust $output->{target}";
}

sub check_trust_output {
    my ( $self, $output ) = @_;
    return "Yes I trust $output->{target}" if $output->{return_value};
    return "No I don't trust $output->{target}";
}

sub spread_ops { 'spread ops' }

1;
__END__
