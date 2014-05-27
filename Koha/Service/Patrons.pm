#!/usr/bin/perl
package Koha::Service::Patrons;

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

use C4::Biblio;
use C4::Context;
use C4::Dates;
use C4::Members;
use C4::Reserves;

sub new {
    my ( $class ) = @_;

    # Authentication is handled manually below
    return $class->SUPER::new( {
        needed_flags => { circulate => 'circulate_remaining_permissions' },
        routes => [
            [ qr'POST /(\d+)/checkouts', 'add_checkout'],
            [ qr'GET /(\d+)/checkouts', 'get_checkouts' ],
            [ qr'GET /(\d+)/holds', 'get_holds' ],
            [ qr'GET /(\d+)/patronInfo', 'get_patron_info' ],
        ]
    } );
}

=head2 get_checkouts

=over 4

POST /svc/patrons/BORROWERNUMBER/checkouts

=back

Checks out an item

=cut

sub add_checkouts {
    my ( $self, $borrowernumber ) = @_;

    my $datedue;
    my $duedatespec = $self->query->param('duedate');

    if ( C4::Context->preference('SpecifyDueDate') && $duedatespec ){
        if ($duedatespec =~ C4::Dates->regexp('syspref')) {
            $datedue = dt_from_string($duedatespec);
        } else {
            return {errors => {INVALID_DATE=>$duedatespec}};
        }
    }

    my ($barcode) = $self->require_params('barcode');

    my $borrower = GetMember( borrowernumber => $borrowernumber );

    my ( $errors, $questions, $alerts ) =
    CanBookBeIssued( $borrower, $barcode, $datedue );

    if ( %$errors || ( %$questions && !$self->query->param('confirmed') ) ) {
        return { errors => $errors, questions => $questions, alerts => $alerts };
    }

    AddIssue( $borrower, $barcode, $datedue );

    return {};
}

=head2 get_holds

=over 4

GET /svc/patrons/BORROWERNUMBER/holds

=back

Retrieves information on the holds for a patron.

=cut

sub get_holds {
    my ( $self, $borrowernumber ) = @_;

    my @holds = GetReservesFromBorrowernumber($borrowernumber);
    foreach my $hold (@holds) {
        my $getiteminfo = GetBiblioFromItemNumber( $hold->{'itemnumber'} );
        $hold->{title} = $getiteminfo->{title};
        $hold->{author} = $getiteminfo->{author};
        $hold->{barcode} = $getiteminfo->{barcode};
    }

    return { holds => \@holds };
}

=head2 get_checkouts

=over 4

GET /svc/patrons/BORROWERNUMBER/checkouts

=back

Retrieves information on the checkouts for a patron.

=cut

sub get_checkouts {
    my ( $self, $borrowernumber ) = @_;

    return { checkouts => GetPendingIssues( $borrowernumber ) };
}

=head2 get_patron_info

=over 4

GET /svc/patrons/BORROWERNUMBER/patronInfo

=back

Retrieves information on a patron.

=cut

sub get_patron_info {
    my ( $self, $borrowernumber ) = @_;

    return { patronInfo => GetMemberDetails( $borrowernumber, 0 ) };
}

1;
