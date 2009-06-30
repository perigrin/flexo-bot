package Flexo::Storage;
use Moose;
use namespace::autoclean;

extends qw(KiokuX::Layer8::Storage);

sub get_irc_identity {
    my ( $self, $nick ) = @_;
    my $stream = $self->search( { nickstr => $nick } );
    ( $stream->next )[0][0];
}

1;
__END__
