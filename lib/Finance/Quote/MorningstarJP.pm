package Finance::Quote::MorningstarJP;
require 5.005;

use strict;

use vars
  qw/$VERSION $MORNINGSTAR_SNAPSHOT_JP_URL $MORNINGSTAR_BASIC_JP_URL $MORNINGSTAR_RATING_JP_URL/;

use Encode;
use LWP::UserAgent;
use HTTP::Request::Common;
use Web::Scraper;

$VERSION = '1.1';

$MORNINGSTAR_SNAPSHOT_JP_URL =
  'http://www.morningstar.co.jp/new_fund/sr_detail_snap.asp?fnc=';

sub methods { return ( morningstar_jp => \&morningstar_jp ); }

{
    my @labels = qw/symbol name last date currency net method/;

    sub labels { return ( morningstar_jp => \@labels ); }
}

sub morningstar_jp {
    my $quoter  = shift;
    my @symbols = @_;

    return unless @symbols;

    my ( $user_agent, $snapshot_url, $snapshot_reply, $snapshot_content,
        $snapshot_root, $snapshot_parser, %funds );

    foreach my $symbol (@symbols) {
        $user_agent = $quoter->user_agent;

        $snapshot_url   = $MORNINGSTAR_SNAPSHOT_JP_URL . $symbol;
        $snapshot_reply = $user_agent->request( GET($snapshot_url) );

        unless ( $snapshot_reply->is_success() ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'HTTP failure';
            next;
        }

        my $parse_result = parseHtml( $snapshot_reply->decoded_content );
        if (   defined $parse_result->{name}
            || defined $parse_result->{date}
            || defined $parse_result->{last}
            || defined $parse_result->{net} )
        {
            $funds{ $symbol, 'name' } = encode( 'utf8', $parse_result->{name} );
            $funds{ $symbol, 'symbol' }   = $symbol;
            $funds{ $symbol, 'currency' } = 'JPY';
            $funds{ $symbol, 'timezone' } = 'Asia/Japan';
            $funds{ $symbol, 'success' }  = 1;
            $funds{ $symbol, 'method' }   = 'morningstar_jp';
            $funds{ $symbol, 'date' }     = $parse_result->{date};
            $funds{ $symbol, 'last' }     = $parse_result->{last};
            $funds{ $symbol, 'net' }      = $parse_result->{net};
        }
        elsif ( !defined $parse_result->{name} ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'Fund name not found';
            next;
        }
        elsif ( !defined $parse_result->{date} ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'Parse date error';
            next;
        }
        elsif ( !defined $parse_result->{last} ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'Parse last error';
            next;
        }
        elsif ( !defined $parse_result->{net} ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'Parse net error';
            next;
        }
    }

    return %funds if wantarray;
    return \%funds;
}

sub parseHtml {
    my $content = shift;

    my $scraper = scraper {
        process '//span[@class="namefund"]/b', 'name' => 'TEXT';

        process
'//form[@id="ms_main"]//div[@class="maintable2"]/table[1]/tr/td[1]/table[2]/tr[1]/td[2]',
          'last' => [ 'TEXT', sub { tr/0-9//cd; } ];

        process
'//form[@id="ms_main"]//div[@class="maintable2"]/table[1]/tr/td[1]/table[2]/tr[1]/td[1]',
          'date' => [ 'TEXT', \&_parse_date ];

        process
'//form[@id="ms_main"]//div[@class="maintable2"]/table[1]/tr/td[1]/table[2]/tr[3]/td[2]',
          'net' => [ 'TEXT', \&_trim_net ];
    };

    my $result = $scraper->scrape($content);
    return $result;
}

sub _parse_date {
    my $str = shift;
    if ( $str =~ /\((.*)\)/ ) {
        my ( $yyyy, $mm, $dd ) = split '-', $1;
        return sprintf "%02d/%02d/%d", $mm, $dd, $yyyy;
    }
}

sub _trim_net {
    my $str = shift;
    if ( $str =~ /(^[+-]?\d+)/ ) {
        return $1;
    }
}

1;

=head1 NAME

Finance::Quote::MorningstarJP - Obtain fund prices from Morningstar Japan

=head1 SYNOPSIS

use Finance::Quote;

$q = Finance::Quote->new;

%fundinfo = $q->fetch("morningstar_jp","fund name");

=head1 DESCRIPTION

This module obtains information about Japanese fund prices from
http://www.morningstar.co.jp/.

=head1 FUND NAMES

Visit http://www.morningstar.co.jp/, and search for your fund.  Open the
link to the fund information, and you will get a URL like this:

 http://www.morningstar.co.jp/new_fund/sr_detail_snap.asp?fnc=51311021

The fund name is the alphanumerical characters after "fnc=" (in this
case, it's 51311021)

=head1 LABELS RETURNED

Information available from Japanese funds may include the following labels:

 symbol
 name
 last
 date
 currency
 net
 method

The prices are updated at the end of each bank day.

=cut
