#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Doubly::Linked' ) || print "Bail out!\n";
}

diag( "Testing Doubly::Linked $Doubly::Linked::VERSION, Perl $], $^X" );
