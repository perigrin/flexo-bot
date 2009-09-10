#!/usr/bin/env perl
use strict;
use Test::More;
use Flexo::Plugin::Trust::SimpleStorage;
{

    package Bot;
    use Moose;
    has model => (
        is         => 'ro',
        does       => 'Flexo::Plugin::Trust::API',
        handles    => 'Flexo::Plugin::Trust::API',
        lazy_build => 1,
    );

    sub _build_model {
        Flexo::Plugin::Trust::SimpleStorage->new_from_trustfile();
    }

}

ok( my $s = Bot->new );
my $request = { channel => '#moose', target => 'Sartak!~sartak@69.25.196.249' };

ok( my $resp = $s->check_trust($request), 'check trust on Sartak' );
is( $resp->{return_value}, 0, q[We don't trust Sartak (yet)'] );

ok( $resp = $s->trust($request), 'trust Sartak' );
is( $resp->{return_value}, 1, q[Okay now we trust Sartak] );

$resp = $s->check_trust($request);
is( $resp->{return_value}, 1, q[check_trust Too] );

ok( $resp = $s->check_distrust($request), 'distrust sartak' );
is( $resp->{return_value}, 0, q[We still trust him] );

ok( $resp = $s->distrust($request), 'distrust Sartak' );
is( $resp->{return_value}, 1, q[Okay now we don't trust Sartak] );

ok( $resp = $s->check_distrust($request), 'distrust sartak' );
is( $resp->{return_value}, 1, q[We still distrust him] );

ok( my $resp = $s->check_believe($request), 'check trust on Sartak' );
is( $resp->{return_value}, 0, q[We don't believe Sartak (yet)'] );

ok( $resp = $s->believe($request), 'trust Sartak' );
is( $resp->{return_value}, 1, q[Okay now we believe Sartak] );

$resp = $s->check_believe($request);
is( $resp->{return_value}, 1, q[check_trust Too] );

ok( $resp = $s->check_disbelieve($request), 'distrust sartak' );
is( $resp->{return_value}, 0, q[We still believe him] );

ok( $resp = $s->disbelieve($request), 'disbelieve Sartak' );
is( $resp->{return_value}, 1, q[Okay now we don't believe Sartak] );

ok( $resp = $s->check_disbelieve($request), 'distrust sartak' );
is( $resp->{return_value}, 1, q[We still disbelieve him] );
my $filename = $s->filename;
undef $s;
unlink($filename);

done_testing;
