package Flexo::Plugin::Trust::SimpleStorage;
use Moose;
use MooseX::Storage;

with Storage(
    format => 'YAML',
    io     => 'AtomicFile',
);

has filename => (
    isa     => 'Str',
    is      => 'ro',
    traits  => ['DoNotSerialize'],
    default => 'trust.yml',
);

has matrix => (
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} },
);

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

sub trust {
    my ( $self, $opt ) = @_;
    my $output = $self->check_trust($opt);
    return $output if $output->{return_value};
    $self->matrix->{ $opt->{channel} }->{ $opt->{target} } = 'o';
    $self->save;
    return { %$output, return_value => 1 };
}

sub check_trust {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'o';
    return { %$opt, return_value => 0 };
}

sub distrust {
    my ( $self, $opt ) = @_;
    my $output = $self->check_distrust($opt);
    return $output if $output->{return_value};
    delete $self->matrix->{ $opt->{channel} }->{ $opt->{target} };
    $self->save;
    return { %$output, return_value => 1 };
}

sub check_distrust {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } ne 'o';
    return { %$opt, return_value => 0 };
}

sub believe {
    my ( $self, $opt ) = @_;
    my $output = $self->check_believe($opt);
    return $output if $output->{return_value};
    $self->matrix->{ $opt->{channel} }->{ $opt->{target} } = 'v';
    $self->save;
    return { %$output, return_value => 1 };
}

sub check_believe {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'v';
    return { %$opt, return_value => 0 };
}

sub disbelieve {
    my ( $self, $opt ) = @_;
    my $output = $self->check_disbelieve($opt);
    return $output if $output->{return_value};
    delete $self->matrix->{ $opt->{channel} }->{ $opt->{target} };
    $self->save;
    return { %$output, return_value => 1 };
}

sub check_disbelieve {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } ne 'v';
    return { %$opt, return_value => 0 };
}

1;
__END__
