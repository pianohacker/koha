#!/usr/bin/perl
package Koha::Service::Items;

# This file is part of Koha.
#
# Copyright (C) 2014 ByWater Solutions
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 NAME

svc/patrons - Web service for getting patron information

=head1 SYNOPSIS

  GET /svc/patrons/BORROWERNUMBER

=head1 DESCRIPTION

This service is used to query and change patron information.

=head1 METHODS

=cut

use Modern::Perl;

use base 'Koha::Service';

use C4::Auth;
use C4::Biblio;
use C4::Circulation;
use C4::Context;
use C4::Dates;
use C4::Items;
use C4::Members;
use C4::Reserves;
use Koha::DateUtils;

sub new {
    my ( $class ) = @_;

    # Authentication is handled manually below
    return $class->SUPER::new( {
        needed_flags => { circulate => 'circulate_remaining_permissions' },
        routes => [
            [ qr'POST /([^,/]+(?:,[^,/]+)*)', 'checkin', [ 'checkedin' ] ],
        ]
    } );
}

=head2 checkin

=over 4

POST /svc/items/BARCODE,BARCODE.../?checkedin=1

=back

Checks in item(s)

=cut

sub checkin {
    my ( $self, $barcodes ) = @_;

    my @items = split /,/, $barcodes;

    my $branch = C4::Context->userenv ? C4::Context->userenv->{'branch'} : '';
    my $dropboxmode = $self->query->param('dropboxmode');

    my $return_date_override = $self->query->param('return_date_override');
    if ( $return_date_override ) {
        $return_date_override = dt_from_string( $return_date_override );
        $return_date_override->set_hour(23);
        $return_date_override->set_minute(59);
    }

    my $exemptfine  = $self->query->param('exemptfine');
    if (
      $exemptfine &&
      !C4::Auth::haspermission(C4::Context->userenv->{'id'}, {'updatecharges' => 'writeoff'})
    ) {
        # silently prevent unauthorized operator from forgiving overdue
        # fines by manually tweaking form parameters
        undef $exemptfine;
    }

    my @responses;
    foreach my $barcode (@items) {
        my ( $returned, $messages, $issueinformation, $borrower ) = AddReturn( 
                $barcode, $branch, $exemptfine, $dropboxmode, $return_date_override );

        push @responses, {
                barcode => $barcode, 
                returned => $returned, 
                messages => $messages,
                issueinformation => $issueinformation,
                borrower => $borrower
                };
    }

    return { responses => \@responses };
}

1;