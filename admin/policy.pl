#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2017 Jesse Weaver
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
use C4::Context;
use C4::Output;

use Koha::Patrons;

use CGI qw( -utf8 );

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   template_name   => "admin/policy.tt",
        authnotrequired => 0,
        flagsrequired   => { parameters => 'manage_circ_rules' },
        query           => $query,
        type            => "intranet",
        debug           => 1,
    }
);

my $uid = Koha::Patrons->find( $borrowernumber )->userid;
my $restricted_to_own_library = $uid && haspermission( $uid, { parameters => 'manage_circ_rules_restricted' }, { no_inherit => 1 } );
$template->param( restricted_to_library => $restricted_to_own_library ? C4::Context::mybranch() : "" );

output_html_with_http_headers $query, $cookie, $template->output;
