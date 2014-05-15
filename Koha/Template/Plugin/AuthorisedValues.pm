package Koha::Template::Plugin::AuthorisedValues;

# Copyright 2012 ByWater Solutions
# Copyright 2013-2014 BibLibre
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

use Modern::Perl;

use Template::Plugin;
use base qw( Template::Plugin );

use Encode qw{encode decode};

use C4::Koha;

sub GetByCode {
    my ( $self, $category, $code, $opac ) = @_;
    return encode( 'UTF-8', GetAuthorisedValueByCode( $category, $code, $opac ) );
}

sub Get {
    my ( $self, $category, $selected, $opac ) = @_;
    return GetAuthorisedValues( $category, $selected, $opac );
}

sub GetAuthValueDropbox {
    my ( $self, $category, $default ) = @_;
    return C4::Koha::GetAuthvalueDropbox($category, $default);
}

1;

=head1 NAME

Koha::Template::Plugin::AuthorisedValues - TT Plugin for authorised values

=head1 SYNOPSIS

[% USE AuthorisedValues %]

[% AuthorisedValues.GetByCode( 'CATEGORY', 'AUTHORISED_VALUE_CODE', 'IS_OPAC' ) %]

[% AuthorisedValues.GetAuthValueDropbox( $category, $default ) %]

=head1 ROUTINES

=head2 GetByCode

In a template, you can get the description for an authorised value with
the following TT code: [% AuthorisedValues.GetByCode( 'CATEGORY', 'AUTHORISED_VALUE_CODE', 'IS_OPAC' ) %]

The parameters are identical to those used by the subroutine C4::Koha::GetAuthorisedValueByCode.

=head2 GetAuthValueDropbox

The parameters are identical to those used by the subroutine C4::Koha::GetAuthValueDropbox

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

Jonathan Druart <jonathan.druart@biblibre.com>

=cut
