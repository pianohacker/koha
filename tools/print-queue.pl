#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use C4::Auth;
use C4::Output;
use C4::Context;
use C4::Letters;
use C4::Letters::Print;

use PDF::API2;
use PDF::Table;

my %types = (
	text => 1,
	table => 1,
);

my $query = new CGI;
our $dbh = C4::Context->dbh;
my ($template, $loggedinuser, $cookie) = get_template_and_user( {
	template_name => "tools/print-queue.tmpl",
	query => $query,
	type => "intranet",
	authnotrequired => 0,
	flagsrequired => {tools => '*'},
	debug => 1,
} );

my $op = $query->param( 'op' ) || '';

if ( $op eq 'print' ) {
    my $statement = << 'ENDSQL';
SELECT message_id, borrowers.*, subject, content, message_transport_type, status, time_queued, from_address, to_address, content_type
FROM message_queue
	LEFT JOIN borrowers USING (borrowernumber)
WHERE status = ?
ENDSQL
	my @bind_params = ( $query->param( 'status' ) || 'pending' );

	if ( $query->param( 'branch' ) ) {
		$statement .= 'AND branchcode = ?';
		push @bind_params, $query->param( 'branch' );
	}

	my $sth = $dbh->prepare( $statement );
	$sth->execute( @bind_params );
	my $messages = $sth->fetchall_arrayref({});

	foreach my $message ( @{ $messages } ) {
		$message->{date_queued} = C4::Dates->new( $message->{time_queued}, 'iso' )->output();
	}
	our $unsent_messages = C4::Letters::_get_unsent_messages( { message_transport_type => 'print' } );
	our %settings = %{ GetBranchPrintSettings( C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef ) };

	my $pdf = PDF::API2->new();
	$pdf->mediabox( $settings{'page_width'}, $settings{'page_height'} );
	my $font = $pdf->corefont($settings{'font_family'}, -encoding => 'UTF-8');
	my $letterhead = $settings{'letterhead_file'} ? PDF::API2->open($settings{'letterhead_file'}) : undef;
	my $table = PDF::Table->new();

	foreach my $message (@$unsent_messages) {
		my @blocks = ParseMarkup($message->{'content'});
		my $page = $letterhead ? $pdf->importpage($letterhead, 1) : $pdf->page;

		my $ypos = $settings{'page_height'} - ($settings{'letterhead_file'} ? $settings{'letterhead_bottom'} : $settings{'page_margin'});

		my $texth = $page->text;
		$texth->font($font, $settings{'font_size'});
		my $leftover;
		our $line_height = $settings{'font_size'} * $settings{'line_height'};

		while (my $block = shift @blocks) {
			if ($ypos < $settings{'page_margin'}) {
				$page = $pdf->page;
				$ypos = $settings{'page_height'} - $settings{'page_margin'};
				$texth = $page->text;
				$texth->font($font, $settings{'font_size'});
			}

			if (ref($block) eq 'ARRAY') {
				$block = { type => 'table', content => $block };
			} elsif (ref($block) eq 'CODE') {
				next;
			} elsif (ref($block) ne 'HASH') {
				$block = { type => 'text', content => $block };
			}

			die "Unknown block type $block->{'type'}" if (!defined($types{$block->{'type'}}));

			if ($block->{'type'} eq 'text') {
				$ypos -= $line_height;

				(undef, $ypos, $leftover) = $table->text_block(
					$texth,
					$block->{'content'},
					-x => $settings{'page_margin'},
					-y => $ypos,
					-h => $ypos - $settings{'page_margin'}, # Why? Because the coordinates start at the bottom
					-w => $settings{'page_width'} - $settings{'page_margin'} * 2, # Why do they start at the bottom?
					-lead => $line_height, # Don't ask me, I just work here
					-align => 'left',
				);

				if ($leftover) {
					unshift @blocks, $leftover;
				}
			} elsif ($block->{'type'} eq 'table') {
				my $new_page;

				($new_page, undef, $ypos) = $table->table(
					$pdf,
					$page,
					$block->{'content'},
					x => $settings{'page_margin'},
					w => $settings{'page_width'} - $settings{'page_margin'} * 2,
					start_y => $ypos,
					start_h => $ypos - $settings{'page_margin'},
					next_y => $settings{'page_height'} - $settings{'page_margin'},
					next_h => $settings{'page_height'} - $settings{'page_margin'} * 2,
					font => $font,
					font_size => $settings{'font_size'},
					padding => $settings{'font_size'} / 2,
					cell_props => $block->{'cell_props'},
				);

				if ($new_page != $page) {
					$page = $new_page;
					$texth = $page->text;
					$texth->font($font, $settings{'font_size'});
				}
			}

			$ypos -= $settings{'block_spacing'};
		}
	}

	print $query->header( -type => 'application/pdf' );

	print $pdf->stringify;

	$pdf->end;
} else {
	if ( $op eq 'mark' and $query->param( 'messages' ) ) {
		my @marked_messages = $query->param( 'messages' );

		my %button_map = ( 'next_status_sent' => 'sent', 'next_status_failed' => 'failed', 'next_status_deleted' => 'deleted' );
		my $param;
		my $next_status;

		while ( ( $param, $next_status ) = each ( %button_map ) ) {
			last if ( $query->param( $param ) );
		}

		my $sth = $dbh->prepare('
			UPDATE message_queue
			SET status = ?
			WHERE message_id IN (' . join( ', ', map( { '?' } @marked_messages ) ) . ')'
		);

		$sth->execute( $next_status, @marked_messages );
	}

    my $statement = << 'ENDSQL';
SELECT message_id, borrowers.*, subject, content, status, time_queued, from_address, to_address, content_type
FROM message_queue
	LEFT JOIN borrowers USING (borrowernumber)
WHERE status = ? AND message_transport_type = 'print'
ENDSQL
	my @bind_params = ( $query->param( 'status' ) || 'pending' );

	if ( $query->param( 'branch' ) ) {
		$statement .= 'AND branchcode = ?';
		push @bind_params, $query->param( 'branch' );
	}

	my $sth = $dbh->prepare( $statement );
	$sth->execute( @bind_params );
	my $messages = $sth->fetchall_arrayref({});

	foreach my $message ( @{ $messages } ) {
		$message->{date_queued} = C4::Dates->new( $message->{time_queued}, 'iso' )->output();
	}

	$template->param(
		messages => $messages,
		status => $query->param( 'status' ) || 'pending',
		status_filter => CGI::scrolling_list(
			-name => 'status',
			-values => [ 'pending', 'sent', 'failed' ],
			-labels => {
				pending => 'Unsent',
				sent => 'Sent',
				failed => 'Failed'
			},
			-default => $query->param( 'status' ) || 'pending',
			-size => 1
		)
	);

	output_html_with_http_headers $query, $cookie, $template->output;
}
