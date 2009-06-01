package Flexo::Storage;
use Moose;
use namespace::autoclean;

extends qw(KiokuX::Layer8::Storage);

sub get_user_by_nick {
    my ( $self, $nick ) = @_;
    ( $self->search( { nickstr => $nick } )->next )[0];
}

1;
__END__