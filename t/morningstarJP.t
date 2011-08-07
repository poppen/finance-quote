#!/usr/bin/perl -w

require 5.005;

use strict;

use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 23;

# Test MorningstarJp functions
my $q        = Finance::Quote->new();
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my %quotes = $q->morningstar_jp( "1031186A", "2010040602", "BOGUS" );
ok(%quotes);

# Check 1031186A
ok(
    $quotes{ "1031186A", "new_symbol" } eq "1986103001",
    "1031186A's new_symbol should be 1986103001"
);
is( $quotes{ "1986103001", "new_symbol" },
    undef, "1986103001's new_symbol should be undef" );

ok( length( $quotes{ "1031186A", "symbol" } ) > 0 );
ok( length( $quotes{ "1031186A", "name" } ) > 0 );
ok( length( $quotes{ "1031186A", "date" } ) > 0 );
ok( $quotes{ "1031186A", "last" } > 0 );
ok( $quotes{ "1031186A", "currency" } eq "JPY" );
ok( $quotes{ "1031186A", "net" } );
ok( $quotes{ "1031186A", "success" } );
ok(      substr( $quotes{ "1031186A", "date" }, 6, 4 ) == $year
      || substr( $quotes{ "1031186A", "date" }, 6, 4 ) == $lastyear );
ok(      substr( $quotes{ "1031186A", "isodate" }, 0, 4 ) == $year
      || substr( $quotes{ "1031186A", "isodate" }, 0, 4 ) == $lastyear );

# Check 2010040602
is( $quotes{ "2010040602", "new_symbol" },
    undef, "2010040602's new_symbol should be undef" );
ok( length( $quotes{ "2010040602", "symbol" } ) > 0 );
ok( length( $quotes{ "2010040602", "name" } ) > 0 );
ok( length( $quotes{ "2010040602", "date" } ) > 0 );
ok( $quotes{ "2010040602", "last" } > 0 );
ok( $quotes{ "2010040602", "currency" } eq "JPY" );
ok( $quotes{ "2010040602", "net" } );
ok( $quotes{ "2010040602", "success" } );
ok(      substr( $quotes{ "2010040602", "date" }, 6, 4 ) == $year
      || substr( $quotes{ "2010040602", "date" }, 6, 4 ) == $lastyear );
ok(      substr( $quotes{ "2010040602", "isodate" }, 0, 4 ) == $year
      || substr( $quotes{ "2010040602", "isodate" }, 0, 4 ) == $lastyear );

# Check that a bogus stock returns no-success
ok( !$quotes{ "BOGUS", "success" } );
