package Finance::Quote::MorningstarJP;
require 5.005;

use strict;

use vars
  qw/$VERSION $MORNINGSTAR_SNAPSHOT_JP_URL $MORNINGSTAR_OLD_SNAPSHOT_JP_URL $MORNINGSTAR_BASIC_JP_URL $MORNINGSTAR_RATING_JP_URL/;

use Encode;
use LWP::UserAgent;
use HTTP::Request::Common;
use Web::Scraper;

$VERSION = '1.2';

$MORNINGSTAR_SNAPSHOT_JP_URL =
  'http://www.morningstar.co.jp/FundData/SnapShot.do?fnc=';

$MORNINGSTAR_OLD_SNAPSHOT_JP_URL =
  'http://www.morningstar.co.jp/new_fund/sr_detail_snap.asp?fnc=';

sub methods { return ( morningstar_jp => \&morningstar_jp ); }

{
    my @labels = qw/symbol name last isodate date currency net p_change method/;

    sub labels { return ( morningstar_jp => \@labels ); }
}

sub morningstar_jp {
    my $quoter  = shift;
    my @symbols = @_;

    return unless @symbols;

    my ( $user_agent, $snapshot_url, $snapshot_reply, $snapshot_content,
        $snapshot_root, $snapshot_parser, $new_symbol, %funds );

    foreach my $symbol (@symbols) {
        $user_agent = $quoter->user_agent;

        # Getting new symbol
        unless ( _is_new_symbol($symbol) ) {
            $snapshot_url   = $MORNINGSTAR_OLD_SNAPSHOT_JP_URL . $symbol;
            $snapshot_reply = $user_agent->request( GET($snapshot_url) );
            unless ( $snapshot_reply->is_success() ) {
                $funds{ $symbol, 'success' }  = 0;
                $funds{ $symbol, 'errormsg' } = 'HTTP failure';
                next;
            }

            $new_symbol = _get_new_symbol( $snapshot_reply->decoded_content );
            unless ( defined $new_symbol ) {
                $funds{ $symbol, 'success' }  = 0;
                $funds{ $symbol, 'errormsg' } = 'Unable to get new fund code';
                next;
            }
        }

        $snapshot_url   = $MORNINGSTAR_SNAPSHOT_JP_URL . $new_symbol;
        $snapshot_reply = $user_agent->request( GET($snapshot_url) );
        unless ( $snapshot_reply->is_success() ) {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'HTTP failure';
            next;
        }

        my $parse_result = _parse_snapshot( $snapshot_reply->decoded_content );
        if (
               defined $parse_result->{name}
            || defined $parse_result->{date}
            || defined $parse_result->{last}
            || (   defined $parse_result->{plus_change}
                || defined $parse_result->{minus_change} )
          )
        {
            $funds{ $symbol, 'name' } = encode( 'utf8', $parse_result->{name} );
            $funds{ $symbol, 'symbol' }     = $symbol;
            $funds{ $symbol, 'new_symbol' } = $new_symbol;
            $funds{ $symbol, 'currency' }   = 'JPY';
            $funds{ $symbol, 'timezone' }   = 'Asia/Japan';
            $funds{ $symbol, 'success' }    = 1;
            $funds{ $symbol, 'method' }     = 'morningstar_jp';
            $funds{ $symbol, 'isodate' }    = $parse_result->{isodate};
            $funds{ $symbol, 'date' }       = $parse_result->{date};
            $funds{ $symbol, 'last' }       = $parse_result->{last};

            if ( defined $parse_result->{plus_change} ) {
                $funds{ $symbol, 'net' } =
                  _build_plus_net( $parse_result->{plus_change} );
                $funds{ $symbol, 'p_change' } =
                  _build_plus_p_change( $parse_result->{plus_change} );
            }
            elsif ( defined $parse_result->{minus_change} ) {
                $funds{ $symbol, 'net' } =
                  _build_minus_net( $parse_result->{minus_change} );
                $funds{ $symbol, 'p_change' } =
                  _build_minus_p_change( $parse_result->{minus_change} );
            }
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
        elsif (!defined $parse_result->{plus_change}
            || !defined $parse_result->{minus_change} )
        {
            $funds{ $symbol, 'success' }  = 0;
            $funds{ $symbol, 'errormsg' } = 'Parse net error';
            next;
        }
    }

    return %funds if wantarray;
    return \%funds;
}

sub _parse_snapshot {
    my $content = shift;

    my $scraper = scraper {
        process '.fundname', 'name' => 'TEXT';
        process 'span.fprice', 'last' => [ 'TEXT', sub { tr/0-9//cd; } ];
        process '//table[@class="tpdt"]/tr[3]/td[1]',
          'date' => [ 'TEXT', \&_build_date ];
        process '//table[@class="tpdt"]/tr[3]/td[1]',
          'isodate' => [ 'TEXT', \&_build_isodate ];
        process '.plus.fprice',  'plus_change'  => 'TEXT';
        process '.minus.fprice', 'minus_change' => 'TEXT';
    };

    my $result = $scraper->scrape($content);
    return $result;
}

sub _parse_old_snapshot {
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

        process '.stextgray',
          'new_symbol' => [ 'TEXT', sub { ( split /\s/, $_ )[1] } ];
    };

    my $result = $scraper->scrape($content);
    return $result;
}

sub _is_new_symbol {
    my $symbol = shift;

    if ( $symbol =~ /\d{10}/ ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _get_new_symbol {
    my $content = shift;
    my $result  = _parse_old_snapshot($content);
    return $result->{new_symbol};
}

sub _build_date {
    my $date = shift;
    my ( $yyyy, $mm, $dd ) = _parse_jp_date($date);
    if ( $yyyy || $mm || $dd ) {
        sprintf "%02d/%02d/%04d", $mm, $dd, $yyyy;
    }
}

sub _build_isodate {
    my $date = shift;
    my ( $yyyy, $mm, $dd ) = _parse_jp_date($date);
    if ( $yyyy || $mm || $dd ) {
        sprintf "%04d-%02d-%02d", $yyyy, $mm, $dd;
    }
}

sub _parse_jp_date {
    my $date = shift;
    if ( $date =~ /(\d{4})\x{5e74}(\d{2})\x{6708}(\d{2})\x{65e5}/ ) {
        return ( $1, $2, $3 );
    }
}

sub _parse_date {
    my $str = shift;
    if ( $str =~ /\((.*)\)/ ) {
        my ( $yyyy, $mm, $dd ) = split '-', $1;
        return sprintf "%02d/%02d/%d", $mm, $dd, $yyyy;
    }
}

sub _build_plus_net {
    my $change = shift;
    my $result = _parse_change($change);
    if ($result) {
        return $result->{net};
    }
}

sub _build_plus_p_change {
    my $change = shift;
    my $result = _parse_change($change);
    if ($result) {
        return $result->{p_change};
    }
}

sub _build_minus_net {
    my $change = shift;
    my $result = _parse_change($change);
    if ($result) {
        return $result->{net} * -1;
    }
}

sub _build_minus_p_change {
    my $change = shift;
    my $result = _parse_change($change);
    if ($result) {
        return $result->{p_change} * -1;
    }
}

sub _parse_change {
    my $change = shift;
    if ( $change =~ /(\d+)\x{5186}\x{ff08}(.*)\x{ff05}\x{ff09}/ ) {
        return { net => $1, p_change => $2 };
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

 http://www.morningstar.co.jp/FundData/SnapShot.do?fnc=1986103001

The fund name is the alphanumerical characters after "fnc=" (in this
case, it's 1986103001)

=head1 LABELS RETURNED

Information available from Japanese funds may include the following labels:

 symbol
 name
 last
 date
 isodate
 currency
 net
 p_change
 method

The prices are updated at the end of each bank day.

=cut
