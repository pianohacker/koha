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
use C4::Members;
use C4::Reserves;

sub new {
    my ( $class ) = @_;

    # Authentication is handled manually below
    return $class->SUPER::new( {
        needed_flags => { circulate => 'circulate_remaining_permissions' },
        routes => [
            [ qr'GET /(\d+)/holds', 'get_holds' ],
            [ qr'GET /(\d+)/checkouts', 'get_checkouts' ],
        ]
    } );
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

1;
