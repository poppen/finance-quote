#!/usr/bin/perl
#
#    Copyright (C) 2011, MATSUI Shinsuke <poppen.jp@gmail.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#    02111-1307, USA

package Finance::Quote::MorningstarJapan;

use 5.006;
use strict;
use warnings;
use Encode;
use HTTP::Request::Common;

use WWW::Scripter;
use Web::Scraper;

our $VERSION                   = '0.1';
our $MORNINGSTAR_JAPAN_ETF_URL = 'http://www.morningstar.co.jp/etf/';

my $_ERROR_DATE = "0000/00/00";

sub methods {
    return ( morningstarjapan_etf => \&etf );
}

{
    my @labels
        = qw/method source success name date isodate currency last volume nav/;
    sub labels { return ( morningstarjapan_etf => \@labels ); }
}

sub etf {
    my ( $quoter, @symbols ) = @_;
    return unless @symbols;

    my %info;

    my $w = WWW::Scripter->new;
    $w->use_plugin('JavaScript');
    $w->timeout( $quoter->user_agent->timeout );

    $w->get($MORNINGSTAR_JAPAN_ETF_URL);
    my $is_success = $w->follow_link( text => decode( 'utf8', '全銘柄' ) );
    if ($is_success) {
        %info = _scraper_etf( $w->content, @symbols );
    }
    else {
        foreach my $symbol (@symbols) {
            $info{ $symbol, 'success' }  = 0;
            $info{ $symbol, 'errormsg' } = "HTTP failure";
        }
        return wantarray ? %info : \%info;
    }

    # Check for undefined symbols
    foreach my $symbol (@symbols) {
        if ( !exists( $info{ $symbol, 'success' } ) ) {
            $info{ $symbol, 'success' }  = 0;
            $info{ $symbol, 'errormsg' } = "ETF symbol not found";
        }
    }

    return %info if wantarray;
    return \%info;
}

sub _scraper_etf {
    my ( $content, @symbols ) = @_;
    my %info = ();

    my $scraper = scraper {
        process '//tbody[@id="etftb"]/tr', 'etfs[]' => scraper {
            process '//td[1]', symbol => 'TEXT';    # コード
            process '//td[2]', name   => 'TEXT';    # ETF名
            process '//td[4]', date => [ 'TEXT', \&_build_date ];    # 日付
            process '//td[4]',
                isodate => [ 'TEXT', \&_build_isodate ];             # 日付
            process '//td[5]', last => [ 'TEXT', sub {tr/0-9//cd} ]; # 終値
            process '//td[6]',
                volume => [ 'TEXT', sub {tr/0-9//cd} ];    # 出来高
            process '//td[7]',
                nav => [ 'TEXT', sub { s/\(\d+\/\d+\)//; tr/0-9//cd } ]
                ;                                          # 基準価額
        };
    };

    my $result = $scraper->scrape($content);

    foreach my $etf ( @{ $result->{etfs} } ) {
        next unless grep( /^$etf->{symbol}$/, @symbols );
        my $symbol = $etf->{symbol};

        my $success = 1;
        $success = 0 if ( !defined $etf->{nav} || $etf->{nav} eq '' );
        $success = 0
            if ( !defined $etf->{date} || $etf->{date} eq $_ERROR_DATE );

        $info{ $symbol, 'success' }  = $success;
        $info{ $symbol, 'currency' } = 'JPY';
        $info{ $symbol, 'method' }   = 'morningstarjapan_etf';
        $info{ $symbol, 'source' }   = 'Finance::Quote::MorningstarJapan';
        $info{ $symbol, 'name' }     = encode( 'utf8', $etf->{name} );
        $info{ $symbol, 'isodate' }  = $etf->{isodate};
        $info{ $symbol, 'date' }     = $etf->{date};
        $info{ $symbol, 'last' }     = $etf->{last};
        $info{ $symbol, 'volume' }   = $etf->{volume};
        $info{ $symbol, 'nav' }      = $etf->{nav};
    }

    return %info;
}

sub _build_isodate {
    my $date = shift;
    my ( $yyyy, $mm, $dd ) = _parse_date($date);
    return sprintf '%04d-%02d-%02d', $yyyy, $mm, $dd;
}

sub _build_date {
    my $date = shift;
    my ( $yyyy, $mm, $dd ) = _parse_date($date);
    return sprintf '%02d/%02d/%04d', $mm, $dd, $yyyy;
}

sub _parse_date {
    my ( $date, @now ) = ( shift, localtime );
    if ( $date =~ /(\d{1,2})\/(\d{1,2})/ ) {

        # MM/DD
        my ( $yyyy, $mm, $dd ) = ( $now[5] + 1900, $1, $2 );
        $yyyy--
            if ( $now[4] + 1 < $mm ); # MM may point last December in January.
        return ( $yyyy, $mm, $dd );
    }
    else {
        return split( '/', $_ERROR_DATE );
    }
}

1;

=head1 NAME

Finance::Quote::MorningstarJapan - Fetch quote from morningstar Japan

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    # fetches information of "Listed Index Fund International 
    # Developed Countries Equity (MSCI kokusai)" ETF
    %etfinfo = $q->fetch("morningstarjapan_etf","1680");

=head1 DESCRIPTION

This module obtains information about fund from "morningstar 
Japan" http://www.morningstar.co.jp/.

Currently this module provides only a method for fetching ETF information, 
morningstarjapan_etf(). Searching ETF is based on Security code.

=head1 LABELS RETURNED

The following labels may be returned by this module : method, name,
date, isodate, currency, last, volume, nav.

=head1 SEE ALSO

Morningstar Japan, http://www.morningstar.co.jp/

Finance::Quote;

=cut
