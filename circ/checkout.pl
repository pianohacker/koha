#!/usr/bin/perl

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

use Modern::Perl;

use C4::Auth;
use C4::Branch;
use C4::ClassSource;
use C4::Context;
use C4::Output;
use C4::Members;
use CGI;
use Koha::Database;

my $query = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user (
    {
        template_name   => 'circ/checkout.tmpl',
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
    }
);

my $borrowernumber = $query->param( 'borrowernumber' );
$template->{ VARS }->{ borrowernumber }=$borrowernumber;
$template->{ VARS }->{ circview }=1;
$template->param( %{ GetMemberDetails( $borrowernumber, 0 ) } );

my $schema = Koha::Database->new->schema;
my $authorised_values = {};

$authorised_values->{branches} = [];
my $onlymine=C4::Context->preference('IndependentBranches') &&
        C4::Context->userenv &&
        C4::Context->userenv->{flags} % 2 == 0 &&
        C4::Context->userenv->{branch};
my $branches = GetBranches($onlymine);
foreach my $thisbranch ( sort keys %$branches ) {
    push @{ $authorised_values->{branches} }, { value => $thisbranch, lib => $branches->{$thisbranch}->{'branchname'} };
}

$authorised_values->{itemtypes} = [ $schema->resultset( "Itemtype" )->search( undef, {
    columns => [ { value => 'itemtype' }, { lib => "description" } ],
    order_by => "description",
    result_class => 'DBIx::Class::ResultClass::HashRefInflator'
} ) ];

my $class_sources = GetClassSources();

my $default_source = C4::Context->preference("DefaultClassificationSource");

foreach my $class_source (sort keys %$class_sources) {
    next unless $class_sources->{$class_source}->{'used'} or
                ($class_source eq $default_source);
    push @{ $authorised_values->{cn_source} }, { value => $class_source, lib => $class_sources->{$class_source}->{'description'} };
}

my $branch_limit = C4::Context->userenv ? C4::Context->userenv->{"branch"} : "";
my $results;
if( $branch_limit ) {
    $results = $schema->resultset( "AuthorisedValue" )->search(
    { "authorised_values_branches.branchcode" => { "=", [ $branch_limit, undef ] } },
    { join => "authorised_values_branches", order_by => "lib" } );
} else {
    $results = $schema->resultset( "AuthorisedValue" )->search(
    undef,
    { order_by => "lib" } );
}

foreach my $result ( $results->all ) {
    $authorised_values->{$result->category} ||= [];
    push @{ $authorised_values->{$result->category} }, { value => $result->authorised_value, lib => $result->lib };
}

$template->{VARS}->{authorised_values} = $authorised_values;

$template->{VARS}->{authvalcode_notforloan} = C4::Koha::GetAuthValCode('items.notforloan', '' );

output_html_with_http_headers $query, $cookie, $template->output;
