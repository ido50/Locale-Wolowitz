#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Wolowitz' ) || print "Bail out!
";
}

diag( "Testing Wolowitz $Wolowitz::VERSION, Perl $], $^X" );
