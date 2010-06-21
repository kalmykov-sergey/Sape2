#!/usr/bin/perl -w
use Test::More 'no_plan';#tests => 11;
BEGIN { use_ok('Sape::Index') };

is( qip_check('http://sutinki3.com/15.htm'), 1, '???');


