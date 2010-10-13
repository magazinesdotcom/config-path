use inc::Module::Install;

name     'Config-Path';
all_from 'lib/Config/Path.pm';
author   q{Cory G Watson <gphat@cpan.org>};
license  'perl';

build_requires 'Test::More';

test_requires 'YAML::XS';
test_requires 'Test::Exception';

requires 'Moose';
requires 'Config::Any';
requires 'Hash::Merge' => '0.12';

WriteAll;

