#!/usr/bin/perl

use strict;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Context;
use MARC::Record;
use MARC::Field;

my $input = new CGI;

my $barcode = $input->param('barcode');
my $title = $input->param('title');
my $author = $input->param('author');

our $frameworkcode = '';

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "tools/fast-add.tmpl",
			     query => $input,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {tools => 'fast_add'},
			     debug => 1,
			     });

if ($title and $barcode) {
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$year +=1900;
	$mon +=1;

	my $record = {
		'biblio.title' => $title,
		'biblioitems.itemtype' => 'FA'
	};

	$record->{'biblio.author'} = $author if ($author);

	$record = TransformKohaToMarc($record);
	$record->leader('     nam a22     7a 4500');
	$record->append_fields(
		MARC::Field->new('003', sprintf('%4d%02d%02d%02d%02d%02d.0', $year, $mon, $mday, $hour, $min, $sec)),
		MARC::Field->new('008', substr($year,2,2) . sprintf("%02d%02d", $mon, $mday) . 't        xxu||||| |||| 00| 0 eng d'),
	);

	my $item_record = TransformKohaToMarc();

	my ($biblionumber, $biblioitemnumber) = AddBiblio($record, $frameworkcode);
	AddItem({
		'barcode' => $barcode,
		'holdingbranch' => C4::Context->userenv->{branch},
		'homebranch' => C4::Context->userenv->{branch},
		'itemnotes' => 'Fast add, please send to cataloger for processing'
	}, $biblionumber);

	$template->param(bib_created => 1);
}

$template->param(barcode => $barcode,
	intranetcolorstylesheet => C4::Context->preference("intranetcolorstylesheet"),
	intranetstylesheet => C4::Context->preference("intranetstylesheet"),
	IntranetNav => C4::Context->preference("IntranetNav")
);

output_html_with_http_headers $input, $cookie, $template->output;
