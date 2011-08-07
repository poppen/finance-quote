#!/usr/bin/perl -w

require 5.005;

use strict;

use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 11;

# Test MorningstarJp functions
my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->morningstar_jp( "1031186A", "BOGUS" );
ok(%quotes);

ok(
    $quotes{ "1031186A", "new_symbol" } eq "1986103001",
    "1031186A's new_symbol should be 1986103001"
);

# Check all the defined values
ok( length( $quotes{ "1031186A", "symbol" } ) > 0 );
ok( length( $quotes{ "1031186A", "name" } ) > 0 );
ok( length( $quotes{ "1031186A", "date" } ) > 0 );
ok( $quotes{ "1031186A", "last" } > 0 );
ok( $quotes{ "1031186A", "currency" } eq "JPY" );
ok( $quotes{ "1031186A", "net" } );
ok( $quotes{ "1031186A", "success" } );
ok(      substr( $quotes{ "1031186A", "date" }, 6, 4 ) == $year
      || substr( $quotes{ "1031186A", "date" }, 6, 4 ) == $lastyear );

# Check that a bogus stock returns no-success
ok( !$quotes{ "BOGUS", "success" } );
