package Flexo::Trust::Simple;
use Moose;
use MooseX::Storage;

with Storage(
    format => 'YAML',
    io     => 'AtomicFile',
);

has filename => (
    isa      => 'Str',
    is       => 'ro',
    traits   => ['DoNotSerialize'],
    required => 1,
);

has matrix => (
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} },
);

with qw(Flexo::Trust::API);

sub new_from_trustfile {
    my $class = shift;
    my $self  = $class->new(@_);
    return $class->load( $self->filename ) if -e $self->filename;
    return $self;
}

sub DEMOLISH { shift->save }

sub save {
    my ($self) = @_;
    $self->store( $self->filename );
}

sub check_trust {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'o';
    return { %$opt, return_value => 0 };
}


sub check_believe {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'v';
    return { %$opt, return_value => 0 };
}

sub trust {
    my ( $self, $opt ) = @_;
    my $output = $self->check_trust($opt);
    return $output if $output->{return_value};
    $self->matrix->{ $opt->{channel} }->{ $opt->{target} } = 'o';
    $self->save;
    return { %$output, return_value => 1 };
}

sub distrust {
    my ( $self, $opt ) = @_;
    my $output = $self->check_distrust($opt);
    return $output if $output->{return_value};
    delete $self->matrix->{ $opt->{channel} }->{ $opt->{target} };
    $self->save;
    return { %$output, return_value => 1 };
}

sub believe {
    my ( $self, $opt ) = @_;
    my $output = $self->check_believe($opt);
    return $output if $output->{return_value};
    $self->matrix->{ $opt->{channel} }->{ $opt->{target} } = 'v';
    $self->save;
    return { %$output, return_value => 1 };
}

sub disbelieve {
    my ( $self, $opt ) = @_;
    my $output = $self->check_disbelieve($opt);
    return $output if $output->{return_value};
    delete $self->matrix->{ $opt->{channel} }->{ $opt->{target} };
    $self->save;
    return { %$output, return_value => 1 };
}

1;
__END__
