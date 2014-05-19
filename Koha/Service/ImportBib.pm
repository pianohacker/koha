#!/usr/bin/perl

package Koha::Service::CoverImages;

# Copyright 2012 CatalystIT Ltd
# Copyright (C) 2014 ByWater Solutions
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

use base 'Koha::Service::XML';

use Modern::Perl;

use C4::Context;
use C4::ImportBatch;
use C4::Matcher;
use XML::Simple;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { editcatalogue => 'edit_catalogue' },
        routes => [
            [ qr'POST /', 'import_bib' ],
        ]
    } );
}

sub import_bib {
    my ( $self ) = @_;

    my $inxml = $self->query->param('xml');
    my $params = { map { $_ => $self->query->param($_) } $self->query->param };
    my $result = {};

    my $import_mode = delete $params->{import_mode} || '';
    my $framework   = delete $params->{framework}   || '';

    if (my $matcher_code = delete $params->{match}) {
        $params->{matcher_id} = C4::Matcher::GetMatcherId($matcher_code);
    }

    my $batch_id = GetWebserviceBatchId($params);
    unless ($batch_id) {
        $result->{'status'} = "failed";
        $result->{'error'} = "Batch create error";
        $self->output_simple($result);
        return;
    }

    my $marcflavour = C4::Context->preference('marcflavour') || 'MARC21';
    my $marc_record = eval {MARC::Record::new_from_xml( $inxml, "utf8", $marcflavour)};
    if ($@) {
        $result->{'status'} = "failed";
        $result->{'error'} = $@;
        $self->output_simple($result);
        return;
    }

    my $import_record_id = AddBiblioToBatch($batch_id, 0, $marc_record, "utf8", int(rand(99999)));
    my @import_items_ids = AddItemsToImportBiblio($batch_id, $import_record_id, $marc_record, 'UPDATE COUNTS');

    my $matcher = C4::Matcher->new($params->{record_type} || 'biblio');
    $matcher = C4::Matcher->fetch($params->{matcher_id});
    my $number_of_matches =  BatchFindDuplicates($batch_id, $matcher);

    # XXX we are ignoring the result of this;
    BatchCommitRecords($batch_id, $framework) if lc($import_mode) eq 'direct';

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("SELECT matched_biblionumber FROM import_biblios WHERE import_record_id =?");
    $sth->execute($import_record_id);
    my $biblionumber=$sth->fetchrow_arrayref->[0] || '';
    $sth = $dbh->prepare("SELECT overlay_status FROM import_records WHERE import_record_id =?");
    $sth->execute($import_record_id);
    my $match_status = $sth->fetchrow_arrayref->[0] || 'no_match';
    my $url = 'http://'. C4::Context->preference('staffClientBaseURL') .'/cgi-bin/koha/catalogue/detail.pl?biblionumber='. $biblionumber;

    $result->{'status'} = "ok";
    $result->{'import_batch_id'} = $batch_id;
    $result->{'match_status'} = $match_status;
    $result->{'biblionumber'} = $biblionumber;
    $result->{'url'} = $url;
    $self->output_simple($result);
}

1;
