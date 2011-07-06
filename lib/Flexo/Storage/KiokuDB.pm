package Flexo::Storage::KiokuDB;
use Moose;
use KiokuX::Model;
use Flexo::Model::Channel;
use Flexo::Model::User;

extends qw(KiokuX::Model);

has columns => (
    isa        => 'ArrayRef',
    is         => 'ro',
    lazy_build => 1,
);

sub _build_columns {
    [
        name => {
            data_type   => 'str',
            is_nullable => 0,
            extract     => sub { shift->name },
        },
    ];
}

around _build__connect_args => sub {
    my $next = shift;
    my $self = shift;
    my $args = $self->$next(@_);
    push @$args, columns => $self->columns;
    return $args;
};

sub channel {
    my ( $self, $name ) = @_;
    my $scope = $self->new_scope;
    my ($channel) = $self->search( { name => $name } )->all;
    unless ($channel) {
        $channel = Flexo::Model::Channel->new( name => $name );
        $self->store($channel);
    }
    return $channel;
}

sub user {
    my ( $self, $name ) = @_;
    my $scope = $self->new_scope;
    my ($user) = $self->search( { name => $name } )->all;
    unless ($user) {
        $user = Flexo::Model::User->new( name => $name );
        $self->store($user);
    }
    return $user;
}

1;
__END__
