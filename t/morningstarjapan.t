#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Finance::Quote;

if ( not $ENV{ONLINE_TEST} ) {
    plan skip_all => 'Set $ENV{ONLINE_TEST} to run this test';
}

plan tests => 12;

# Test morningstarjapan_etf functions.

my $q        = Finance::Quote->new("MorningstarJapan");
my $year     = ( localtime() )[5] + 1900;
my $lastyear = $year - 1;

my @stocks = ( "1680", "BOGUS" );

my %quotes = $q->fetch( "morningstarjapan_etf", @stocks );
ok(%quotes);

ok( $quotes{ "1680", "success" } );
ok( $quotes{ "1680", "currency" } eq "JPY" );
is( $quotes{ "1680", 'method' }, 'morningstarjapan_etf' );
is( $quotes{ "1680", 'source' }, 'Finance::Quote::MorningstarJapan' );
ok( length( $quotes{ "1680", "name" } ) > 0 );
ok(        substr( $quotes{ "1680", "isodate" }, 0, 4 ) == $year
        || substr( $quotes{ "1680", "isodate" }, 0, 4 ) == $lastyear );
ok(        substr( $quotes{ "1680", "date" }, 6, 4 ) == $year
        || substr( $quotes{ "1680", "date" }, 6, 4 ) == $lastyear );
cmp_ok( $quotes{ "1680", "last" },   '>', 0 );
cmp_ok( $quotes{ "1680", "volume" }, '>', 0 );
cmp_ok( $quotes{ "1680", "nav" },    '>', 0 );

# Check that a bogus stock returns no-success.
ok( !$quotes{ "BOGUS", "success" } );

