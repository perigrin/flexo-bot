package Flexo::Model::User;
use Moose;
use MooseX::Aliases use namespace::autoclean;

has name => (
    isa      => 'Str',
    is       => 'ro',
    alias    => ['nick'],
    required => 1,
);

1;
__END__
