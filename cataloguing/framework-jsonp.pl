#!/usr/bin/perl

use CGI;
use C4::Context;
use C4::Biblio;

my $input = new CGI;
our $dbh = C4::Context->dbh;

my $frameworkcode = $input->param('frameworkcode') || '';
my $info = $input->param('info') || 'kohalinks';
my $prepend = $input->param('prepend') || '';
my $append = $input->param('append') || '';

my $tagslib = GetMarcStructure(1, $frameworkcode);

print $input->header('text/javascript');

print $prepend . "{";

if ($info eq 'kohalinks') {
	foreach my $tag (sort(keys (%{$tagslib}))) {
		my $taglib = $tagslib->{$tag};
		foreach my $subfield (sort(keys %{$taglib})) {
			my $subfieldlib = $taglib->{$subfield};
			if ($subfieldlib->{kohafield}) {
				print "'" . $subfieldlib->{kohafield} . "':['$tag','$subfield'],";
			}
		}
	}
} elsif ($info eq 'mandatory') {
	my @mandatory_tags;
	my @mandatory_subfields;

	foreach my $tag (sort(keys (%{$tagslib}))) {
		my $taglib = $tagslib->{$tag};
		push @mandatory_tags, $tag if ($taglib->{mandatory});
		foreach my $subfield (sort(keys %{$taglib})) {
			my $subfieldlib = $taglib->{$subfield};
			push @mandatory_subfields, "['$tag','$subfield']" if ($subfieldlib->{mandatory} && $subfieldlib->{tab} != -1 && $subfieldlib->{tab} != 10);
		}
	}

	print "tags:[";
	foreach my $tag (@mandatory_tags) { print "'$tag',"; }
	print "],";

	print "subfields:[";
	foreach my $subfield (@mandatory_subfields) { print "$subfield,"; }
	print "]";
} elsif ($info eq 'itemtypes') {
	my $sth=$dbh->prepare("select itemtype,description from itemtypes order by description");
	$sth->execute;

	while (my ($itemtype,$description) = $sth->fetchrow_array) {
		print "'$itemtype':'$description',";
	}
}

print "}" . $append;
