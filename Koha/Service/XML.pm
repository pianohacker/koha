package Koha::Service::XML;

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

Koha::Service::XML - base class for XML webservices.

=head1 DESCRIPTION

Extends Koha::Service to output authentication errors and other results using XML by default.

=head1 METHODS

=cut

use base 'Koha::Service';

use XML::Simple;

=head2 output_simple

    $self->output_simple( $response[, \%options] );

Processes $response though XML::Simple, then calls C<output>.

See C<Koha::Service->output> for meaning of C<\%options>.

=cut

sub output_simple {
    my ( $self, $response, $options ) = @_;

    # Set defaults
    $options = {
        type => 'xml',
        %{ $options || {} },
    };

    $self->output( XMLout( $response, NoAttr => 1, RootName => 'response', XMLDecl => 1 ), $options );
}

sub handle_auth_failure {
    my ( $self ) = @_;

    if ( !$self->{authnotrequired} ) {
        $self->output_simple( { auth_status => $self->auth_status }, { type => 'xml', status => '403 Forbidden' } );
        exit;
    }
}

sub run {
    my ( $self ) = @_;

    $self->authenticate;
    my $result = $self->dispatch;
    $self->output( $result, { type => 'xml' } ) if ($result);
}

1;
