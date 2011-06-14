#!/usr/bin/perl
#
# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA
#
#-----------------------------------
# Script Name: zed-koha-server.pl
# Script Version: 1.3
# Date:  2004/04/14
# Author:  Joshua Ferraro [jmf at kados dot org]
# Description: A very basic Z3950 Server 
# Usage: zed-koha-server.pl
# Revision History:
#    0.00  2003/08/14:     Original version; search works.
#    0.01  2003/10/02:     First functional version; search and fetch working
#                           records returned in USMARC (ISO2709) format,     
#             Bath compliant to Level 1 in Functional Areas A, B.
#    0.02  2004/04/14:  Cleaned up documentation, etc. No functional 
#                 changes.
#    1.30  2004/04/22:    Changing version numbers to correspond with CVS;
#                 Fixed the substitution bug (e.g., 4=100 before 4=1);
#                 Added support for the truncation attribute (5=1 and
#                 5=100; thanks to Tomasz M. Wolniewicz for pointing
#                 out these improvements)
#    2.2.9 2008/04/05: Updated for latest Koha; added better support
#                for different item tags, availability information in
#                852$r; fixed @bib_list to consistently use biblionumbers
#-----------------------------------
# Note: After installing SimpleServer (indexdata.dk/simpleserver) and 
# changing the leader information in Koha's MARCgetbiblio subroutine in
# Biblio.pm you can run this script as root:
# 
# ./zed-koha-server.pl
#
# and the server will start running on port 9999 and will allow searching
# and retrieval of records in MARC21 (USMARC; ISO2709) bibliographic format.
# ----------------------------------
use strict;
use warnings;

use Net::Z3950::OID;
use Net::Z3950::SimpleServer;

use MARC::Record;
use C4::Context;
use C4::Dates;
use C4::Biblio;
use C4::Reserves;
use C4::Search;

Net::Z3950::SimpleServer->new(
    INIT => \&init_handler,
    SEARCH => \&search_handler,
    FETCH => \&fetch_handler
)->launch_server( "z3950-responder.pl", @ARGV );

sub init_handler {
    my $args = shift;
    my $session = {};

    # FIXME: I should force use of my database name 
    $args->{'IMP_NAME'} = "Zed-Koha-JCFL";
    $args->{'IMP_VER'} = "3.2.x";
    $args->{'ERR_CODE'} = 0;
    $args->{'HANDLE'} = {};
}

# Very possibly unnecessary
sub _setname { return shift->{'SETNAME'} || '_results' }

sub search_handler {        
    my ( $args ) = @_;
    ## Place the user's query into a variable 
   
    my ( $error, $marcresults, $count ) = SimpleSearch( $args->{'QUERY'}, undef, undef, undef, 'pqf' );
    if ( $error ) {
        $args->{'ERR_CODE'} = 2; # Bib-1 temporary system error
        $args->{'ERR_STR'} = "Upstream error: $error";
        return;
    }

    $args->{'HITS'} = $count;
    $args->{'HANDLE'}->{_setname( $args )} = $marcresults; # Decode on fetch 
}

sub fetch_handler {
    my ( $args ) = @_;

    return unless ( $args->{'HANDLE'}->{_setname( $args )} );
    my $record = $args->{'HANDLE'}->{_setname( $args )}->[$args->{'OFFSET'} - 1] or return;

    $args->{'REP_FORM'} = &Net::Z3950::OID::usmarc;

    if ( ref( $record ) eq 'MARC::Record' ) {
        $args->{'RECORD'} = $record->as_usmarc;

        return;
    }

    $record = MARC::File::USMARC::decode( $record );

    my $record_data = TransformMarcToKoha( undef, $record, '' );

    my ( $itemtag, $itemnumsubfield ) = GetMarcFromKohaField( "items.itemnumber", '' );

    my @item_tags = $record->field( $itemtag );
    foreach my $item_tag ( @item_tags ) {   #get all 952s
        my $item_record = new MARC::Record();
        $item_record->append_fields( $item_tag );
        my $item = TransformMarcToKoha( undef, $item_record, '' );
        my $itemnumber = $item->{'itemnumber'};

        my $availability;

        my ( $status, $reserve ) = CheckReserves( $item->{'itemnumber'}, $item->{'barcode'} );

        if ( $status ne '0' ) {
            $availability = 'On hold';
        } elsif ( $item->{'itemlost'} ) {
            $availability = 'Lost';
        } elsif ( $item->{'onloan'} ) {
            $availability = 'Due on ' . C4::Dates->new( $item->{'onloan'}, 'iso' )->output;
        } else {
            $availability = 'Available';
        }

        #make it one big happy family
        my $new852 = MARC::Field->new(
            852,'','',
            'a' => C4::Context->preference( 'LibraryName' ),
            'b' => $item->{'holdingbranch'} || $item->{'homebranch'} || 'MAIN',
            'h' => $item->{'itemcallnumber'} || $record_data->{'classification'},
            'k' => $record_data->{'itemtype'},
            'p' => $item->{'barcode'},
            'y' => $availability,
        );
        $record->insert_fields_ordered( $new852 );
        $record->delete_field( $item_tag );
    }

    $args->{'HANDLE'}->{_setname( $args )}->[$args->{'OFFSET'} - 1] = $record;

    $args->{'RECORD'} = $record->as_usmarc();
}
