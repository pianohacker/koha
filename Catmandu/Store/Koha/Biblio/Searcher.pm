package Catmandu::Store::Koha::Biblio::Searcher;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Iterable';

has bag  => (is => 'ro', required => 1);
has query => (is => 'ro', required => 1);
has _parsed_query => (is => 'ro', lazy => 1, builder => 1);
has start => (is => 'ro', required => 1);
has limit => (is => 'ro', required => 1);
has total => (is => 'ro');
has sort => (is => 'ro');

sub _build__parsed_query {
    my ($self) = @_;
    my ( undef, $query ) = $self->bag->_querybuilder->build_query_compat(
        [], # operators
        [ $self->query ], # operands
        [], # indexes
        [], # orig_limits
        $self->sort, # sort_by
    );

    return $query;
}

sub generator {
    my ($self) = @_;

    my @hits;

    return sub {
        state $total = $self->total;
        return if defined $total && $total == 0;
        state $offset = 0;

        unless ( scalar @hits ) {
            my $to_fetch = defined $self->limit ? $self->limit - $offset : $self->bag->buffer_size;

            if ( $self->bag->buffer_size < $to_fetch ) {
                $to_fetch = $self->bag->buffer_size;
            } elsif ( $to_fetch < 0 ) {
                $to_fetch = 0;
            }

            warn $offset, $to_fetch;
            my ( undef, $results ) = $self->bag->_searcher->search_compat(
                $self->_parsed_query,
                undef,
                $self->sort,
                [ 'biblioserver' ],
                $to_fetch,
                $offset + $self->start,
            );
            @hits = @{ $results->{biblioserver}->{RECORDS} };
            my $num_hits = scalar @hits;

            return unless $num_hits;

            $offset += $num_hits;
        }

        my $record = shift @hits // return;
        if ($total) {
            $total--;
        }

        return $self->bag->_export( $record );
    };
}

sub slice { # TODO constrain total?
    my ($self, $start, $total) = @_;
    $start //= 0;
    $self->new(
        bag   => $self->bag,
        query => $self->query,
        start => $self->start + $start,
        limit => $self->limit,
        total => $total,
        sort  => $self->sort,
    );
}

sub count {
    my ($self) = @_;

    return $self->bag->_searcher->count($self->_parsed_query);
}

1;
