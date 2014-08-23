#!/usr/bin/perl

package Koha::Service::Config::SystemPreferences;

# This file is part of Koha.
#
# Copyright 2009 Jesse Weaver
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

use C4::Context;
use C4::Log;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { parameters => 1 },
        routes => [
            [ qr'POST /([A-Za-z0-9_-]+)', 'set_single_preference' ],
            [ qr'POST /', 'set_preferences' ],
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

sub set_single_preference {
    my ( $self, $preference ) = @_;

    unless ( C4::Context->config('demo') ) {
        my $value = join( ',', $self->query->param( 'value' ) || '' );
        C4::Context->set_preference( $preference, $value );
        logaction( 'SYSTEMPREFERENCE', 'MODIFY', undef, $preference . " | " . $value );
    }

    return {};
}

=head2 set_preferences

=over 4

POST /svc/config/systempreferences/

pref_$pref1=$value1&pref_$pref2=$value2

=back

Used to set several system preferences at once. Each preference you want to set
should be sent prefixed with pref. If you wanted to turn off the
virtualshelves syspref, for instance, you would POST the following:

pref_virtualshelves=0

=cut

sub set_preferences {
    my ( $self ) = @_;

    unless ( C4::Context->config( 'demo' ) ) {
        foreach my $param ( $self->query->param() ) {
            my ( $pref ) = ( $param =~ /pref_(.*)/ );

            next if ( !defined( $pref ) );

            my $value = join( ',', $self->query->param( $param ) );

            C4::Context->set_preference( $pref, $value );
            logaction( 'SYSTEMPREFERENCE', 'MODIFY', undef, $pref . " | " . $value );
        }
    }

    return {};
}

1;
