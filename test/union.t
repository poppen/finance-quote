#!/usr/bin/perl -w
use strict;
use Test;
BEGIN {plan tests => 7};

use Finance::Quote;

# Test TD Waterhouse functions.

my $q      = Finance::Quote->new();

my %quotes = $q->unionfunds("975788","12345");
ok(%quotes);

# Check the last values are defined.  These are the most
#  used and most reliable indicators of success.
ok($quotes{"975788","last"} > 0);
ok($quotes{"975788","success"});
ok($quotes{"975788", "currency"} eq "EUR");

my $year = (localtime())[5] + 1900;
ok(substr($quotes{"975788","isodate"},0,4) eq $year);
ok(substr($quotes{"975788","date"},6,4) eq $year);


# Check that bogus stocks return failure:

ok(! $quotes{"12345","success"});