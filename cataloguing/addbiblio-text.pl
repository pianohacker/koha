#!/usr/bin/perl

# Copyright 2008 LibLime
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

use strict;
use CGI;
use C4::Output qw(:html :ajax);
use C4::Output::JSONStream;
use JSON;
use C4::Auth;
use C4::Biblio;
use C4::Search;
use C4::AuthoritiesMarc;
use C4::Context;
use MARC::Record;
use MARC::Field;
use C4::Log;
use C4::Koha;    # XXX subfield_is_koha_internal_p
use C4::Branch;    # XXX subfield_is_koha_internal_p
use C4::ClassSource;
use C4::ImportBatch;
use C4::Charset;

use Date::Calc qw(Today);
use MARC::File::USMARC;
use MARC::File::XML;

if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
    MARC::File::XML->default_record_format('UNIMARC');
}

our($tagslib,$authorised_values_sth,$is_a_modif,$usedTagsLib,$mandatory_z3950);

our ($sec, $min, $hour, $mday, $mon, $year, undef, undef, undef) = localtime(time);
$year +=1900;
$mon +=1;

our %creators = (
    '000@' => sub { '     nam a22     7a 4500' },
    '005@' => sub { sprintf('%4d%02d%02d%02d%02d%02d.0', $year, $mon, $mday, $hour, $min, $sec) },
    '008@' => sub { substr($year,2,2) . sprintf("%02d%02d", $mon, $mday) . 't        xxu||||| |||| 00| 0 eng d' },
);

=item MARCfindbreeding

    $record = MARCfindbreeding($breedingid);

Look up the import record repository for the record with
record with id $breedingid.  If found, returns the decoded
MARC::Record; otherwise, -1 is returned (FIXME).
Returns as second parameter the character encoding.

=cut

sub MARCfindbreeding {
    my ( $id ) = @_;
    my ($marc, $encoding) = GetImportRecordMarc($id);
    # remove the - in isbn, koha store isbn without any -
    if ($marc) {
        my $record = MARC::Record->new_from_usmarc($marc);
        my ($isbnfield,$isbnsubfield) = GetMarcFromKohaField('biblioitems.isbn','');
        if ( $record->field($isbnfield) ) {
            foreach my $field ( $record->field($isbnfield) ) {
                foreach my $subfield ( $field->subfield($isbnsubfield) ) {
                    my $newisbn = $field->subfield($isbnsubfield);
                    $newisbn =~ s/-//g;
                    $field->update( $isbnsubfield => $newisbn );
                }
            }
        }
        # fix the unimarc 100 coded field (with unicode information)
        if (C4::Context->preference('marcflavour') eq 'UNIMARC' && $record->subfield(100,'a')) {
            my $f100a=$record->subfield(100,'a');
            my $f100 = $record->field(100);
            my $f100temp = $f100->as_string;
            $record->delete_field($f100);
            if ( length($f100temp) > 28 ) {
                substr( $f100temp, 26, 2, "50" );
                $f100->update( 'a' => $f100temp );
                my $f100 = MARC::Field->new( '100', '', '', 'a' => $f100temp );
                $record->insert_fields_ordered($f100);
            }
        }

        if ( !defined(ref($record)) ) {
            return -1;
        }
        else {
            # normalize author : probably UNIMARC specific...
            if (    C4::Context->preference("z3950NormalizeAuthor")
                and C4::Context->preference("z3950AuthorAuthFields") )
            {
                my ( $tag, $subfield ) = GetMarcFromKohaField("biblio.author");

 #                 my $summary = C4::Context->preference("z3950authortemplate");
                my $auth_fields =
                  C4::Context->preference("z3950AuthorAuthFields");
                my @auth_fields = split /,/, $auth_fields;
                my $field;

                if ( $record->field($tag) ) {
                    foreach my $tmpfield ( $record->field($tag)->subfields ) {

       #                        foreach my $subfieldcode ($tmpfield->subfields){
                        my $subfieldcode  = shift @$tmpfield;
                        my $subfieldvalue = shift @$tmpfield;
                        if ($field) {
                            $field->add_subfields(
                                "$subfieldcode" => $subfieldvalue )
                              if ( $subfieldcode ne $subfield );
                        }
                        else {
                            $field =
                              MARC::Field->new( $tag, "", "",
                                $subfieldcode => $subfieldvalue )
                              if ( $subfieldcode ne $subfield );
                        }
                    }
                }
                $record->delete_field( $record->field($tag) );
                foreach my $fieldtag (@auth_fields) {
                    next unless ( $record->field($fieldtag) );
                    my $lastname  = $record->field($fieldtag)->subfield('a');
                    my $firstname = $record->field($fieldtag)->subfield('b');
                    my $title     = $record->field($fieldtag)->subfield('c');
                    my $number    = $record->field($fieldtag)->subfield('d');
                    if ($title) {

#                         $field->add_subfields("$subfield"=>"[ ".ucfirst($title).ucfirst($firstname)." ".$number." ]");
                        $field->add_subfields(
                                "$subfield" => ucfirst($title) . " "
                              . ucfirst($firstname) . " "
                              . $number );
                    }
                    else {

#                       $field->add_subfields("$subfield"=>"[ ".ucfirst($firstname).", ".ucfirst($lastname)." ]");
                        $field->add_subfields(
                            "$subfield" => ucfirst($firstname) . ", "
                              . ucfirst($lastname) );
                    }
                }
                $record->insert_fields_ordered($field);
            }
            return $record, $encoding;
        }
    }
    return -1;
}

# Borrowed from MARC::Record::JSON, due to its lack of availability on CPAN

sub MARC::Record::as_json_record_structure {
    my $self = shift;
    my $data = { leader => $self->leader };
    my @fields;
    foreach my $field ($self->fields) {
        my $json_field = { tag => $field->tag };

        if ($field->is_control_field) {
            $json_field->{contents} = $field->data;
        } else {
            $json_field->{indicator1} = $field->indicator(1);
            $json_field->{indicator2} = $field->indicator(2);

            $json_field->{subfields} = [ $field->subfields ];
        }

        push @fields, $json_field;
    }

    $data->{fields} = \@fields;

    return $data;
}

=item GetMandatoryFieldZ3950

    This function return an hashref which containts all mandatory field
    to search with z3950 server.

=cut

sub GetMandatoryFieldZ3950($){
    my $frameworkcode = shift;
    my @isbn   = GetMarcFromKohaField('biblioitems.isbn',$frameworkcode);
    my @title  = GetMarcFromKohaField('biblio.title',$frameworkcode);
    my @author = GetMarcFromKohaField('biblio.author',$frameworkcode);
    my @issn   = GetMarcFromKohaField('biblioitems.issn',$frameworkcode);
    my @lccn   = GetMarcFromKohaField('biblioitems.lccn',$frameworkcode);

    return {
        $isbn[0].$isbn[1]     => 'isbn',
        $title[0].$title[1]   => 'title',
        $author[0].$author[1] => 'author',
        $issn[0].$issn[1]     => 'issn',
        $lccn[0].$lccn[1]     => 'lccn',
    };
}

sub build_tabs ($$$$$) {
    my($template, $record, $dbh,$encoding, $input) = @_;
    # fill arrays
    my @loop_data =();
    my $tag;
    my $i=0;
    my $authorised_values_sth = $dbh->prepare("select authorised_value,lib
        from authorised_values
        where category=? order by lib");

    # in this array, we will push all the 10 tabs
    # to avoid having 10 tabs in the template : they will all be in the same BIG_LOOP
    my @BIG_LOOP;
    my @HIDDEN_LOOP;

# loop through each tab 0 through 9
    foreach my $tag (sort(keys (%{$tagslib}))) {
        my $taglib = $tagslib->{$tag};
        my $indicator;
# if MARC::Record is not empty => use it as master loop, then add missing subfields that should be in the tab.
# if MARC::Record is empty => use tab as master loop.
        if ($record ne -1 && ($record->field($tag) || $tag eq '000')) {
            my @fields;
            if ($tag ne '000') {
                @fields = $record->field($tag);
            } else {
                push @fields,$record->leader();
            }
            foreach my $field (@fields)  {
                my $tag_writeout = "$tag ";
                $tag_writeout .= ($field->indicator(1) eq ' ' ? '_' : $field->indicator(1)) . ($field->indicator(1) eq ' ' ? '_' : $field->indicator(1)) . ' ' if ($tag>=10);
                my $tag_index = int(rand(1000000));
                my @subfields_data;
                if ($tag<10) {
                    my ($value,$subfield);
                    if ($tag ne '000') {
                        $value=$field->data();
                        $subfield="@";
                    } else {
                        $value = $field;
                        $subfield='@';
                    }
                    my $subfieldlib = $taglib->{$subfield};
                    next if ($subfieldlib->{kohafield} eq 'biblio.biblionumber');

                    push(@subfields_data, "$value");
                    $i++;
                } else {
                    my @subfields=$field->subfields();
                    foreach my $subfieldcount (0..$#subfields) {
                        my $subfield=$subfields[$subfieldcount][0];
                        my $value=$subfields[$subfieldcount][1];
                        my $subfieldlib = $taglib->{$subfield};
                        next if (length $subfield !=1);
                        next if ($subfieldlib->{tab} > 9 or $subfieldlib->{tab} == -1);
                        push(@subfields_data, "\$$subfield $value");
                        $i++;
                    }
                }
# now, loop again to add parameter subfield that are not in the MARC::Record
                foreach my $subfield (sort( keys %{$tagslib->{$tag}})) {
                    my $subfieldlib = $taglib->{$subfield};
                    next if (length $subfield !=1);
                    next if ($tag<10);
                    next if (!$subfieldlib->{mandatory});
                    next if ($subfieldlib->{tab} > 9 or $subfieldlib->{tab} == -1);
                    next if (defined($field->subfield($subfield)));
                    push(@subfields_data, "\$$subfield");
                    $i++;
                }
                if (@subfields_data) {
                    $tag_writeout .= join(' ', @subfields_data);
                    push (@BIG_LOOP, $tag_writeout);
                }
# If there is more than 1 field, add an empty hidden field as separator.
            }
# if breeding is empty
        } else {
            my $tag_writeout = "$tag ";
            $tag_writeout .= '__ ' if ($tag>=10);
            my @subfields_data;
            foreach my $subfield (sort(keys %{$tagslib->{$tag}})) {
                my $subfieldlib = $taglib->{$subfield};
                next if (length $subfield !=1);
                next if (!$subfieldlib->{mandatory});
                next if ($subfieldlib->{tab} > 9);

                if (ref($creators{$tag . $subfield}) eq 'CODE') {
                    if (($subfieldlib->{hidden} <= -4) or ($subfieldlib->{hidden}>=5) or ($taglib->{tab} == -1)) {
                        my %row = (
                            tag => $tag,
                            index => int(rand(1000000)),
                            index_subfield => int(rand(1000000)),
                            random => int(rand(1000000)),
                            subfield => ($subfield eq '@' ? '00' : $subfield),
                            subfield_value => $creators{$tag . $subfield}(),
                        );
                        push @HIDDEN_LOOP, \%row;
                        next;
                    } else {
                        push @subfields_data, $creators{$tag . $subfield}();
                        next;
                    }
                }

                if ($tag >= 10) {
                    push @subfields_data, "\$$subfield";
                } else {
                    push @subfields_data, "";
                }
                $i++;
            }
            next if (!@subfields_data);
            push (@BIG_LOOP, $tag_writeout . join(' ', @subfields_data));
        }
    }
#         $template->param($tabloop."XX" =>\@loop_data);
    $template->param(
        BIG_LOOP => join("\n", @BIG_LOOP),
        HIDDEN_LOOP => \@HIDDEN_LOOP,
        record_length => $#BIG_LOOP,
    );
}

#
# sub that tries to find authorities linked to the biblio
# the sub :
#   - search in the authority DB for the same authid (in $9 of the biblio)
#   - search in the authority DB for the same 001 (in $3 of the biblio in UNIMARC)
#   - search in the authority DB for the same values (exactly) (in all subfields of the biblio)
# if the authority is found, the biblio is modified accordingly to be connected to the authority.
# if the authority is not found, it's added, and the biblio is then modified to be connected to the authority.
#

sub BiblioAddAuthorities{
  my ( $record, $frameworkcode ) = @_;
  my $dbh=C4::Context->dbh;
  my $query=$dbh->prepare(qq|
SELECT authtypecode,tagfield
FROM marc_subfield_structure
WHERE frameworkcode=?
AND (authtypecode IS NOT NULL AND authtypecode<>\"\")|);
# SELECT authtypecode,tagfield
# FROM marc_subfield_structure
# WHERE frameworkcode=?
# AND (authtypecode IS NOT NULL OR authtypecode<>\"\")|);
  $query->execute($frameworkcode);
  my ($countcreated,$countlinked);
  while (my $data=$query->fetchrow_hashref){
    foreach my $field ($record->field($data->{tagfield})){
      next if ($field->subfield('3')||$field->subfield('9'));
      # No authorities id in the tag.
      # Search if there is any authorities to link to.
      my $query='at='.$data->{authtypecode}.' ';
      map {$query.= ' and he,ext="'.$_->[1].'"' if ($_->[0]=~/[A-z]/)}  $field->subfields();
      my ($error, $results, $total_hits)=SimpleSearch( $query, undef, undef, [ "authorityserver" ] );
    # there is only 1 result
      if ( $error ) {
        warn "BIBLIOADDSAUTHORITIES: $error";
        return (0,0) ;
      }
      if ($results && scalar(@$results)==1) {
        my $marcrecord = MARC::File::USMARC::decode($results->[0]);
        $field->add_subfields('9'=>$marcrecord->field('001')->data);
        $countlinked++;
      } elsif (scalar(@$results)>1) {
   #More than One result
   #This can comes out of a lack of a subfield.
#         my $marcrecord = MARC::File::USMARC::decode($results->[0]);
#         $record->field($data->{tagfield})->add_subfields('9'=>$marcrecord->field('001')->data);
  $countlinked++;
      } else {
  #There are no results, build authority record, add it to Authorities, get authid and add it to 9
  ###NOTICE : This is only valid if a subfield is linked to one and only one authtypecode
  ###NOTICE : This can be a problem. We should also look into other types and rejected forms.
         my $authtypedata=GetAuthType($data->{authtypecode});
         next unless $authtypedata;
         my $marcrecordauth=MARC::Record->new();
         my $authfield=MARC::Field->new($authtypedata->{auth_tag_to_report},'','',"a"=>"".$field->subfield('a'));
         map { $authfield->add_subfields($_->[0]=>$_->[1]) if ($_->[0]=~/[A-z]/ && $_->[0] ne "a" )}  $field->subfields();
         $marcrecordauth->insert_fields_ordered($authfield);

         # bug 2317: ensure new authority knows it's using UTF-8; currently
         # only need to do this for MARC21, as MARC::Record->as_xml_record() handles
         # automatically for UNIMARC (by not transcoding)
         # FIXME: AddAuthority() instead should simply explicitly require that the MARC::Record
         # use UTF-8, but as of 2008-08-05, did not want to introduce that kind
         # of change to a core API just before the 3.0 release.
         if (C4::Context->preference('marcflavour') eq 'MARC21') {
            SetMarcUnicodeFlag($marcrecordauth, 'MARC21');
         }

#          warn "AUTH RECORD ADDED : ".$marcrecordauth->as_formatted;

         my $authid=AddAuthority($marcrecordauth,'',$data->{authtypecode});
         $countcreated++;
         $field->add_subfields('9'=>$authid);
      }
    }
  }
  return ($countlinked,$countcreated);
}

# ========================
#          MAIN
#=========================
my $input = new CGI;
my $error = $input->param('error');
my $biblionumber  = $input->param('biblionumber'); # if biblionumber exists, it's a modif, not a new biblio.
my $breedingid    = $input->param('breedingid');
my $z3950         = $input->param('z3950');
my $op            = $input->param('op');
my $mode          = $input->param('mode');
my $record_text   = $input->param('record');
my $frameworkcode = $input->param('frameworkcode');
my $dbh           = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "cataloguing/addbiblio-text.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => 1 },
    }
);

if (is_ajax() && $op eq 'try_parse') {
    my @params = $input->param();
    my $record = TransformHtmlToMarc( \@params , $input );
    my $response = new C4::Output::JSONStream;

    eval {
           $record = TransformTextToMarc( $record_text, existing_record => $record )
    };
    if ( $@ ) {
        chomp $@;
        $response->param( type => 'input', error => 'parse_failed', message => $@ );

        output_with_http_headers $input, $cookie, $response->output, 'json';
        exit;
    }

    $response->param( record => $record->as_json_record_structure );

    output_with_http_headers $input, $cookie, $response->output, 'json';
    exit;
}

$frameworkcode = &GetFrameworkCode($biblionumber)
  if ( $biblionumber and not($frameworkcode) );

$frameworkcode = '' if ( $frameworkcode eq 'Default' );

# Getting the list of all frameworks
# get framework list
my $frameworks = getframeworks;
my @frameworkcodeloop;
foreach my $thisframeworkcode ( keys %$frameworks ) {
    my %row = (
        value         => $thisframeworkcode,
        frameworktext => $frameworks->{$thisframeworkcode}->{'frameworktext'},
    );
    if ($frameworkcode eq $thisframeworkcode){
        $row{'selected'}="selected=\"selected\"";
        }
    push @frameworkcodeloop, \%row;
}
$template->param( frameworkcodeloop => \@frameworkcodeloop,
    breedingid => $breedingid );

# ++ Global
$tagslib         = &GetMarcStructure( 1, $frameworkcode );
$usedTagsLib     = &GetUsedMarcStructure( $frameworkcode );
$mandatory_z3950 = GetMandatoryFieldZ3950($frameworkcode);
# -- Global

my $record   = -1;
my $encoding = "";
my (
    $biblionumbertagfield,
    $biblionumbertagsubfield,
    $biblioitemnumtagfield,
    $biblioitemnumtagsubfield,
    $bibitem,
    $biblioitemnumber
);

if (($biblionumber) && !($breedingid)){
    $record = GetMarcBiblio($biblionumber);
}
if ($breedingid) {
    ( $record, $encoding ) = MARCfindbreeding( $breedingid ) ;
}

$is_a_modif = 0;

if ($biblionumber) {
    $is_a_modif = 1;
    $template->param( title => $record->title(), );

    # if it's a modif, retrieve bibli and biblioitem numbers for the future modification of old-DB.
    ( $biblionumbertagfield, $biblionumbertagsubfield ) =
    &GetMarcFromKohaField( "biblio.biblionumber", $frameworkcode );
    ( $biblioitemnumtagfield, $biblioitemnumtagsubfield ) =
    &GetMarcFromKohaField( "biblioitems.biblioitemnumber", $frameworkcode );

    # search biblioitems value
    my $sth =  $dbh->prepare("select biblioitemnumber from biblioitems where biblionumber=?");
    $sth->execute($biblionumber);
    ($biblioitemnumber) = $sth->fetchrow;
}

#-------------------------------------------------------------------------------------
if ( $op eq "addbiblio" ) {
#-------------------------------------------------------------------------------------
    # getting html input
    my @params = $input->param();
    $record = TransformHtmlToMarc( \@params , $input );
    eval {
           $record = TransformTextToMarc( $record_text, existing_record => $record )
    };
    # check for a duplicate
    my ($duplicatebiblionumber,$duplicatetitle) = FindDuplicate($record) if (!$is_a_modif);
    my $confirm_not_duplicate = $input->param('confirm_not_duplicate');
    # it is not a duplicate (determined either by Koha itself or by user checking it's not a duplicate)
    if ( !$duplicatebiblionumber or $confirm_not_duplicate ) {
        my $oldbibnum;
        my $oldbibitemnum;
        if (C4::Context->preference("BiblioAddsAuthorities")){
          my ($countlinked,$countcreated)=BiblioAddAuthorities($record,$frameworkcode);
        }
        if ( $is_a_modif ) {
            ModBiblioframework( $biblionumber, $frameworkcode );
            ModBiblio( $record, $biblionumber, $frameworkcode );
        }
        else {
            ( $biblionumber, $oldbibitemnum ) = AddBiblio( $record, $frameworkcode );
        }

        if ($mode ne "popup"){
            print $input->redirect(
                "/cgi-bin/koha/cataloguing/additem.pl?biblionumber=$biblionumber&frameworkcode=$frameworkcode"
            );
            exit;
        } else {
          $template->param(
            biblionumber => $biblionumber,
            done         =>1,
            popup        =>1
          );
          $template->param( title => $record->subfield('200',"a") ) if ($record ne "-1" && C4::Context->preference('marcflavour') =~/unimarc/i);
          $template->param( title => $record->title() ) if ($record ne "-1" && C4::Context->preference('marcflavour') eq "usmarc");
          $template->param(
            popup => $mode,
            itemtype => $frameworkcode,
          );
          output_html_with_http_headers $input, $cookie, $template->output;
          exit;
        }
    } else {
    # it may be a duplicate, warn the user and do nothing
        build_tabs ($template, $record, $dbh,$encoding,$input);
        $template->param(
            biblionumber             => $biblionumber,
            biblioitemnumber         => $biblioitemnumber,
            duplicatebiblionumber    => $duplicatebiblionumber,
            duplicatebibid           => $duplicatebiblionumber,
            duplicatetitle           => $duplicatetitle,
        );
    }
}
elsif ( $op eq "delete" ) {

    my $error = &DelBiblio($biblionumber);
    if ($error) {
        warn "ERROR when DELETING BIBLIO $biblionumber : $error";
        print "Content-Type: text/html\n\n<html><body><h1>ERROR when DELETING BIBLIO $biblionumber : $error</h1></body></html>";
    exit;
    }

    print $input->redirect('/cgi-bin/koha/catalogue/search.pl');
    exit;

} else {
   #----------------------------------------------------------------------------
   # If we're in a duplication case, we have to set to "" the biblionumber
   # as we'll save the biblio as a new one.
    if ( $op eq "duplicate" ) {
        $biblionumber = "";
    }

#FIXME: it's kind of silly to go from MARC::Record to MARC::File::XML and then back again just to fix the encoding
    eval {
        my $uxml = $record->as_xml;
        MARC::Record::default_record_format("UNIMARC")
          if ( C4::Context->preference("marcflavour") eq "UNIMARC" );
        my $urecord = MARC::Record::new_from_xml( $uxml, 'UTF-8' );
        $record = $urecord;
    };
    build_tabs( $template, $record, $dbh, $encoding,$input );
    $template->param(
        biblionumber             => $biblionumber,
        biblionumbertagfield        => $biblionumbertagfield,
        biblionumbertagsubfield     => $biblionumbertagsubfield,
        biblioitemnumtagfield    => $biblioitemnumtagfield,
        biblioitemnumtagsubfield => $biblioitemnumtagsubfield,
        biblioitemnumber         => $biblioitemnumber,
    );
}

$template->param( title => $record->title() ) if ( $record ne "-1" );
$template->param(
    popup => $mode,
    frameworkcode => $frameworkcode,
    itemtype => $frameworkcode,
    itemtypes => GetItemTypeList(),
);

output_html_with_http_headers $input, $cookie, $template->output;
