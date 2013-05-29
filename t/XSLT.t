#!/usr/bin/perl
#
# This Koha test module is a stub!  
# Add more tests here!!!

use strict;
use warnings;

use C4::Context;
use C4::Templates;
use Test::More tests => 13;
use Test::MockModule;
use File::Basename qw/dirname/;
use File::Temp;
use File::Path qw/make_path/;

BEGIN {
        use_ok('C4::XSLT');
}

my $opacdir = File::Temp->newdir();
my $staffdir = File::Temp->newdir();
my @themes = ('prog', 'test');
my @langs = ('en', 'es-ES');

sub make_test_file {
    my ( $filename, $contents ) = @_;

    make_path(dirname($filename));
    open my $fh, '>', $filename or die "Could not create test file: $filename";
    print $fh $contents;
    close $fh;
}

# create temporary files to be tested later
foreach my $theme (@themes) {
    foreach my $lang (@langs) {
        foreach my $dir ($opacdir, $staffdir) {
            make_test_file( "$dir/$theme/$lang/xslt/my_file.xslt", "Theme $theme, language $lang" );
            make_test_file( "$dir/$theme/$lang/xslt/MARC21slim2intranetDetail.xsl", "Theme $theme, language $lang, MARC21slim2intranetDetail" );
            make_test_file( "$dir/$theme/$lang/xslt/test_en.xsl", "Theme $theme, language $lang, test_en" );
            make_test_file( "$dir/$theme/$lang/xslt/UNIMARCslim2OPACDetail.xsl", "Theme $theme, language $lang, UNIMARCslim2OPACDetail" );
            make_test_file( "$dir/$theme/$lang/xslt/nondefault_test.xsl", "Theme $theme, language $lang, nondefault_test" );
            make_test_file( "$dir/$theme/$lang/xslt/MARC21slim2OPACResults.xsl", "Theme $theme, language $lang, MARC21slim2OPACResults" );
        }
    }
}

sub find_and_slurp_default {
    my ($dir, $theme, $lang) = @_;

    my $filename = C4::XSLT::_get_best_default_xslt_filename($dir, $theme, $lang, 'my_file.xslt');
    open my $fh, '<', $filename or return "Could not open: $filename";
    my $str = <$fh>;
    close $fh;
    return $str;
}

sub find_and_slurp {
    my ($marcflavour, $xslsyspref) = @_;

    my $filename = C4::XSLT::XSLTGetFilename( $marcflavour, $xslsyspref );
    open my $fh, '<', $filename or return "Could not open: $filename";
    my $str = <$fh>;
    close $fh;
    return $str;
}

my $module_context = new Test::MockModule('C4::Context');
$module_context->mock(
    'config',
    sub {
        my ( $self, $var ) = @_;
        my %predefs = (
            opachtdocs => $opacdir,
            intrahtdocs => $staffdir,
        );

        return $predefs{$var} || $module_context->original('config')->(@_);
    }
);
$module_context->mock(
    'preference',
    sub {
        my ( $self, $var ) = @_;
        my %predefs = (
            template => 'prog',
            marcflavour => 'MARC21',
            opacthemes => 'test',
            XSLTDetailsDisplay => 'default',
            XSLTResultsDisplay => "$staffdir/prog/en/xslt/test_en.xsl",
            OPACXSLTDetailsDisplay => "$opacdir/test/en/xslt/nondefault_test.xsl",
            OPACXSLTResultsDisplay => '"default"',
        );

        return $predefs{$var} || $module_context->original('preference')->(@_);
    }
);

# These tests verify that we're finding the right XSLT file when present,
# and falling back to the right XSLT file when an exact match is not present.
is(find_and_slurp_default($opacdir, 'test', 'en'   ), 'Theme test, language en',    'Found test/en');
is(find_and_slurp_default($opacdir, 'test', 'es-ES'), 'Theme test, language es-ES', 'Found test/es-ES');
is(find_and_slurp_default($opacdir, 'prog', 'en',  ), 'Theme prog, language en',    'Found test/en');
is(find_and_slurp_default($opacdir, 'prog', 'es-ES'), 'Theme prog, language es-ES', 'Found test/es-ES');
is(find_and_slurp_default($opacdir, 'test', 'fr-FR'), 'Theme test, language en',    'Fell back to test/en for test/fr-FR');
is(find_and_slurp_default($opacdir, 'nope', 'es-ES'), 'Theme prog, language es-ES', 'Fell back to prog/es-ES for nope/es-ES');
is(find_and_slurp_default($opacdir, 'nope', 'fr-FR'), 'Theme prog, language en',    'Fell back to prog/en for nope/fr-FR');
is(find_and_slurp('MARC21', 'XSLTDetailsDisplay'), 'Theme prog, language en, MARC21slim2intranetDetail', 'Used default for staff/details');
is(find_and_slurp('MARC21', 'XSLTResultsDisplay'), 'Theme prog, language en, test_en', 'Used non-default with langcode for staff/results');
is(find_and_slurp('MARC21', 'OPACXSLTDetailsDisplay'), 'Theme test, language en, nondefault_test', 'not-prog: Used non-default for local marcflavour and opac/details');
is(find_and_slurp('UNIMARC', 'OPACXSLTDetailsDisplay'), 'Theme test, language en, UNIMARCslim2OPACDetail', 'not-prog: Used default for non-local marcflavour and opac/details');
is(find_and_slurp('MARC21', 'OPACXSLTResultsDisplay'), 'Theme test, language en, MARC21slim2OPACResults', 'not-prog: Used "default" for opac/results');
