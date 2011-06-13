package Flexo;
use 5.10.1;
use Moses;
use namespace::autoclean;

# ABSTRACT: The patriarch of IRC Bots

nickname 'Flexo';
server 'irc.perl.org';

has plugins => ( is => 'ro', );

1;
__END__
