#!/usr/bin/perl

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
use CGI;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Dates;
use C4::Circulation;
use C4::Koha;
use C4::Branch; # GetBranchName

#use Smart::Comments;
#use Data::Dumper;

use vars qw($debug);

BEGIN {
	$debug = $ENV{DEBUG} || 0;
}

my $dbh = C4::Context->dbh;

my $input = new CGI;

my ($template, $loggedinuser, $cookie) = get_template_and_user({
    template_name   => "sco/sco-receipt.tmpl",
    authnotrequired => 0,
      flagsrequired => { circulate => "circulate_remaining_permissions" },
    query => $input,
    type  => "opac",
    debug => 1,
});
my $borrowernumber = $input->param('borrowernumber');
my $cardnumber = $input->param('cardnumber');

#start the page and read in includes
my $data;
if ( $cardnumber ) {
    $data = GetMember( cardnumber => $cardnumber );
    $borrowernumber = $data->{borrowernumber} if ( $data );
} else {
    $data = GetMember( borrowernumber => $borrowernumber );
}

my $branch=C4::Context->userenv->{'branch'};

if ( not defined $data ) {
    $template->param (unknowuser => 1);
	output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

my %bor;
$bor{'borrowernumber'} = $borrowernumber;

my $branchdetail = GetBranchDetail( $data->{'branchcode'});
$template->param($branchdetail);

# current issues
#
my $issue = GetPendingIssues($borrowernumber);
my $count = scalar(@$issue);
my $roaddetails = &GetRoadTypeDetails( $data->{'streettype'} );
my $today       = POSIX::strftime("%Y-%m-%d", localtime);	# iso format
my @issuedata;
my $overdues_exist = 0;
my $totalprice = 0;
for ( my $i = 0 ; $i < $count ; $i++ ) {
    my $datedue = $issue->[$i]{'date_due'};
    $issue->[$i]{'date_due'}  = C4::Dates->new($issue->[$i]{'date_due'}, 'iso')->output('syspref');
    $issue->[$i]{'issuedate'} = C4::Dates->new($issue->[$i]{'issuedate'},'iso')->output('syspref');
    my %row = %{ $issue->[$i] };
    $totalprice += $issue->[$i]{'replacementprice'};
    $row{'replacementprice'} = $issue->[$i]{'replacementprice'};
    if ( $datedue lt $today ) {
        $overdues_exist = 1;
        $row{'red'} = 1;
	}

    #find the charge for an item
    my ( $charge, $itemtype ) =
      GetIssuingCharges( $issue->[$i]{'itemnumber'}, $borrowernumber );

    my $itemtypeinfo = getitemtypeinfo($itemtype);
    $row{'itemtype_description'} = $itemtypeinfo->{description};
    $row{'itemtype_image'}       = $itemtypeinfo->{imageurl};

    $row{'charge'} = sprintf( "%.2f", $charge );

    push( @issuedata, \%row );
}


# check to see if patron's image exists in the database
# basically this gives us a template var to condition the display of
# patronimage related interface on

$template->param($data);


$template->param(
    detailview => 1,
    AllowRenewalLimitOverride => C4::Context->preference("AllowRenewalLimitOverride"),
    DHTMLcalendar_dateformat => C4::Dates->DHTMLcalendar(),
    borrowernumber  => $borrowernumber,
    branch          => $branch,
    issueloop       => \@issuedata,
    overdues_exist  => $overdues_exist,
    dateformat      => C4::Context->preference("dateformat"),
    "dateformat_" . (C4::Context->preference("dateformat") || '') => 1,
);

output_html_with_http_headers $input, $cookie, $template->output;

