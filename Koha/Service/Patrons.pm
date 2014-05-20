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

svc/config/systempreferences - Web service for setting system preferences

=head1 SYNOPSIS

  POST /svc/config/systempreferences/

=head1 DESCRIPTION

This service is used to set system preferences, either one at a time or in
batches.

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

=head2 set_single_preference

=over 4

POST /svc/config/systempreferences/$preference

value=$value

=back

Used to set a single system preference.

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

sub get_checkouts {
    my ( $self, $borrowernumber ) = @_;

    return { checkouts => GetPendingIssues( $borrowernumber ) };
}

1;
