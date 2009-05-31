#!/usr/bin/perl
# vim: set et :

# script to administer the systempref table
# written 20/02/2002 by paul.poulain@free.fr
# This software is placed under the gnu General Public License, v2 (http://www.gnu.org/licenses/gpl.html)

# Copyright 2009 LibLime
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

=head1 systempreferences.pl

ALGO :
 this script use an $op to know what to do.
 if $op is empty or none of the above values,
    - the default screen is build (with all records, or filtered datas).
    - the   user can clic on add, modify or delete record.
 if $op=add_form
    - if primkey exists, this is a modification,so we read the $primkey record
    - builds the add/modify form
 if $op=add_validate
    - the user has just send datas, so we create/modify the record
 if $op=delete_form
    - we show the record having primkey=$primkey and ask for deletion validation form
 if $op=delete_confirm
    - we delete the record having primkey=$primkey

=cut

use strict;
use warnings;

use CGI;
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Languages qw(getTranslatedLanguages);
use C4::ClassSource;
use C4::Log;
use C4::Output;
use C4::Bookfund qw(GetLocalCurrency);
use File::Spec;
use IO::File;
use YAML::Syck qw();
$YAML::Syck::ImplicitTyping = 1;

# use Smart::Comments;
#

our $PREF_REGEX = '^([a-z_-]+)(?:\.([a-z_-]+))? ([a-zA-Z_0-9-]+)((?:\|[^=]+=[^|]+)*)}}';

sub GetTab {
    my ( $input, $tab ) = @_;

    my $tab_template = C4::Output::gettemplate( 'admin/preferences/' . $tab . '.pref', 'intranet', $input );

    $tab_template->param(
        local_currency => GetLocalCurrency()->{'currency'}, # currency code is used, because we do not know how a given currency is formatted.
    );

    return YAML::Syck::Load( $tab_template->output() );
}

sub _get_chunk {
    my ( $value, %options ) = @_;

    my $name = $options{'pref'};
    my $chunk = { name => $name, value => $value, type => $options{'type'} || 'input', class => $options{'class'} };

    if ( $options{'class'} eq 'password' ) {
        $chunk->{'input_type'} = 'password';
    } elsif ( exists( $options{ 'choices' } ) ) {
        if ( ref( $options{ 'choices' } ) eq '' ) {
            if ( $options{'choices'} eq 'class-sources' ) {
                my $sources = GetClassSources();
                $options{'choices'} = { map { $_ => $sources->{$_}->{'description'} } @$sources };
            }
        }

        $value ||= 0;

        $chunk->{'type'} = 'select';
        $chunk->{'CHOICES'} = [
            sort { $a->{'text'} cmp $b->{'text'} }
            map { { text => $options{'choices'}->{$_}, value => $_, selected => ( $_ eq $value || ( $_ eq '' && ( $value eq '0' || !$value ) ) ) } }
            keys %{ $options{'choices'} }
        ];
    }

    $chunk->{ 'type_' . $chunk->{'type'} } = 1;
    
    return $chunk;
}

sub TransformPrefsToHTML {
    my ( $data, $highlighted_pref ) = @_;

    my @lines;
    my $title = ( keys( %$data ) )[0];
    my $tab = $data->{ $title };
    $tab = { '' => $tab } if ( ref( $tab ) eq 'ARRAY' );

    while ( my ( $group, $contents ) = each %$tab ) {
        if ( $group ) {
            push @lines, { is_group_title => 1, title => $group };
        }

        foreach my $line ( @$contents ) {
            my @chunks;
            my @names;

            foreach my $piece ( @$line ) {
                if ( ref ( $piece ) eq 'HASH' ) {
                    my $name = $piece->{'pref'};

                    if ( $name ) {
                        my $value = C4::Context->preference( $name );
                        $value = $piece->{'default'} if ( !defined( $value ) && $piece->{'default'} );
                        my $chunk = _get_chunk( $value, %$piece );

                        $chunk->{'highlighted'} = 1 if ( $name =~ /$highlighted_pref/ );

                        push @chunks, $chunk;
                        push @names, { name => $name, highlighted => ( $highlighted_pref && ( $name =~ /$highlighted_pref/i ? 1 : 0 ) ) };
                    } else {
                        push @chunks, $piece;
                    } 
                } else {
                    push @chunks, { type_text => 1, contents => $piece };
                }
            }

            push @lines, { CHUNKS => \@chunks, NAMES => \@names };
        }
    }

    return $title, \@lines;
}

sub _get_pref_files {
    my ( $input, $open_files ) = @_;

    my ( $htdocs, $theme, $lang, undef ) = C4::Output::_get_template_file( 'admin/preferences/admin.tmpl', 'intranet', $input );

    my %results;

    foreach my $file ( glob( "$htdocs/$theme/$lang/modules/admin/preferences/*.pref" ) ) {
        my ( $tab ) = ( $file =~ /([a-z_-]+)\.pref$/ );

        $results{$tab} = $open_files ? new IO::File( $file, 'r' ) : '';
    }

    return %results;
}

sub JumpPref {
    my ( $input, $tab, $jumpfield ) = @_;

    return ( $tab ) if ( $jumpfield !~ /^[a-zA-Z_0-9-]+$/ );

    my %tab_files = _get_pref_files( $input );

    while ( my ( $tab, $tabfile ) = each %tab_files ) {
        while ( <$tabfile> ) {
            return ( $tab, $1 ) if ( /name: ($jumpfield)/i );
        }

        close $tabfile;
    }
}

sub SearchPrefs {
    my ( $input, $searchfield ) = @_;
    my @tabs;

    sub _format_text {
        my ( $text, $highlighted ) = @_;

        return { type_text => 1, contents => $text } if ( !$highlighted );

        my @results;

        return @results;
    }

    my %tab_files = _get_pref_files( $input, 0 );

    foreach my $tab_name ( keys %tab_files ) {
        my $data = GetTab( $tab_name );
        my $title = ( keys( %$data ) )[0];
        my $tab = $data->{ $title };
        $tab = { '' => $tab } if ( ref( $tab ) eq 'ARRAY' );

        my $matched_groups;
        
        while ( my ( $group_title, $contents ) = each %$tab ) {
            my $include_entire_group = ( $group_title =~ /$searchfield/i );

            my @new_contents;

            foreach my $line ( @$contents ) {
                my $matched;
                my @new_chunks;

                foreach my $piece ( @$line ) {
                    if ( ref( $piece ) eq 'HASH' && exists( $piece->{'choices'} ) && grep( /$searchfield/i, values( %{ $piece->{'choices'} } ) ) ) {
                        $matched = 1;
                        $piece->{'highlighted'} = 1;
                        push @new_chunks, $piece;
                    } elsif ( $piece =~ /$searchfield/i ) {
                        $matched = 1;
                        while ( $piece =~ s/(.*\W)(\w*$searchfield\w*)(\W.*)/$3/gi ) {
                            push @new_chunks, { type_text => 1, contents => $1 };
                            push @new_chunks, { type_text => 1, highlighted => 1, contents => $2 };
                        }

                        push @new_chunks, { type_text => 1, contents => $piece } if ( $piece );
                    } else {
                        push @new_chunks, $piece;
                    }
                }

                push @new_contents, \@new_chunks if ( $matched || $include_entire_group );
            }

            $matched_groups->{$group_title} = \@new_contents if ( @new_contents );
        }

        if ( $matched_groups ) {
            my ( $title, $LINES ) = TransformPrefsToHTML( { $title => $matched_groups }, $searchfield );

            push @tabs, { tab => $tab, tab_title => $title, LINES => $LINES, };
        }
    }

    return @tabs;
}

my $dbh = C4::Context->dbh;
our $input = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {   template_name   => "admin/preferences.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 1,
        flagsrequired   => { parameters => 1 },
        debug           => 1,
    }
);

my $op = $input->param('op') || '';
my $tab = $input->param('tab');
$tab ||= 'local-use';

my $highlighted;

if ( $op eq 'save' ) {
    foreach my $param ( $input->param() ) {
        my ( $pref ) = ( $param =~ /pref_(.*)/ );

        next if ( !defined( $pref ) );

        #C4::Context->set_preference( $pref, $input->param( $param ) );
    } 

    print $input->redirect( '/cgi-bin/koha/admin/preferences.pl?tab=' . $tab );
    exit;
} elsif ( $op eq 'jump' ) {
    my $jumpfield = $input->param( 'jumpfield' );
    $template->param( jumpfield => $jumpfield );

    ( $tab, $highlighted ) = JumpPref( $input, $tab, $jumpfield );

    if ( !defined( $highlighted ) ) {
        $template->param( jump_not_found => 1 );
    }
}

my @TABS;

if ( $op eq 'search' ) {
    my $searchfield = $input->param( 'searchfield' );
    $template->param( searchfield => $searchfield );

    @TABS = SearchPrefs( $input, $searchfield );

    foreach my $tabh ( @TABS ) {
        $template->param(
            $tabh->{'tab'} => 1
        );
    }

    if ( !@TABS ) {
        $template->param(
            search_not_found => 1,
            last_tab => $tab,
        );
    }
} else {
    my ( $tab_title, $LINES ) = TransformPrefsToHTML( GetTab( $input, $tab ), $highlighted, ( $op eq 'jump' ) );

    push @TABS, { tab_title => $tab_title, LINES => $LINES };
    $template->param(
        $tab => 1,
        tab => $tab,
    );
}

$template->param( TABS => \@TABS );

output_html_with_http_headers $input, $cookie, $template->output;
