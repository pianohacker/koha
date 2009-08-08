package C4::Inventory;

# Copyright (C) 2009 LibLime
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

use C4::Context;
use C4::Koha;
use C4::Biblio;
use C4::Items;
use C4::Charset;
use Memoize;

our ($VERSION, @EXPORT);

use base qw( Exporter );

BEGIN {
	# set the version for version checking
	$VERSION = 0.01;
	@EXPORT = qw(
        CheckInventory
        GetInventoryList
        AddInventoryList
	);
}

our $item_details_base = "
    SELECT 
      biblio.biblionumber, itemnumber, barcode,
      title, author, biblioitems.itemtype, itemcallnumber,
      itemtypes.description as itemtype_description, location, ccode,
      items.holdingbranch, branches.branchname as holdingbranch_description,
      itemlost, damaged, wthdrawn, onloan
      FROM items
        LEFT JOIN biblioitems ON (biblioitems.biblioitemnumber = items.biblioitemnumber)
        LEFT JOIN biblio ON (biblioitems.biblionumber = biblio.biblionumber)
        LEFT JOIN itemtypes ON (itemtypes.itemtype = biblioitems.itemtype)
        LEFT JOIN branches ON (branches.branchcode = items.holdingbranch)
";

=head1 NAME

C4::Inventory

=cut

sub CheckInventory {
    my (%args) = @_;
    my $dbh = C4::Context->dbh;
    
    our $where_clauses = [];
    our $query_params = [];

    my ( @nonexistent, @missing, @erroneous );
    my @scanned_items;
    my $required_items;

    sub _add_condition {
        my ( $column, $values ) = @_;

        if ( ref( $values ) eq 'ARRAY' ) {
            return unless ( @$values );
            push @$where_clauses, "$column IN (" . join( ', ', ( '?' ) x scalar( @$values ) ) . ')';
            push @$query_params, @$values;
        } elsif ( $values ) {
            push @$where_clauses, "$column = ?";
            push @$query_params, $values;
        }
    }

    my $sql = $item_details_base . "
          WHERE
            itemlost = 0 AND
            damaged = 0 AND
            wthdrawn = 0 AND
            (items.onloan IS NULL)
    ";

    _add_condition( 'items.holdingbranch', $args{'branchcode'} );
    _add_condition( 'biblioitems.itemtype', $args{'itemtype'} );
    _add_condition( 'items.location', $args{'location'} );
    _add_condition( 'items.ccode', $args{'collection'} );

    if ( $args{'mincallnumber'} && $args{'maxcallnumber'} ) {
        push @$where_clauses, 'itemcallnumber BETWEEN ? AND ?';
        push @$query_params, $args{'mincallnumber'}, $args{'maxcallnumber'};
    }

    use Data::Dumper; warn Data::Dumper->new([ \%args ])->Indent(0)->Terse(1)->Dump();

    if ( @$where_clauses ) {
        $sql .= ' AND ' . join( ' AND ', @$where_clauses ) ;
    } else {
        die "No condition specified; will not show entire checked-in collection";
    }
    $required_items = $dbh->selectall_hashref( $sql, 'itemnumber', {}, @$query_params );
    $sql =~ s/\s+/ /gm;
    warn $sql;
    my %item_cache = %$required_items; # Create a copy
    my $mem_get_item = memoize( \&_get_item, SCALAR => [ HASH => \%item_cache ] );

    if ( $args{'items'} ) {
        @scanned_items = @{ $args{'items'} };
    } elsif ( $args{'barcodes_file'} ) {
        my $item = {};
        my $fh = $args{'barcodes_file'};
        while ( <$fh> ) {
            my ($barcode) = ( $_ =~ /^([a-zA-Z0-9]+)/ ); #Extract the first alphanumeric word from the line
            my $itemnumber = _get_itemnumber_from_barcode( $barcode );
            if ( !$itemnumber ) {
                push @nonexistent, { barcode => $barcode, map( +( "last_$_", $item->{$_} ), keys %$item ) };
                next;
            }
            $item = $mem_get_item->( $itemnumber );
            push @scanned_items, $itemnumber;
        }
    }

    foreach my $scanned_item ( @scanned_items ) {
        ModDateLastSeen( $scanned_item );

        if ( $required_items->{$scanned_item} ) {
            delete $required_items->{$scanned_item};
            next;
        }

        # Wasn't found in the list of items to check against. Erroneous!
        my %row = %{ $mem_get_item->( $scanned_item ) };
        $row{'location_description'} = _get_authorised_description( 'items.location', $row{'location'} ) if ( $row{'location'} );
        $row{'ccode_description'} = _get_authorised_description( 'items.ccode', $row{'ccode'} ) if ( $row{'ccode'} );
        $row{'itemlost_description'} = _get_authorised_description( 'items.itemlost', $row{'itemlost'} ) if ( $row{'itemlost'} );
        $row{'damaged_description'} = _get_authorised_description( 'items.damaged', $row{'damaged'} ) if ( $row{'damaged'} );
        $row{'wthdrawn_description'} = _get_authorised_description( 'items.wthdrawn', $row{'wthdrawn'} ) if ( $row{'wthdrawn'} );
  
        $row{'callnumber_wrong'} = 1 if (
            ( $args{'mincallnumber'} && $args{'maxcallnumber'} ) &&
            ( $row{'itemcallnumber'} lt $args{'mincallnumber'} || $row{'itemcallnumber'} gt $args{'maxcallnumber'} )
        );

        $row{'is_lost'} = 1 if ( $row{'itemlost'} );
        $row{'is_damaged'} = 1 if ( $row{'damaged'} );
        $row{'is_wthdrawn'} = 1 if ( $row{'wthdrawn'} );
        $row{'is_checked_out'} = 1 if ( $row{'onloan'} );

        _check_field( \%row, \%args, 'branchcode', 'items.holdingbranch' );
        _check_field( \%row, \%args, 'itemtype', 'biblioitems.itemtype' );
        _check_field( \%row, \%args, 'location', 'items.location' );
        _check_field( \%row, \%args, 'collection', 'items.ccode' );
        
        push @erroneous, \%row;
    }

    @missing = values %$required_items;

    return \@nonexistent, [ sort _callnumber_title @missing ], [ sort _callnumber_title @erroneous ];
}

sub _get_item {
    my ( $itemnumber ) = @_;

    return C4::Context->dbh->selectrow_hashref( $item_details_base . 'WHERE itemnumber = ?', {}, $itemnumber );
}

sub _get_itemnumber_from_barcode {
    my ( $barcode ) = @_;
    return C4::Context->dbh->selectrow_array( "SELECT itemnumber FROM items WHERE barcode = ?", {}, $barcode);
}

sub _get_authorised_description {
    my ( $kohafield, $value ) = @_;
    my $authvals = GetKohaAuthorisedValues( $kohafield );

    return $authvals ? ( $authvals->{$value} || '' ) : '';
}

sub _check_field {
    my ( $row, $args, $field, $kohafield ) = @_;
    return unless( $args->{$field} );

    my $value = $row->{( split( /\./, $kohafield ) )[1]};

    if ( ref( $args->{$field} ) && ref( $args->{$field} ) eq 'ARRAY' ) {
        my @values = @{ $args->{$field} };
        return if ( !@values || grep { $_ eq $value } @values );

        $row->{"${field}_wrong"} = 1;
        $row->{"${field}_possible_values"} = [ map +{ description => _get_authorised_description( $kohafield, $_ ) }, @values ];
    } else {
        return if ( !$value || $value eq $args->{$field} );
        $row->{"${field}_wrong"} = 1;
        $row->{"${field}_possible_values"} = [ { description => _get_authorised_description( $kohafield, $value ) } ];
    }
}

sub _callnumber_title {
    if ( ( $a->{'itemcallnumber'} || '' ) eq ( $b->{'itemcallnumber'} || '' ) ) {
        return ( $a->{'title'} || '' ) cmp ( $b->{'title'} || '' );
    } else {
        return ( $a->{'itemcallnumber'} || '' ) cmp ( $b->{'itemcallnumber'} || '' );
    }
}

sub GetInventoryList {
}

sub AddInventoryList {
}

1;
__END__

=head1 AUTHOR

Koha Development Team <info@koha.org>

Jesse Weaver <pianohacker@gmail.com>

=cut
