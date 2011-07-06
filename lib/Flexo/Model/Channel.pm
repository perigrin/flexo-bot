package Flexo::Model::Channel;
use Moose;
use namespace::autoclean;

has name => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has ops => (
    isa     => 'ArrayRef',
    traits  => ['Array'],
    lazy    => 1,
    default => sub { [] },
    handles => {
        is_trusted    => 'grep',
        trust         => 'push',
        trust_count   => 'count',
        _distrust_at  => 'delete',
        _get_trust_at => 'get'
    }
);

sub distrust {
    my ( $self, $user ) = @_;
    for my $i ( 0 .. $self->trust_count ) {
        next unless $self->_get_trust_at($i) eq $user;
        $self->_distrust_at($i);
        last;
    }
}

has voice => (
    isa     => 'ArrayRef',
    traits  => ['Array'],
    lazy    => 1,
    default => sub { [] },
    handles => {
        is_believed    => 'grep',
        believe        => 'push',
        voice_count    => 'count',
        _disbelieve_at => 'delete',
        _get_voice_at  => 'get'
    }
);

sub disbelieve {
    my ( $self, $user ) = @_;
    for my $i ( 0 .. $self->voice_count ) {
        next unless $self->_get_voice_at($i) eq $user;
        $self->_disbelieve_at($i);
        last;
    }
}

1;
__END__
