#!/usr/bin/perl

package Koha::Service::BibProfile;

# This file is part of Koha.
#
# Copyright 2007 LibLime
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

use Modern::Perl;

use base 'Koha::Service';

use C4::Context;
use C4::Koha;
use XML::Simple;

sub new {
    my ( $class ) = @_;

    # Authentication is handled manually below
    return $class->SUPER::new( {
        authnotrequired => 1,
        needed_flags => { editcatalogue => 'edit_catalogue'},
        routes => [
            [ qr'GET /(\d+)', 'fetch_bib' ],
            [ qr'POST /(\d+)', 'update_bib' ],
        ]
    } );
}

sub run {
    my ( $self ) = @_;

    $self->authenticate;

    unless ( $self->auth_status eq "ok" ) {
        $self->output( XMLout( { auth_status => $self->auth_status }, NoAttr => 1, RootName => 'response', XMLDecl => 1 ), { type => 'xml', status => '403 Forbidden' } );
        exit;
    }

    # get list of required tags
    my $result = {};
    $result->{'auth_status'} = $self->auth_status;
    _get_mandatory_tags($result);
    _get_mandatory_subfields($result);
    _get_reserved_tags($result);
    _get_bib_number_tag($result);
    _get_biblioitem_itemtypes($result);

    $self->output(
        XMLout(
            $result,
            NoAttr => 1,
            RootName => 'response',
            XMLDecl => 1,
            GroupTags => {mandatory_tags => 'tag', mandatory_subfields => 'subfield', reserved_tags => 'tag', valid_values => 'value'}
        ),
        { type => 'xml', status => '403 Forbidden' }
    );
}

sub _get_mandatory_tags {
    my $result = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare_cached("SELECT tagfield FROM marc_tag_structure WHERE frameworkcode = '' AND mandatory = 1");
    $sth->execute();
    my @tags = ();
    while (my $row = $sth->fetchrow_arrayref) {
        push @tags, $row->[0];
    }
    $result->{'mandatory_tags'} = \@tags;
}

sub _get_mandatory_subfields {
    my $result = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare_cached("SELECT tagfield, tagsubfield
                                    FROM marc_subfield_structure
                                    WHERE frameworkcode = ''
                                    AND tagsubfield <> '\@'
                                    AND kohafield <> 'biblioitems.itemtype'
                                    AND mandatory = 1");
    $sth->execute();
    my @subfields = ();
    while (my $row = $sth->fetchrow_arrayref) {
        push @subfields, { tag => $row->[0], subfield_label => $row->[1] };
    }
    $result->{'mandatory_subfields'} = \@subfields;
}

sub _get_reserved_tags {
    my $result = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare_cached("SELECT DISTINCT tagfield
                                    FROM marc_subfield_structure
                                    WHERE frameworkcode = ''
                                    AND (kohafield = 'items.itemnumber' OR kohafield = 'biblioitems.itemtype' OR
                                         kohafield = 'biblio.biblionumber')");
    $sth->execute();
    my @tags = ();
    while (my $row = $sth->fetchrow_arrayref) {
        push @tags, $row->[0];
    }
    $result->{'reserved_tags'} = \@tags;
}

sub _get_bib_number_tag {
    my $result = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare_cached("SELECT tagfield, tagsubfield
                                    FROM marc_subfield_structure
                                    WHERE frameworkcode = ''
                                    AND kohafield = 'biblio.biblionumber'");
    $sth->execute();
    my @tags = ();
    while (my $row = $sth->fetchrow_arrayref) {
        push @tags, { tag => $row->[0], subfield => $row->[1] };
    }
    $result->{'bib_number'} = \@tags;
}

sub _get_biblioitem_itemtypes {
    my $result = shift;
    my $dbh = C4::Context->dbh;
    my $itemtypes = GetItemTypes;
    my $sth = $dbh->prepare_cached("SELECT tagfield, tagsubfield
                                    FROM marc_subfield_structure
                                    WHERE frameworkcode = ''
                                    AND kohafield = 'biblioitems.itemtype'");
    $sth->execute();
    my @tags = ();
    while (my $row = $sth->fetchrow_arrayref) {
        push @tags, { tag => $row->[0], subfield => $row->[1] };
    }
    my @valid_values = map { { code => $_,  description => $itemtypes->{$_}->{'description'} } } sort keys %$itemtypes;
    $result->{'special_entry'} = { field => \@tags,  valid_values => \@valid_values };
}

1;
