package Flexo::Plugin::Trust::API;
use Moose::Role;
use namespace::autoclean;
requires qw(matrix trust distrust believe disbelieve);

sub check_trust {
    my ( $self, $opt ) = @_;
    warn "check_trust";
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'o';
    return { %$opt, return_value => 0 };
}

sub check_distrust {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } ne 'o';
    return { %$opt, return_value => 0 };
}

sub check_believe {
    my ( $self, $opt ) = @_;
    no warnings;
    return { %$opt, return_value => 1 }
      if $self->matrix->{ $opt->{channel} }->{ $opt->{target} } eq 'v';
    return { %$opt, return_value => 0 };
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
