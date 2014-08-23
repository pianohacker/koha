#!/usr/bin/perl

package Koha::Service::CoverImages;

# This file is part of Koha.
#
# Copyright 2013 Universidad Nacional de Cordoba
#                Tomas Cohen Arazi
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

use base 'Koha::Service';

use C4::Images;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { tools => 'upload_local_cover_images' }
    } );
}

sub run {
    my ( $self ) = @_;

    $self->authenticate;

    my $action       = $self->query->param('action');
    my $biblionumber = $self->query->param('biblionumber');
    my @imagenumbers = $self->query->param('imagenumber');

    # Array to store the reponse JSON
    my $response = [];

    if ( $action eq "delete" ) {
        # Build a hash of valid imagenumbers fr the given biblionumber
        my %valid_imagenumbers = map {$_ => 1} ListImagesForBiblio($biblionumber);

        foreach my $imagenumber ( @imagenumbers ) {
            if ( exists( $valid_imagenumbers{ $imagenumber } ) ) {
                DelImage($imagenumber);
                push @$response, {
                    imagenumber => $imagenumber,
                    deleted => 1
                };
            } else {
                push @$response, {
                    imagenumber => $imagenumber,
                    deleted => 0,
                    error => "MSG_INVALID_IMAGENUMBER"
                };
            }
        }
    } else {
        # invalid action
        $self->croak( 'invalid_action' );
    }

    return $response;
}

1;
