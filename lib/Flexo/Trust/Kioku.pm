package Flexo::Trust::Kioku;
use Moose;
with qw(Flexo::Trust::API);

has model => (
    isa     => 'KiokuX::Model',
    is      => 'ro',
    handles => [qw(channel user)],
);

sub check_trust {
    my ( $self, $opt ) = @_;
    my $channel = $self->channel( $opt{channel} );
    my $user    = $self->user( $opt{target} );
    return $channel->is_trusted($user);
}

sub check_believe {
    my ( $self, $opt ) = @_;
    my $channel = $self->channel( $opt{channel} );
    my $user    = $self->user( $opt{$target} );
    return $channel->is_believed($user);
}

sub _modify {
    my ( $self, $opt, $method ) = @_;
    my $channel = $self->channel( $opt{channel} );
    my $user    = $self->user( $opt{$target} );
    $channel->$method($user);
    $self->store($channel);
}

sub trust {
    my ( $self, $opt ) = @_;
    $self->_modify( $self, $opt, 'trust' );
}

sub distrust {
    my ( $self, $opt ) = @_;
    $self->_modify( $self, $opt, 'distrust' );
}

sub believe {
    my ( $self, $opt ) = @_;
    $self->_modify( $self, $opt, 'believe' );
}

sub disbelieve {
    my ( $self, $opt ) = @_;
    $self->_modify( $self, $opt, 'disbelieve' );
}

1;
__END__
