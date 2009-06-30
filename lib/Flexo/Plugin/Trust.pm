package Flexo::Plugin::Trust;
use 5.10.0;
use Moses::Plugin;

use Regexp::Common qw(IRC pattern);

has untrusted_channels => (
    isa        => 'HashRef[Str]',
    is         => 'ro',
    lazy_build => 1,
    metaclass  => 'Collection::Hash',
    provides   => { exists => 'is_untrusted_channel' },
);

sub build_untrusted_channels => ( { '#perl' => 1, } );

has model => (
    isa        => 'Flexo::Plugin::Model',
    is         => 'ro',
    lazy_build => 1,
);

sub _build_model { Flexo::Plugin::Model->new( dsn => 'hash' ) }

##########################
# Plugin related methods #
##########################

# REGEXES
my $NICK            = $RE{IRC}{nick}{-keep}{ -count => 20 };
my $CHANNEL         = $RE{IRC}{channel}{-keep};
my $COMMAND         = q[(?k:trust|distrust|believe|disbelieve)];
my $in_channel      = qq[(?:in\\s+$CHANNEL)?];
my $spread_the_love = q[(?:spread(?:\s+the\s+love|ops))];
my $check           = q[(?:do\\s+you|check)];
pattern
  name   => [qw(COMMAND trust -keep)],
  create => qq[^$COMMAND\\s+$NICK\\s*$in_channel[?.!]*],
  ;

pattern
  name   => [qw(COMMAND check -keep)],
  create => qq[^$check\\s+$RE{COMMAND}{trust}{-keep}],
  ;

pattern
  name   => [qw(COMMAND spread_ops -keep)],
  create => qq[^(?:$spread_the_love|names)\\s*$in_channel[?.!]*],
  ;

sub S_bot_addressed {
    my ( $self, $irc ) = splice @_, 0, 2;

    my $msg = $$_[2] || return PCI_EAT_NONE;

    my $channel = $$_[1]->[0];
    return PCI_EAT_NONE if $self->is_untrusted_channel($channel) );

    my ( $nick, $user, $host ) = parse_user( ${ $_[0] } );

    given ($msg) {
          when ( $RE{COMMAND}{trust}{-keep} ) {
              my ( $command, $nick, $target ) = ( $1, $2, $3 );
              $target //= $channel;
              my $nick = $self->long_form($nick);
              $self->$command( $nick => $target );
          }
          when ( $RE{COMMAND}{check}{-keep} ) {
              my ( $command, $nick, $target ) = ( $1, $2, $3 );
              my $method = "is_{$command}ed";
              my $nick   = $self->long_form($nick);
              $target //= $channel;

              my $check = "$command $nick in $target";
              $self->$command( $nick => $target )
                ? $self->privmsg( $channel => "Yes, I $check." )
                : $self->privmsg( $channel => "No, I don't $check." );
          }
          when ( $RE{COMMAND}{spread_ops}{-keep} ) {
              my $target = $1 // $channel;
              $self->spread_ops($target);
          }
          default { return PCI_EAT_NONE; };
    }

    return PCI_EAT_PLUGIN;
}

# alias S_irc_bot_addressed to S_msg because they do the same thing
__PACKAGE__->meta->add_method( S_msg => \&S_bot_addressed );

sub S_public {
      my ( $self, $irc ) = splice @_, 0, 2;
      ( my $msg = $$_[2] ) =~ s/^opbots[:,]?\s+//i || return PCI_EAT_NONE;
      my $channel = $$_[1]->[0];
      return PCI_EAT_NONE if $self->is_untrusted_channel($channel) );

      my ( $nick, $user, $host ) = parse_user( ${ $_[0] } );

      given ($msg) {
            when ( $RE{COMMAND}{trust}{-keep} ) {
                my ( $command, $nick, $target ) = ( $1, $2, $3 );
                $target //= $channel;
                my $nick = $self->long_form($nick);
                $self->$command( $nick => $target );
            }
            when ( $RE{COMMAND}{check}{-keep} ) {
                my ( $command, $nick, $target ) = ( $1, $2, $3 );
                my $method = "is_{$command}ed";
                my $nick   = $self->long_form($nick);
                $target //= $channel;

                my $check = "$command $nick in $target";
                $self->$command( $nick => $target )
                  ? $self->privmsg( $channel => "Yes, I $check." )
                  : $self->privmsg( $channel => "No, I don't $check." );
            }
            when ( $RE{COMMAND}{spread_ops}{-keep} ) {
                my $target = $1 // $channel;
                $self->spread_ops($target);
            }
            default { return PCI_EAT_NONE; };
      }

      return PCI_EAT_PLUGIN;
}

sub trust {
      my ( $self, $nick, $channel ) = @_;
      return 1 if $self->get_user_by_nick($nick)->add_channel_op($channel);
      return 0;
}

sub is_trusted {
      my ( $self, $nick, $channel ) = @_;
      return 1 if $self->get_user_by_nick($nick)->has_channel_op($channel);
      return 0;
}

sub is_distrusted {
      my ( $self, $nick, $channel ) = @_;
      return !$self->is_trusted( $nick, $channel );
}

sub is_believed {
      my ( $self, $nick, $channel ) = @_;
      return 1 if $self->get_user_by_nick($nick)->has_channel_voice($channel);
      return 0;
}

sub is_disbelieve {
      my ( $self, $nick, $channel ) = @_;
      return !$self->is_believed( $nick, $channel );
}

sub is_halfop {
      my ( $self, $nick, $channel ) = @_;
      return 1 if $self->get_user_by_nick($nick)->has_channel_halfop($channel);
      return 0;
}

1;
__END__
