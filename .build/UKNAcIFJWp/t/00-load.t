#!perl

use strict;
use warnings;

use Test::More;



plan tests => 1;

use_ok('Wolowitz');
diag("Testing Wolowitz $Wolowitz::VERSION, Perl $], $^X");
