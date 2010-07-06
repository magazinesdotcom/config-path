use Test::More;
use strict;

use Config::Path;

my $conf = Config::Path->new(files => [ 't/conf/simple.yml', 't/conf/other.yml' ]);
ok(defined($conf));

cmp_ok($conf->fetch('a/b'), 'eq', 'c', 'depth works');
cmp_ok($conf->fetch('foo'), 'eq', 'bar', 'got foo key from file 1');

$conf->override('a/b', 'd');
$conf->override('foo', 'baz');

cmp_ok($conf->fetch('a/b'), 'eq', 'd', 'override path a/b');
cmp_ok($conf->fetch('foo'), 'eq', 'baz', 'override path foo');

$conf->reload;

cmp_ok($conf->fetch('a/b'), 'eq', 'c', 'override path a/b reload');
cmp_ok($conf->fetch('foo'), 'eq', 'bar', 'override path foo reload');

done_testing;