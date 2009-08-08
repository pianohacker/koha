#!/usr/bin/perl

# Copyright 2000-2009 Biblibre S.A
#                                         John Soros <john.soros@biblibre.com>
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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

#need to open cgi and get the fh before anything else opens a new cgi context (see C4::Auth)
use CGI;
my $input = CGI->new;
my $uploadbarcodes = $input->param('uploadbarcodes');

use C4::Auth;
use C4::Output;
use C4::Koha;
use C4::Branch; # GetBranches
use C4::Dates;

my $input = new CGI;
my $minlocation = $input->param('minlocation') || '';
my $maxlocation = $input->param('maxlocation');
$maxlocation = $minlocation.'Z' unless ( $maxlocation || ! $minlocation );
my @branchcodes = $input->param('branchcode');
my @locations = $input->param('location');
my @itemtypes = $input->param('itemtype');
my $ignoreissued = $input->param('ignoreissued') || 1;
my $op = $input->param('op');
my $res;    #contains the results loop
# warn "uploadbarcodes : ".$uploadbarcodes;
# use Data::Dumper; warn Dumper($input);
my ($template, $borrowernumber, $cookie) = get_template_and_user({
    template_name => "tools/inventory.tmpl",
    query => $input,
    type => "intranet",
    authnotrequired => 0,
    flagsrequired => {tools => 'inventory'},
    debug => 1,
});

my $location_auth = GetAuthValCode( 'items.location', '' );
$template->param( locationsloop => GetAuthorisedValues( $location_auth ) ) if ( $location_auth );

my $ccode_auth = GetAuthValCode( 'items.ccode', '' );
$template->param( ccodeloop => GetAuthorisedValues( $ccode_auth ) ) if ( $ccode_auth );

my $lost_auth = GetAuthValCode( 'items.itemlost', '' );
$template->param( lostloop => GetAuthorisedValues( $lost_auth, 4 ) ) if ( $lost_auth );
 
$template->param(
    branchloop => GetBranchesLoop(),
    itemtypeloop => GetItemTypeList(),
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
);

output_html_with_http_headers $input, $cookie, $template->output;
