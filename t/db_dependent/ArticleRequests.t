#!/usr/bin/perl

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

use Modern::Perl;

use POSIX qw(strftime);

use Test::More tests => 49;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Biblio;
use Koha::Patron;
use Koha::Library;
use Koha::CirculationRules;

BEGIN {
    use_ok('Koha::ArticleRequest');
    use_ok('Koha::ArticleRequests');
    use_ok('Koha::ArticleRequest::Status');
}

my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin();
my $builder = t::lib::TestBuilder->new;

my $dbh = C4::Context->dbh;
$dbh->{RaiseError} = 1;

$dbh->do("DELETE FROM circulation_rules");

my $biblio = Koha::Biblio->new()->store();
ok( $biblio->id, 'Koha::Biblio created' );

my $biblioitem = $schema->resultset('Biblioitem')->new(
    {
        biblionumber => $biblio->id
    }
)->insert();
ok( $biblioitem->id, 'biblioitem created' );

my $itype = $builder->build({ source => 'Itemtype' });
my $item = Koha::Item->new(
    {
        biblionumber     => $biblio->id,
        biblioitemnumber => $biblioitem->id,
        itype => $itype->{itemtype},
    }
)->store();
ok( $item->id, 'Koha::Item created' );

my $branch   = $builder->build({ source => 'Branch' });
my $category = $builder->build({ source => 'Category' });
my $patron   = Koha::Patron->new(
    {
        categorycode => $category->{categorycode},
        branchcode   => $branch->{branchcode},
    }
)->store();
ok( $patron->id, 'Koha::Patron created' );

my $article_request = Koha::ArticleRequest->new(
    {
        borrowernumber => $patron->id,
        biblionumber   => $biblio->id,
        itemnumber     => $item->id,
    }
)->store();
$article_request = Koha::ArticleRequests->find( $article_request->id );
ok( $article_request->id, 'Koha::ArticleRequest created' );

is( $article_request->status, Koha::ArticleRequest::Status::Pending, 'New article request has status of Open' );
$article_request->process();
is( $article_request->status, Koha::ArticleRequest::Status::Processing, '$ar->process() changes status to Processing' );
$article_request->complete();
is( $article_request->status, Koha::ArticleRequest::Status::Completed, '$ar->complete() changes status to Completed' );
$article_request->cancel();
is( $article_request->status, Koha::ArticleRequest::Status::Canceled, '$ar->complete() changes status to Canceled' );
$article_request->status(Koha::ArticleRequest::Status::Pending);
$article_request->store();

is( $article_request->biblio->id,   $biblio->id, '$ar->biblio() gets corresponding Koha::Biblio object' );
is( $article_request->item->id,     $item->id,   '$ar->item() gets corresponding Koha::Item object' );
is( $article_request->borrower->id, $patron->id, '$ar->borrower() gets corresponding Koha::Patron object' );

my $ar = $patron->article_requests();
is( ref($ar),      'Koha::ArticleRequests', '$patron->article_requests returns Koha::ArticleRequests object' );
is( $ar->next->id, $article_request->id,    'Returned article request matches' );

is( $patron->article_requests_current()->count(), 1, 'Open request returned for article_requests_current' );
$article_request->process();
is( $patron->article_requests_current()->count(), 1, 'Processing request returned for article_requests_current' );
$article_request->complete();
is( $patron->article_requests_current()->count(), 0, 'Completed request not returned for article_requests_current' );
$article_request->cancel();
is( $patron->article_requests_current()->count(), 0, 'Canceled request not returned for article_requests_current' );

$article_request->status(Koha::ArticleRequest::Status::Pending);
$article_request->store();

is( $patron->article_requests_finished()->count(), 0, 'Open request returned for article_requests_finished' );
$article_request->process();
is( $patron->article_requests_finished()->count(), 0, 'Processing request returned for article_requests_finished' );
$article_request->complete();
$article_request->cancel();
is( $patron->article_requests_finished()->count(), 1, 'Canceled request not returned for article_requests_finished' );

$article_request->status(Koha::ArticleRequest::Status::Pending);
$article_request->store();

$ar = $biblio->article_requests();
is( ref($ar),      'Koha::ArticleRequests', '$biblio->article_requests returns Koha::ArticleRequests object' );
is( $ar->next->id, $article_request->id,    'Returned article request matches' );

is( $biblio->article_requests_current()->count(), 1, 'Open request returned for article_requests_current' );
$article_request->process();
is( $biblio->article_requests_current()->count(), 1, 'Processing request returned for article_requests_current' );
$article_request->complete();
is( $biblio->article_requests_current()->count(), 0, 'Completed request not returned for article_requests_current' );
$article_request->cancel();
is( $biblio->article_requests_current()->count(), 0, 'Canceled request not returned for article_requests_current' );

$article_request->status(Koha::ArticleRequest::Status::Pending);
$article_request->store();

is( $biblio->article_requests_finished()->count(), 0, 'Open request returned for article_requests_finished' );
$article_request->process();
is( $biblio->article_requests_finished()->count(), 0, 'Processing request returned for article_requests_finished' );
$article_request->complete();
$article_request->cancel();
is( $biblio->article_requests_finished()->count(), 1, 'Canceled request not returned for article_requests_finished' );

my $rule = Koha::CirculationRules->set_rule(
    {
        categorycode => undef,
        itemtype     => undef,
        branchcode   => undef,
        rule_name    => 'article_requests',
        rule_value   => 'yes',
    }
);
ok( $biblio->can_article_request($patron), 'Record is requestable with rule type yes' );
is( $biblio->article_request_type($patron), 'yes', 'Biblio article request type is yes' );
ok( $item->can_article_request($patron),   'Item is requestable with rule type yes' );
is( $item->article_request_type($patron), 'yes', 'Item article request type is yes' );
$rule->delete();

$rule = Koha::CirculationRules->set_rule(
    {
        categorycode => undef,
        itemtype     => undef,
        branchcode   => undef,
        rule_name    => 'article_requests',
        rule_value   => 'bib_only',
    }
);
ok( $biblio->can_article_request($patron), 'Record is requestable with rule type bib_only' );
is( $biblio->article_request_type($patron), 'bib_only', 'Biblio article request type is bib_only' );
ok( !$item->can_article_request($patron),  'Item is not requestable with rule type bib_only' );
is( $item->article_request_type($patron), 'bib_only', 'Item article request type is bib_only' );
$rule->delete();

$rule = Koha::CirculationRules->set_rule(
    {
        categorycode => undef,
        itemtype     => undef,
        branchcode   => undef,
        rule_name    => 'article_requests',
        rule_value   => 'item_only',
    }
);
ok( $biblio->can_article_request($patron), 'Record is requestable with rule type item_only' );
is( $biblio->article_request_type($patron), 'item_only', 'Biblio article request type is item_only' );
ok( $item->can_article_request($patron),   'Item is not requestable with rule type item_only' );
is( $item->article_request_type($patron), 'item_only', 'Item article request type is item_only' );
$rule->delete();

$rule = Koha::CirculationRules->set_rule(
    {
        categorycode => undef,
        itemtype     => undef,
        branchcode   => undef,
        rule_name    => 'article_requests',
        rule_value   => 'no',
    }
);
ok( !$biblio->can_article_request($patron), 'Record is requestable with rule type no' );
is( $biblio->article_request_type($patron), 'no', 'Biblio article request type is no' );
ok( !$item->can_article_request($patron),   'Item is not requestable with rule type no' );
is( $item->article_request_type($patron), 'no', 'Item article request type is no' );
$rule->delete();

$schema->storage->txn_rollback();
