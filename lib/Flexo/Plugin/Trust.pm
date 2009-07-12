package Flexo::Plugin::Trust;
use 5.10.0;
use Moses::Plugin;
use Regexp::Common qw(IRC pattern);

use namespace::autoclean;

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

__PACKAGE__->meta->add_method( S_msg    => \&S_bot_addressed );
__PACKAGE__->meta->add_method( S_public => \&S_bot_addressed );

around S_public => sub {
    my $next = shift;
    warn map { $$_ } @_;
    return PCI_EAT_NONE unless $$_[5] =~ s/^opbots[:,]?\s+//i;
    $next->(@_);
};

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
    my $method = $self->can( $command->{method} ) // return;
    return $self->$method($command);
}

sub trust            { 'trust' }
sub check_trust      { 'check trust' }
sub distrust         { 'distrust' }
sub check_distrust   { 'distrust' }
sub believe          { 'believe' }
sub check_believe    { 'check believe' }
sub disbelieve       { 'disbelieve' }
sub check_disbelieve { 'check disbelieve' }
sub spread_ops       { 'spread ops' }

1;
__END__

has model => (
    isa        => 'Flexo::Plugin::Model',
    is         => 'ro',
    lazy_build => 1,
);

sub _build_model { Flexo::Plugin::Model->new( dsn => 'hash' ) }

1;
__END__
