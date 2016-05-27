package Catmandu::Store::Koha::Biblio::Bag;

use Catmandu::Sane;
use Moo;
use Catmandu::Hits;
use Catmandu::Importer::MARC;
use Catmandu::Importer::MARC::Decoder;
use Catmandu::Exporter::MARC;
use Catmandu::Exporter::MARC::Base;
use Catmandu::Store::Koha::Biblio::Searcher;

use C4::Biblio qw( GetMarcFromKohaField );
use Koha::Biblios;
use Koha::BiblioUtils;
use Koha::SearchEngine::QueryBuilder;
use Koha::SearchEngine::Search;

with 'Catmandu::Bag';
with 'Catmandu::Searchable';

has buffer_size => (is => 'ro', lazy => 1, builder => 'default_buffer_size');
has cql_mapping => (is => 'ro');
has default_frameworkcode => ( is => 'rw' );
has _querybuilder => ( is => 'ro', lazy => 1, builder => 1 );
has record => ( is => 'rw', default => sub { 'record' } );
has _searcher => ( is => 'ro', lazy => 1, builder => 1 );
has on_error => ( is => 'ro', default => sub { 'IGNORE' } );

sub default_buffer_size { 100 }

sub _build__searcher {
    return Koha::SearchEngine::Search->new({index => 'biblios'});
}

sub _build__querybuilder {
    return Koha::SearchEngine::QueryBuilder->new({index => 'biblios'});
}

sub _export {
    my ( $self, $record ) = @_;
    my ( $biblionumtag, $biblionumsubfield ) = GetMarcFromKohaField( "biblio.biblionumber" );
    return Catmandu::Importer::MARC::Decoder->decode( $record, "$biblionumtag$biblionumsubfield" );
}

sub generator {
    my ($self) = @_;
    sub {
        state $iterator = Koha::BiblioUtils->get_all_biblios_iterator();
        my $record = $iterator->next;
        return $record ? $self->_export($record->record) : $record;
    };
}

sub count {
    my ($self) = @_;

    return Koha::Biblios->count;
}

sub get { # TODO ignore missing
    my ($self, $id) = @_;

    my $record = GetMarcBiblio( $id, 1 );
    return $record ? $self->_export($record) : undef;
}

sub add {
    my ($self, $data) = @_;

    my $record = Catmandu::Exporter::MARC::Base->_raw_to_marc_record( $data->{$self->record} );
    return unless scalar $record->fields;

    Catmandu::BadVal->throw('frameworkcode required in record') unless ( $data->{frameworkcode} || defined $self->default_frameworkcode );

    AddBiblio( $record, $data->{frameworkcode} // $self->default_frameworkcode );
}

sub delete {
    my ($self, $id) = @_;

    DelBiblio( $id );
}

sub delete_all { # TODO refresh
    my ($self) = @_;

    Catmandu::NotImplemented->throw('delete_all not implemented');
}

sub delete_by_query { # TODO refresh
    my ($self, %args) = @_;
    my $es = $self->store->es;
    $es->delete_by_query(
        index => $self->store->index_name,
        type  => $self->name,
        body  => {
            query => $args{query},
        },
    );
}

sub commit {
    my ($self) = @_;
}

sub search {
    my ($self, %args) = @_;

    my $searcher = $self->searcher(%args);

    my $results = $searcher->as_array;

    my $hits = {
        start => $args{start},
        limit => $args{limit},
        hits => $results,
        total => scalar @$results,
    };

    $hits = Catmandu::Hits->new($hits);

    return $hits;
}

sub searcher {
    my ($self, %args) = @_;
    $args{limit} = $args{total} if ( !defined $args{limit} || $args{total} > $args{limit} );
    return Catmandu::Store::Koha::Biblio::Searcher->new(%args, bag => $self);
}

sub translate_sru_sortkeys {
    my ($self, $sortkeys) = @_;
    [ grep { defined $_ } map { $self->_translate_sru_sortkey($_) } split /\s+/, $sortkeys ];
}

sub _translate_sru_sortkey {
    my ($self, $sortkey) = @_;
    my ($field, $schema, $asc) = split /,/, $sortkey;

    $asc //= 1;

    return { $field => $asc ? 'asc' : 'desc' };
}

sub translate_cql_query {
    my ($self, $query) = @_;
    return $query;
    #rCatmandu::Store::ElasticSearch::CQL->new(mapping => $self->cql_mapping)->parse($query);
}

=head1 SEE ALSO

L<Catmandu::Bag>, L<Catmandu::Searchable>

=cut

1;
