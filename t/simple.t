use Test::More;
use strict;

use Config::Path;

my $conf = Config::Path->new(files => [ 't/conf/simple.yaml', 't/conf/other.yaml' ]);
ok(defined($conf));

cmp_ok($conf->fetch('foo'), 'eq', 'bar', 'got foo key from file 1');
cmp_ok($conf->fetch('baz'), 'eq', 'gorch', 'got baz key from file 2');

done_testing;