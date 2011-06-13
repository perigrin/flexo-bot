package Flexo::Trust::API;
use Moose::Role;
use namespace::autoclean;

requires qw(
  check_trust
  check_believe
  trust
  distrust
  believe
  disbelieve
);

sub check_distrust {
    my ( $self, $opt ) = @_;
    return !$self->check_trust($opt);
}

sub check_disbelieve {
    my ( $self, $opt ) = @_;
    return !$self->check_believe($opt);
}

1;
__END__
