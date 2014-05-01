#!/usr/bin/perl
#
# Copyright 2013 ByWater
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
#

use Modern::Perl '2009';

use CGI;
use MARC::Record;

use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Output;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'cataloguing/editor.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => 'edit_catalogue' },
    }
);

# Needed information for cataloging plugins
$template->{VARS}->{DefaultLanguageField008} = pack( 'A3', C4::Context->preference('DefaultLanguageField008') || 'eng' );

# Z39.50 servers
my $dbh = C4::Context->dbh;
$template->{VARS}->{z3950_targets} = $dbh->selectall_arrayref( q{
    SELECT * FROM z3950servers
    ORDER BY name
}, { Slice => {} } );

output_html_with_http_headers $input, $cookie, $template->output;
