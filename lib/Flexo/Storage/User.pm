package Flexo::Storage::User;
use Moose;
use namespace::autoclean;

use KiokuDB::Util qw(set);

extends qw(KiokuX::Layer8::User);

has nickstr => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

for my $level (qw(channel_op channel_voice channel_halfop )) {
    has $level => (
        does    => "KiokuDB::Set",
        is      => 'ro',
        lazy    => 1,
        default => sub { set( [] ) },
        handles => {
            "has_${level}" => 'member',
            "add_${level}" => 'insert',
        }
    );
}

1;
__END__
