package C4::Letters::Print;

# Copyright 2000-2002 Katipo Communications
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
use C4::Context;

use vars qw($VERSION @ISA @EXPORT %units);

BEGIN {
	require Exporter;
	# set the version for version checking
	$VERSION = 3.01;
	@ISA = qw(Exporter);
	@EXPORT = qw(
	GetBranchPrintSettings
	ParseMarkup
	TransformMarkupToHtml
	);
}

# How many points per each one of these units

%units = (
	in => 72,
	cm => 72 / 2.54,
	mm => 72 / 25.4,
);

sub GetBranchPrintSettings {
	my ( $branchcode, $to_units ) = @_;
	my $dbh = C4::Context->dbh;
	my $result;

	if ( $branchcode && $branchcode ne '*' ) {
		$result = $dbh->selectrow_hashref( "
			SELECT *
			FROM branch_print_preferences
			WHERE branchcode = ? OR branchcode IS NULL
			ORDER BY branchcode IS NULL
			LIMIT 1
		", {}, $branchcode );
	} else {
		$result = $dbh->selectrow_hashref( "
			SELECT *
			FROM branch_print_preferences
			WHERE branchcode IS NULL
		", {} );
	}

	if ( !$result ) {
		$result = {
			page_margin => 0.5 * 72,
			page_width => 8.5 * 72,
			page_height => 11 * 72,
			letterhead_file => '',
			letterhead_bottom => 0,
			block_spacing => 12,
			font_family => 'Georgia',
			font_size => 12,
			line_height => 1.2, # As a multiple of font_size
			unit => 'in',
		};
	}

	if ( $to_units ) {
		foreach my $key ( qw( page_margin page_width page_height letterhead_bottom block_spacing ) ) {
			$result->{$key} = $result->{$key} / $units{$result->{unit}};
		}
	}

	return $result;
}

sub ParseMarkup {
	my $markup = shift;

	my @blocks = split /\n\n/, $markup;
	my @results;

	BLOCK: foreach my $block (@blocks) {
		if ($block =~ /^\|.*\|$/m) {
			my @rows = ();
			my @row_cell_props = ();

			foreach my $line (split /\n/, $block) {
				if ($line !~ /^\|.*\|$/) {
					push @results, "Incorrect table row '$line'; lines must begin and end with |";
					next BLOCK;
				}

				my @cells = split /\s*\| */, $line;
				@cells = @cells[1..$#cells];

				my @cells_props;

				for ( my $i = 0; $i < scalar( @cells ); $i++ ) {
					my $cell = $cells[$i];
					my $cell_props = {};

					if ( $cell =~ /^\*[^*]*\*$/ ) {
						$cell_props->{'background_color'} = '#444444';

						$cells[$i] =~ s/^\* *| *\*$//g;
					}

					if ( $cell =~ /^\t+/ ) {
						$cell =~ s/^(\t+)//g;
						$cells[$i] = ('   ' x length($1)) . $cell;
					}

					push @cells_props, $cell_props;
				}

				push @row_cell_props, \@cells_props;
				push @rows, \@cells;
			}

			push @results, { type => 'table', content => \@rows, cell_props => \@row_cell_props };
		} else {
			push @results, $block;
		}
	}

	return @results;
}

sub TransformMarkupToHtml {
	my $markup = shift;

	my @blocks = ParseMarkup($markup);
	my @results;

	for my $block (@blocks) {
		if (ref($block) eq 'HASH') {
			if ($block->{type} eq 'table') {
				push @results, "<table>";
				for my $row (@{$block->{content}}) {
					push @results, '<tr><td>' . join('</td><td>', @{$row}) . '</td></tr>';
				}
				push @results, "</table>";
			}
		} else {
			$block =~ s/\n/<br \/>/g;
			push @results, "<p>$block</p>";
		}
	}

	return join "\n", @results;
}

1;
