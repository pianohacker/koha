package Koha::Service::Bib;

# This file is part of Koha.
#
# Copyright 2007 LibLime
# Copyright 2012 software.coop and MJ Ray
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

use C4::Biblio;
use C4::Items;
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

    $self->dispatch;
}

sub fetch_bib {
    my ( $self, $biblionumber ) = @_;

    my $record = GetMarcBiblio( $biblionumber, $self->query->url_param('items') );

    if (defined $record) {
        $self->output( $record->as_xml_record(), { type => 'xml' } );
    } else {
        $self->output( '', { status => '404 Not Found', type => 'xml' } );
    }
}

sub update_bib {
    my ( $self, $biblionumber ) = @_;

    my $old_record = GetMarcBiblio($biblionumber);
    unless  (defined $old_record) {
        $self->output( '', { status => '404 Not Found', type => 'xml' } );
        return;
    }

    my $result = {};
    my $inxml = $self->query->param('POSTDATA');
    use Data::Dumper; warn Dumper($self->query);

    my $record = eval {MARC::Record::new_from_xml( $inxml, "utf8", C4::Context->preference('marcflavour'))};
    my $do_not_escape = 0;
    if ($@) {
        $result->{'status'} = "failed";
        $result->{'error'} = $@;
    } else {
        my $fullrecord = $record->clone();
        my ( $itemtag, $itemsubfield ) =
          GetMarcFromKohaField( "items.itemnumber", '' );

        # delete any item tags
        foreach my $field ( $record->field($itemtag) ) {
            $record->delete_field($field);
        }

        if ( $self->query->url_param('items') ) {
            foreach my $field ( $fullrecord->field($itemtag) ) {
                my $one_item_record = $record->clone();
                $one_item_record->add_fields($field);
                ModItemFromMarc( $one_item_record, $biblionumber,
                    $field->subfield($itemsubfield) );
            }
        }

        ModBiblio( $record, $biblionumber, '' );
        my $new_record =
          GetMarcBiblio( $biblionumber, $self->query->url_param('items') );

        $result->{'status'} = "ok";
        $result->{'biblionumber'} = $biblionumber;
        my $xml = $new_record->as_xml_record();
        $xml =~ s/<\?xml.*?\?>//i;
        $result->{'marcxml'} =  $xml;
        $do_not_escape = 1;
    }
   
    $self->output( XMLout($result, NoAttr => 1, RootName => 'response', XMLDecl => 1, NoEscape => $do_not_escape), { type => 'xml' } ); 
}

1;
