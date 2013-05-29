#!/usr/bin/perl
#
# Copyright 2013 Jesse Weaver
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

use Modern::Perl '2010';

use CGI;

use C4::Auth;
use C4::Context;
use C4::Branch;
use C4::Output;
use URI::Escape;

our $dbh = C4::Context->dbh;
our $input = new CGI;

our ( $template, $loggedinuser, $cookie ) = get_template_and_user( {
    template_name => "admin/external-targets.tt",
    query => $input,
    type => "intranet",
    authnotrequired => 0,
    flagsrequired => {parameters => 'parameters_remaining_permissions'},
    debug => 1,
} );

our $op = $input->param( 'op' ) // 'show';
$template->{VARS}->{op} = $op;

given ( $op ) {
    when ( 'show' ) { show_external_targets(); }
    when ( 'add' ) { show_edit_form(); }
    when ( 'edit' ) { show_edit_form(); }
    when ( 'save' ) { save_target(); }
    when ( 'delete' ) { delete_target(); }
}

output_html_with_http_headers $input, $cookie, $template->output;

sub show_external_targets {
    $template->{VARS}->{saved_id} = $input->param( 'saved_id' );
    $template->{VARS}->{deleted_name} = $input->param( 'deleted_name' );
    $template->{VARS}->{targets} = $dbh->selectall_arrayref( q{
        SELECT *
        FROM external_targets
    }, { Slice => {} } );
}

sub show_edit_form {
    $template->{VARS}->{branches} = GetBranchesLoop( undef, 0 );
    $template->{VARS}->{syntaxes} = [ 'MARC21', 'UNIMARC', 'NORMARC' ];
    $template->{VARS}->{encodings} = { 'utf8' => 'UTF-8', 'marc8' => 'MARC-8' };

    my $target_id;
    if ( $target_id = $input->param( 'target_id' ) ) {
        $template->{VARS}->{target} = $dbh->selectrow_hashref( q{ SELECT * FROM external_targets WHERE target_id = ? }, {}, $target_id );
        
        my $available_branches = $dbh->selectall_hashref( q{ SELECT * FROM external_target_restrictions WHERE target_id = ? }, 'branchcode', {}, $target_id );

        foreach my $branch ( @{ $template->{VARS}->{branches} } ) {
            $branch->{selected} = 1 if ( $available_branches->{$branch->{branchcode}} );
        }
    }
}

sub save_target {
    my $target_id;
    if ( $target_id = $input->param( 'target_id' ) ) {
        $dbh->do( q{
            UPDATE external_targets
            SET name = ?, host = ?, port = ?, db = ?, userid = ?, password = ?, syntax = ?, encoding = ?
            WHERE target_id = ?
        }, {}, map { $input->param( $_ ) // '' } qw( name host port db userid password syntax encoding target_id ) );
    } else {
        $dbh->do( q{
            INSERT
            INTO external_targets(name, host, port, db, userid, password, syntax, encoding)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?)
        }, {}, map { $input->param( $_ ) // '' } qw( name host port db userid password syntax encoding ) );
        $target_id = $dbh->last_insert_id( undef, undef, undef, undef );
    }

    $dbh->do( q{
        DELETE
        FROM external_target_restrictions
        WHERE target_id = ?
    }, {}, $target_id );

    foreach my $branchcode ( $input->param( 'branch' ) ) {
        $dbh->do( q{
            INSERT
            INTO external_target_restrictions(branchcode, target_id)
            VALUES(?, ?)
        }, {}, $branchcode, $target_id );
    }

    print $input->redirect( '/cgi-bin/koha/admin/external_targets.pl?saved_id=' . $target_id );
    exit;
}

sub delete_target {
    my ($target_id, $target);

    return unless ( $target_id = $input->param( 'target_id' ) and $target = $dbh->selectrow_hashref( q{ SELECT * FROM external_targets WHERE target_id = ? }, {}, $target_id ) );

    $dbh->do( q{ DELETE FROM external_targets WHERE target_id = ? }, {}, $target_id );

    print $input->redirect( '/cgi-bin/koha/admin/external_targets.pl?deleted_name=' . uri_escape( $target->{'name'} ) );
}
