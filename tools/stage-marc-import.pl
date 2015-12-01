#!/usr/bin/perl

# Script for handling import of MARC data into Koha db
#   and Z39.50 lookups

# Koha library project  www.koha-community.org

# Licensed under the GPL

# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
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

use strict;
#use warnings; FIXME - Bug 2505

# standard or CPAN modules used
use CGI qw ( -utf8 );
use CGI::Cookie;
use MARC::File::USMARC;

# Koha modules used
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::ImportBatch;
use C4::Matcher;
use Koha::Upload;
use C4::BackgroundJob;
use C4::MarcModificationTemplates;
use Koha::Plugins;

my $input = new CGI;

my $fileID                     = $input->param('uploadedfileid');
my $runinbackground            = $input->param('runinbackground');
my $completedJobID             = $input->param('completedJobID');
my $matcher_id                 = $input->param('matcher');
my $overlay_action             = $input->param('overlay_action');
my $nomatch_action             = $input->param('nomatch_action');
my $parse_items                = $input->param('parse_items');
my $item_action                = $input->param('item_action');
my $comments                   = $input->param('comments');
my $record_type                = $input->param('record_type');
my $encoding                   = $input->param('encoding');
my $to_marc_plugin             = $input->param('to_marc_plugin');
my $marc_modification_template = $input->param('marc_modification_template_id');
my $existing_batch_id          = $input->param('existing_batch_id');
my $control_number_handling    = $input->param('control_number_handling');
my $timestamp_update           = $input->param('timestamp_update');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/stage-marc-import.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'stage_marc_import' },
        debug           => 1,
    }
);

$template->param(
    SCRIPT_NAME => '/cgi-bin/koha/tools/stage-marc-import.pl',
    uploadmarc  => $fileID,
    record_type => $record_type,
);

my %cookies = parse CGI::Cookie($cookie);
my $sessionID = $cookies{'CGISESSID'}->value;
if ($completedJobID) {
    my $job = C4::BackgroundJob->fetch($sessionID, $completedJobID);
    my $results = $job->results();
    $template->param(map { $_ => $results->{$_} } keys %{ $results });
} elsif ($fileID) {
    my $upload = Koha::Upload->new->get({ id => $fileID, filehandle => 1 });
    my $fh = $upload->{fh};
    my $filename = $upload->{name}; # filename only, no path
	my $marcrecord='';
    $/ = "\035";
	while (<$fh>) {
        s/^\s+//;
        s/\s+$//;
		$marcrecord.=$_;
	}
    $fh->close;

    my $job = undef;
    my $dbh;
    if ($runinbackground) {
        my $job_size = () = $marcrecord =~ /\035/g;
        # if we're matching, job size is doubled
        $job_size *= 2 if ($matcher_id ne "");
        $job = C4::BackgroundJob->new($sessionID, $filename, '/cgi-bin/koha/tools/stage-marc-import.pl', $job_size);
        my $jobID = $job->id();

        # fork off
        if (my $pid = fork) {
            # parent
            # return job ID as JSON
            my $reply = CGI->new("");
            print $reply->header(-type => 'text/html');
            print '{"jobID":"' . $jobID . '"}';
            exit 0;
        } elsif (defined $pid) {
            # child
            # close STDOUT to signal to Apache that
            # we're now running in the background
            close STDOUT;
            # close STDERR; # there is no good reason to close STDERR
        } else {
            # fork failed, so exit immediately
            warn "fork failed while attempting to run tools/stage-marc-import.pl as a background job: $!";
            exit 0;
        }

        # if we get here, we're a child that has detached
        # itself from Apache

    }

    # New handle, as we're a child.
    $dbh = C4::Context->dbh({new => 1});
    $dbh->{AutoCommit} = 0;
    # FIXME branch code
    my $stage_results = BatchStageMarcRecords( {
        record_type => $record_type,
        encoding => $encoding,
        marc_records => $marcrecord,
        file_name => $filename,
        to_marc_plugin => $to_marc_plugin,
        marc_modification_template => $marc_modification_template,
        comments => $comments,
        parse_items => $parse_items,
        progress_interval => 50,
        progress_callback => staging_progress_callback( $job, $dbh ),
        existing_batch_id => $existing_batch_id,
        control_number_handling => $control_number_handling,
        timestamp_update => $timestamp_update,
    } );

    my $num_with_matches = 0;
    my $checked_matches = 0;
    my $matcher_failed = 0;
    my $matcher_code = "";
    if ($matcher_id ne "") {
        my $matcher = C4::Matcher->fetch($matcher_id);
        if (defined $matcher) {
            $checked_matches = 1;
            $matcher_code = $matcher->code();
            $num_with_matches =
              BatchFindDuplicates( $stage_results->{batch_id}, $matcher, 10, 50,
                matching_progress_callback( $job, $dbh ) );
            SetImportBatchMatcher( $stage_results->{batch_id}, $matcher_id );
            SetImportBatchOverlayAction( $stage_results->{batch_id}, $overlay_action );
            SetImportBatchNoMatchAction( $stage_results->{batch_id}, $nomatch_action );
            SetImportBatchItemAction( $stage_results->{batch_id}, $item_action );
            $dbh->commit();
        } else {
            $matcher_failed = 1;
        }
    } else {
        $dbh->commit();
    }

    my $results = {
        staged          => $stage_results->{num_valid},
        matched         => $num_with_matches,
        num_items       => $stage_results->{num_items},
        import_errors   => scalar( @{ $stage_results->{invalid_records} } ),
        total           => $stage_results->{num_valid} + scalar( @{ $stage_results->{invalid_records} } ),
        checked_matches => $checked_matches,
        matcher_failed  => $matcher_failed,
        matcher_code    => $matcher_code,
        import_batch_id => $stage_results->{batch_id},
        control_number_handling => $control_number_handling,
        num_matched_control_number => $stage_results->{num_matched_control_number},
    };
    if ($runinbackground) {
        $job->finish($results);
    } else {
	    $template->param( %$results );
    }

} else {
    # initial form
    if ( C4::Context->preference("marcflavour") eq "UNIMARC" ) {
        $template->param( "UNIMARC" => 1 );
    }
    my @matchers = C4::Matcher::GetMatcherList();
    $template->param( available_matchers => \@matchers );

    my @templates = GetModificationTemplates();
    $template->param( MarcModificationTemplatesLoop => \@templates );

    if ( C4::Context->preference('UseKohaPlugins') &&
         C4::Context->config('enable_plugins') ) {

        my @plugins = Koha::Plugins->new()->GetPlugins('to_marc');
        $template->param( plugins => \@plugins );
    }

    if ($existing_batch_id) {
        $template->param(
            existing_batch_id => $existing_batch_id,
            existing_batch => GetImportBatch($existing_batch_id),
        );
    }
}

output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

sub staging_progress_callback {
    my $job = shift;
    my $dbh = shift;
    return sub {
        my $progress = shift;
        $job->progress($progress);
    }
}

sub matching_progress_callback {
    my $job = shift;
    my $dbh = shift;
    my $start_progress = $job->progress();
    return sub {
        my $progress = shift;
        $job->progress($start_progress + $progress);
    }
}
