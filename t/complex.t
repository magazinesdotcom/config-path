use Test::More;
use strict;

use Config::Path;

my $conf = Config::Path->new(directory => 't/conf' );

use Data::Dumper;

cmp_ok($conf->fetch('xml/not'), 'eq', 'empty', 'got value for xml item');
ok(!defined($conf->fetch('xml/empty')), 'got undef for empty item');

cmp_ok($conf->fetch('thingies/0/name'), 'eq', 'thing1', 'arrays');

ok(!defined($conf->fetch('thingies/fart/name')), 'got undef for unreachable item');

ok(!defined($conf->fetch('thingies/fart/name')), 'got undef for unreachable (array) item');

cmp_ok($conf->fetch('one/for/the'), 'eq', 'hustle', 'deep hash');

ok(!defined($conf->fetch('one/far/the')), 'got undef for unreachable (hash) item');

done_testing;
