package Flexo::Plugin::Trust;
use 5.10.0 h;
use Moses::Plugin;

use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( :ALL );
use Regexp::Common qw(IRC pattern);

has session => (
    isa        => 'POE::Session',
    is         => 'ro',
    lazy_build => 1
);

sub _build_session {
    my $self = shift;
    POE::Session->create(
        object_states => [
            $self => [
                qw(
                  _start
                  _stop
                  _on_join
                  _spread_ops
                  )
            ],
        ],
        options => { trace => 0 },
    );
}

has trustfile => (
    isa     => 'Str',
    is      => 'ro',
    lazy    => 1,
    default => sub { 'trust.yaml' },
);

has data => (
    isa => 'HashRef',
    is  => 'ro'
);

##########################
# Plugin related methods #
##########################

sub PCI_register {
    my ( $self, $irc ) = @_;
    $self->{irc} = $irc;
    $irc->plugin_register( $self, 'SERVER',
        qw(join mode nick public bot_addressed) );
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = @_;
    delete( $self->{irc} );
    $poe_kernel->refcount_decrement( $self->{session_id}, __PACKAGE__ );
    return 1;
}

sub S_join {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ($who)     = ${ $_[0] };
    my ($nick)    = ( split /!/, $who )[0];
    my ($channel) = ${ $_[1] };
    my $mapping   = $irc->isupport('CASEMAPPING');
    if ( $nick eq $irc->nick_name() ) {
        $self->{CHAN_SYNCING}->{ u_irc $channel, $mapping } = 1;
        return PCI_EAT_NONE;
    }

    return PCI_EAT_NONE
      unless $irc->is_channel_operator( $channel, $irc->nick_name() );

    if ( $self->is_owner($who) ) {
        $irc->yield( mode => $channel => "+o" => $nick );
        return PCI_EAT_NONE;
    }

    my $mode;
    given ( { $channel => $who ] ) {
        when ( not $self->trusted_channel( keys %$_ ) ) { }        
        when ( $self->is_trusted(@$_) )  { $mode = 'o'; }
        when ( $self->is_henchman(@$_) ) { $mode = 'h'; }
        when ( $self->is_believed(@$_) ) { $mode = 'v'; }
    }
}

if ( $mode and $irc->is_channel_operator( $channel, $irc->nick_name() ) ) {
    $irc->yield( mode => $channel => ( '+' . $mode ) => $nick );
}

return PCI_EAT_NONE;
}

sub S_chan_sync {
    my ( $self, $irc ) = splice @_, 0, 2;
    my $channel = ${ $_[0] };
    my $mapping = $irc->isupport('CASEMAPPING');
    my $uchan   = u_irc $channel, $mapping;
    my $value   = delete $self->{CHAN_SYNCING}->{$uchan};
    $poe_kernel->post( $self->session => _spread_ops => $channel )
      if $value == 2;
    return PCI_EAT_NONE;
}

sub S_nick {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $old, $userhost ) = ( split /!/, ${ $_[0] } )[ 0 .. 1 ];
    my ($nick) = ${ $_[1] };
    my ($who)  = $nick . '!' . $userhost;

    foreach my $channel ( @{ ${ $_[ARG2] } } ) {
        next unless $irc->is_channel_operator( $channel, $irc->nick_name() );
        my ($mode);
      SWITCH: {
            if ( not $self->trusted_channel($channel) ) {
                last SWITCH;
            }
            if ( $self->is_trusted( $channel, $who ) ) {
                $mode = 'o';
                last SWITCH;
            }
            if ( $self->is_henchman( $channel, $who ) ) {
                $mode = 'h';
                last SWITCH;
            }
            if ( $self->is_believed( $channel, $who ) ) {
                $mode = 'v';
                last SWITCH;
            }
        }

        if ($mode) {
            $irc->yield( mode => $channel => ( '+' . $mode ) => $nick );
        }
    }

    return PCI_EAT_NONE;
}

sub S_mode {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $nick, $userhost ) = ( split /!/, ${ $_[0] } )[ 0 .. 1 ];
    my ($channel) = ${ $_[1] };
    return PCI_EAT_NONE unless ( $self->trusted_channel($channel) );
    my ($mynick) = $irc->nick_name();
    return PCI_EAT_NONE if ( l_irc($nick)    eq l_irc($mynick) );
    return PCI_EAT_NONE if ( l_irc($channel) eq l_irc($mynick) );
    my ($parsed_mode) =
      _parse_mode_line( map { ref $_ eq 'SCALAR' ? $$_ : $_ } @_[ 2 .. $#_ ] );

    my ($trusted_nick) = $self->is_trusted( $channel, ${ $_[0] } );

    while ( my $mode = shift( @{ $parsed_mode->{modes} } ) ) {
        my $arg = shift( @{ $parsed_mode->{args} } )
          if ( $mode =~ /^(\+[hovklbIe]|-[hovbIe])/ );
      SWITCH: {
            if (    $trusted_nick
                and $mode eq '+o'
                and l_irc($arg) eq l_irc($mynick) )
            {
                $poe_kernel->post( $self->session, '_spread_ops', $channel );
                last SWITCH;
            }

            if ( $trusted_nick and $mode =~ /^\+([ohv])/ ) {
                my ($flag) = $1;
                my ($full) = $irc->nick_long_form($arg);
                if ( l_irc($arg) ne l_irc($mynick)
                    and ( !$self->check( $channel, $full, $flag ) ) )
                {
                    $self->record( $channel, $full, '+', $flag );
                }
                last SWITCH;
            }

            if ( $mode eq '+o' and l_irc($arg) eq l_irc($mynick) ) {
                $self->record( $channel, $nick . '!' . $userhost, '+', undef );
                last SWITCH;
            }
        }
    }
    return PCI_EAT_NONE;
}

sub S_bot_addressed {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ($channel) = ${ $_[1] }->[0];
    return PCI_EAT_NONE unless ( $self->trusted_channel($channel) );

    my ($what) = ${ $_[2] };
    return PCI_EAT_NONE unless $what;

    my ( $nick, $user, $host ) = parse_user( ${ $_[0] } );
    my ( $msg, @modes ) = $self->told( $channel, $nick, $what );

    return PCI_EAT_NONE unless ($msg);

    $irc->yield( privmsg => $channel => $msg );

    foreach my $mode (@modes) {
        $irc->yield( mode => $mode );
    }

    return PCI_EAT_PLUGIN;
}

# alias S_irc_bot_addressed to S_msg because they do the same thing
__PACKAGE__->meta->add_method( S_msg => \&S_bot_addressed );

sub S_public {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ($channel) = ${ $_[1] }->[0];
    return PCI_EAT_NONE unless ( $self->trusted_channel($channel) );

    my ($what) = ${ $_[2] };
    return PCI_EAT_NONE unless $what;
    return PCI_EAT_NONE unless $what =~ s/^opbots[:,]?\s+//i;

    my ( $nick, $user, $host ) = parse_user( ${ $_[0] } );
    my ( $msg, @modes ) = $self->told( $channel, $nick, $what );

    return PCI_EAT_NONE unless ($msg);

    $irc->yield( privmsg => $channel => $msg );

    foreach my $mode (@modes) {
        $irc->yield( mode => $mode );
    }

    return PCI_EAT_PLUGIN;
}

#############################
# POE based handler methods #
#############################

sub _start {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $kernel->refcount_increment( $self->{session_id}, __PACKAGE__ );
}

sub _stop { }

sub _on_join {
    my ($self)   = $_[OBJECT];
    my ($result) = $_[ARG0]->{result};
    my ($error)  = $_[ARG0]->{error};

    if ( not defined($error) ) {
        foreach my $row ( @{$result} ) {
            my ($nick) = ( split /!/, $row->{Identity} )[0];
            $self->{irc}->yield(
                mode => $row->{Channel} => ( '+' . $row->{Mode} ) => $nick );
        }
    }

}

sub _spread_ops {
    my ( $kernel, $self, $channel ) = @_[ KERNEL, OBJECT, ARG0 ];
    my ($irc) = $self->{irc};
    my (@nicks);

    foreach my $nick ( $self->{irc}->channel_list($channel) ) {
        if (
            not(   $irc->is_channel_operator( $channel, $nick )
                or $irc->is_channel_halfop( $channel, $nick )
                or $irc->has_channel_voice( $channel, $nick ) )
          )
        {
            push( @nicks, $nick );
        }
    }

    my @trust   = ();
    my @believe = ();
    my @hench   = ();
    my @modes   = ();

    foreach my $nick (@nicks) {
        if ( $self->is_trusted( $channel, $nick ) ) {
            push @trust, $nick;
        }
        elsif ( $self->is_believed( $channel, $nick ) ) {
            push @believe, $nick;
        }
        elsif ( $self->is_henchman( $channel, $nick ) ) {
            push @hench, $nick;
        }
    }

    return unless @trust || @believe || @hench;

    #$irc->call( ctcp => $channel => 'ACTION spreads the love...' );

    push @modes, $self->_build_modes( $channel, '+', 'o', @trust );
    push @modes, $self->_build_modes( $channel, '+', 'v', @believe );
    push @modes, $self->_build_modes( $channel, '+', 'h', @hench );

    foreach my $mode (@modes) {
        $irc->yield( mode => $mode );
    }
}

#########################
# Trust related methods #
#########################

sub is_owner {
    my ( $self, $who ) = @_;
    return 1 if $who =~ /^perigrin/;
    return 0 unless $who;            # we don't trust nobody
    return 0 unless $self->owner;    # We don't have an owner

    # check their full hostmask
    $who = $self->{irc}->nick_long_form($who) unless $who =~ /!/;

    return 1 if matches_mask( $self->{owner}, $who );
    return 0;
}

sub is_trusted {
    my ($self) = shift;
    return $self->check( $_[0], $_[1], 'o' );
}

sub is_believed {
    my ($self) = shift;
    return $self->check( $_[0], $_[1], 'v' );
}

sub is_henchman {
    my ($self) = shift;
    return $self->check( $_[0], $_[1], 'h' );
}

sub check {
    my ($self)    = shift;
    my ($channel) = l_irc( $_[0] ) || return 0;
    my ($who)     = $_[1] || return 0;
    my ($mode)    = $_[2] || return 0;

    $who = $self->{irc}->nick_long_form($who) unless $who =~ /!/;

    my ( $nick, $user, $host ) = parse_user($who);
    return 0 unless ( $nick && $user && $host );

    # always trust your owner
    return 1 if $self->is_owner($who);
    return 1 if $user eq 'matthewt' && $host eq 'warez.trout.me.uk';

    return 0 unless ( defined( $self->{data}->{$channel} ) );

    my %trusts = %{ $self->{data}->{$channel} };

    while ( my ( $user, $trust ) = each %trusts ) {
        next unless lc($user) eq lc($who);
        next unless $trust eq $mode;
        return 1;
    }
    return 0;
}

# REGEXES
my $NICK           = $RE{IRC}{nick}{-keep}{ -count => 20 };
my $CHANNEL        = $RE{IRC}{channel}{-keep};
my $COMMAND        = q[(?k:trust|distrust|believe|disbelieve)];
my $messages_trust = qq[^$COMMAND\\s+$NICK\\s*(?:in\\s+$CHANNEL)?[?.!]*];
my $check_trust =
  qq[^do\\s+you\\s+$COMMAND\\s+$NICK\\s*(?:in\\s+$CHANNEL)?[?.!]*];
my $spread_love =
  qq[^(?:(?:spread (?:the love|ops))|(?:names))\\s*(?:in\\s+$CHANNEL)?[?.!]*];

pattern
  name   => [qw(COMMAND trust -keep)],
  create => qq[$messages_trust],
  ;

pattern
  name   => [qw(COMMAND check -keep)],
  create => qq[$check_trust],
  ;

pattern
  name   => [qw(COMMAND spread_ops -keep)],
  create => qq[$spread_love],
  ;

sub told {
    my ($self)      = shift;
    my ($channel)   = $_[0] || return undef;
    my ($from_nick) = $_[1] || return undef;
    my ($message)   = $_[2] || return undef;
    my ( $command, $nick, $in_channel );

    # trust | distrust | believe | disbelieve
    if ( ( $command, $nick, $in_channel ) =
        $message =~ $RE{COMMAND}{trust}{-i} )
    {
        $channel = $in_channel || $channel;
        my @nicks = split /[\s,]+/, $nick;
        return "But I don't trust you in $channel, $from_nick"
          unless $self->is_trusted( $channel, $from_nick );
        return $self->$command( $channel, $from_nick, @nicks );
    }

    # check command
    if ( ( $command, $nick, $in_channel ) =
        $message =~ $RE{COMMAND}{check}{-i} )
    {
        $channel = $in_channel if $in_channel;
        $command =
            $command eq 'trust'   ? 'o'
          : $command eq 'believe' ? 'v'
          :                         undef;
        return unless $command;
        return $self->check( $channel, $nick, $command )
          ? "Yes I do"
          : "Hell no, are you kidding me?";
    }

    if ( ( $command, $in_channel ) = $message =~ $RE{COMMAND}{spread_ops}{-i} )
    {
        $channel = $in_channel if $in_channel;
        $poe_kernel->post( $self->{session_id}, '_spread_ops', $channel );
    }
    return;
}

sub trusted_channel {
    my ($self) = shift;
    my ($channel) = l_irc( $_[0] ) || return 0;

    if ( $channel eq '#PERL' ) {
        return 0;
    }
    return 1;
}

###################
# Command methods #
###################

sub trust {
    my ( $self, $channel, $from_nick, @nicks ) = @_;
    my @trusted_nicks = ();
    my @mode_nicks    = ();

    return "But I don't trust _you_ $from_nick"
      unless $self->is_trusted( $channel, $from_nick );

    for my $nick (@nicks) {
        if ( $self->is_trusted( $channel, $nick ) ) {
            push @trusted_nicks, $nick;
        }
        else {
            $self->record( $channel, $nick, '+', 'o' );
            push @mode_nicks, $nick;
        }
    }

    my $privmsg =
      @trusted_nicks
      ? "$from_nick, I already trust " . _and_join(@trusted_nicks)
      : @mode_nicks ? "OK, $from_nick"
      :   "$from_nick, please specify nick(s) you would like me to trust";

    my @modes = $self->_build_modes( $channel, '+', 'o', @mode_nicks );

    return $privmsg, @modes;
}

sub distrust {
    my ( $self, $channel, $from_nick, @nicks ) = @_;
    my @untrusted_nicks = ();
    my @mode_nicks      = ();

    return "But I don't trust _you_ $from_nick"
      unless $self->is_trusted( $channel, $from_nick );

    for my $nick (@nicks) {
        if ( $self->is_trusted( $channel, $nick ) ) {
            $self->record( $channel, $nick, '-', 'o' );
            push @mode_nicks, $nick;
        }
        else {
            push @untrusted_nicks, $nick;
        }
    }

    my $privmsg =
      @untrusted_nicks
      ? "$from_nick, But I don't trust " . _and_join(@untrusted_nicks)
      : @mode_nicks ? "OK, $from_nick"
      :   "$from_nick, please specify nick(s) you'd like me to distrust";

    my @modes = $self->_build_modes( $channel, '-', 'o', @mode_nicks );

    return $privmsg, @modes;
}

sub believe {
    my ( $self, $channel, $from_nick, @nicks ) = @_;
    my @trust_nicks   = ();
    my @believe_nicks = ();
    my @mode_nicks    = ();

    return "But I don't trust _you_ $from_nick"
      unless $self->is_trusted( $channel, $from_nick );

    for my $nick (@nicks) {
        if ( $self->is_trusted( $channel, $nick ) ) {
            push @trust_nicks, $nick;
        }
        elsif ( $self->is_believed( $channel, $nick ) ) {
            push @believe_nicks, $nick;
        }
        else {
            push @mode_nicks, $nick;
            $self->record( $channel, $nick, '+', 'v' );
        }
    }

    my ( $trust_nicks, $believe_nicks );
    if ( @trust_nicks && @believe_nicks ) {
        $trust_nicks   = join ", ", @trust_nicks;
        $believe_nicks = join ", ", @believe_nicks;
    }
    else {
        $trust_nicks   = _and_join(@trust_nicks);
        $believe_nicks = _and_join(@believe_nicks);
    }

    my $privmsg =
      $trust_nicks && $believe_nicks
      ? "I already trust $trust_nicks and believe $believe_nicks"
      : $trust_nicks   ? "I already trust $trust_nicks"
      : $believe_nicks ? "I already believe $believe_nicks"
      : @mode_nicks    ? "OK, $from_nick"
      :   "$from_nick, please specify nick(s) you'd like me to believe";

    my @modes = $self->_build_modes( $channel, '+', 'v', @mode_nicks );

    return $privmsg, @modes;
}

sub disbelieve {
    my ( $self, $channel, $from_nick, @nicks ) = @_;
    my @non_believe_nicks = ();
    my @mode_nicks        = ();

    return "But I don't trust _you_ $from_nick"
      unless $self->is_trusted( $channel, $from_nick );

    for my $nick (@nicks) {
        if ( $self->is_believed( $channel, $nick, 'v' ) ) {
            $self->record( $channel, $nick, '-', 'v' );
            push @mode_nicks, $nick;
        }
        else {
            push @non_believe_nicks, $nick;
        }
    }

    my $privmsg =
        @non_believe_nicks ? "I don't believe " . _and_join(@non_believe_nicks)
      : @mode_nicks        ? "OK, $from_nick"
      :   "$from_nick, please specify nick(s) you'd like me to disbelieve";

    my @modes = $self->_build_modes( $channel, '-', 'v', @mode_nicks );

    return $privmsg, @modes;

}

sub _build_modes {
    my ( $self, $channel, $give_take, $mode, @nicks ) = @_;
    return
      unless $self->{irc}
          ->is_channel_operator( $channel, $self->{irc}->nick_name() );
    my @modes = ();

    while ( my @subset = splice( @nicks, 0, 4 ) ) {
        push @modes,
          $channel . ' ' . $give_take . $mode x @subset . " " . join ' ',
          @subset;
    }
    return @modes;
}

sub record {
    my ($self)      = shift;
    my ($channel)   = l_irc( $_[0] ) || return 0;
    my ($who)       = $_[1] || return 0;
    my ($give_take) = $_[2] || return 0;
    my ($mode)      = $_[3] || return 0;

    return 0 unless ( $channel && $who && $give_take && $mode );

    $who = $self->{irc}->nick_long_form($who) unless $who =~ /!/;

    if ( $give_take eq '+' ) {
        $self->{data}->{$channel}->{$who} = $mode;
    }
    if ( $give_take eq '-' ) {
        delete $self->{data}->{$channel}->{$who};
    }
    return 1;
}

###########################
# Miscellaneous functions #
###########################

sub _parse_mode_line {
    my ($hashref) = {};

    my ($count) = 0;
    foreach my $arg (@_) {
        if ( $arg =~ /^(\+|-)/ or $count == 0 ) {
            my ($action) = '+';
            foreach my $char ( split( //, $arg ) ) {
                if ( $char eq '+' or $char eq '-' ) {
                    $action = $char;
                }
                else {
                    push( @{ $hashref->{modes} }, $action . $char );
                }
            }
        }
        else {
            push( @{ $hashref->{args} }, $arg );
        }
        $count++;
    }
    return $hashref;
}

sub _and_join {
    my (@array) = @_;
    return unless @array;
    return $array[0] if @array == 1;
    my $last_element = pop @array;
    return join( ', ', @array ) . ', and ' . $last_element;
}

1;
