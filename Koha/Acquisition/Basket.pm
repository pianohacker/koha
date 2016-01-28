package Koha::Acquisition::Basket;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;

use base qw(Koha::Object);

=head1 NAME

Koha::Acquisition::Basket - Koha Basket Object class

=head1 API

=head2 Class Methods

=head3 effective_create_items

Returns C<create_items> for this basket, falling back to C<AcqCreateItem> if unset.

=cut

sub effective_create_items {
    my ( $self ) = @_;

    return $self->create_items || C4::Context->preference('AcqCreateItem');
}

=head3 type

=cut

sub type {
    return 'Aqbasket';
}

1;
