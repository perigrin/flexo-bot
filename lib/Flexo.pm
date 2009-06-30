package Flexo;
use Moses;

use Module::Pluggable (
    search_path => ["Flexo::Plugin"],
    except      => ['Flexo::Plugin::Trust'],
    sub_name    => 'plugin_classes',
);

server 'irc.perl.org';
channels '#orlando';

# has dsn => (
#     isa     => 'Str',
#     is      => 'ro',
#     default => 'dbi:SQLite:dbname=flexo.db',
# );
# 
# has storage => (
#     isa        => 'Flexo::Storage',
#     is         => 'ro',
#     lazy_build => 1,
# );
# 
# sub _build_storage {
#     my ($self) = @_;
#     return;
#     Flexo::Storage->new(
#         dsn        => $self->dsn,
#         extra_args => {
#             create  => 1,
#             columns => [
#                 nickstr => {
#                     data_type   => "varchar",
#                     is_nullable => 1,           # probably important
#                 },
#             ],
#         }
#     );
# }
# 
sub custom_plugins {
    my ($self) = @_;
    return {
        # 'Flexo::Plugin::Trust' =>
        #   Flexo::Plugin::Trust->new( storage => $self->storage, ),
        map { $_ => $_ } $_[0]->plugin_classes
    };
}

__PACKAGE__->run unless caller;

no Moses;
1;
__END__
