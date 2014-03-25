#!/usr/bin/perl
#
# This Koha test module is a stub!
# Add more tests here!!!

use Modern::Perl;
use POSIX qw(strftime);

use C4::Bookseller qw( GetBookSellerFromId );

use Test::More tests => 64;

BEGIN {
    use_ok('C4::Acquisition');
    use_ok('C4::Bookseller');
    use_ok('C4::Biblio');
    use_ok('C4::Budgets');
    use_ok('C4::Bookseller');
}

# Sub used for testing C4::Acquisition subs returning order(s):
#    GetOrdersByStatus, GetOrders, GetDeletedOrders, GetOrder etc.
# (\@test_missing_fields,\@test_extra_fields,\@test_different_fields,$test_nbr_fields) =
#  _check_fields_of_order ($exp_fields, $original_order_content, $order_to_check);
# params :
# $exp_fields             : arrayref whose elements are the keys we expect to find
# $original_order_content : hashref whose 2 keys str and num contains hashrefs
#                           containing content fields of the order created with NewOrder
# $order_to_check         : hashref whose keys/values are the content of an order
#                           returned by the C4::Acquisition sub we are testing
# returns :
# \@test_missing_fields   : arrayref void if ok ; otherwise contains the list of
#                           fields missing in $order_to_check
# \@test_extra_fields     : arrayref void if ok ; otherwise contains the list of
#                           fields unexpected in $order_to_check
# \@test_different_fields : arrayref void if ok ; otherwise contains the list of
#                           fields which value is not the same in between $order_to_check and
# $test_nbr_fields        : contains the number of fields of $order_to_check

sub _check_fields_of_order {
    my ( $exp_fields, $original_order_content, $order_to_check ) = @_;
    my @test_missing_fields   = ();
    my @test_extra_fields     = ();
    my @test_different_fields = ();
    my $test_nbr_fields       = scalar( keys %$order_to_check );
    foreach my $field (@$exp_fields) {
        push @test_missing_fields, $field
          unless exists( $order_to_check->{$field} );
    }
    foreach my $field ( keys %$order_to_check ) {
        push @test_extra_fields, $field
          unless grep ( /^$field$/, @$exp_fields );
    }
    foreach my $field ( keys %{ $original_order_content->{str} } ) {
        push @test_different_fields, $field
          unless ( !exists $order_to_check->{$field} )
          or ( $original_order_content->{str}->{$field} eq
            $order_to_check->{$field} );
    }
    foreach my $field ( keys %{ $original_order_content->{num} } ) {
        push @test_different_fields, $field
          unless ( !exists $order_to_check->{$field} )
          or ( $original_order_content->{num}->{$field} ==
            $order_to_check->{$field} );
    }
    return (
        \@test_missing_fields,   \@test_extra_fields,
        \@test_different_fields, $test_nbr_fields
    );
}

# Sub used for testing C4::Acquisition subs returning several orders
# (\@test_missing_fields,\@test_extra_fields,\@test_different_fields,\@test_nbr_fields) =
#   _check_fields_of_orders ($exp_fields, $original_orders_content, $orders_to_check)
sub _check_fields_of_orders {
    my ( $exp_fields, $original_orders_content, $orders_to_check ) = @_;
    my @test_missing_fields   = ();
    my @test_extra_fields     = ();
    my @test_different_fields = ();
    my @test_nbr_fields       = ();
    foreach my $order_to_check (@$orders_to_check) {
        my $original_order_content =
          ( grep { $_->{str}->{ordernumber} eq $order_to_check->{ordernumber} }
              @$original_orders_content )[0];
        my (
            $t_missing_fields,   $t_extra_fields,
            $t_different_fields, $t_nbr_fields
          )
          = _check_fields_of_order( $exp_fields, $original_order_content,
            $order_to_check );
        push @test_missing_fields,   @$t_missing_fields;
        push @test_extra_fields,     @$t_extra_fields;
        push @test_different_fields, @$t_different_fields;
        push @test_nbr_fields,       $t_nbr_fields;
    }
    @test_missing_fields = keys %{ { map { $_ => 1 } @test_missing_fields } };
    @test_extra_fields   = keys %{ { map { $_ => 1 } @test_extra_fields } };
    @test_different_fields =
      keys %{ { map { $_ => 1 } @test_different_fields } };
    return (
        \@test_missing_fields,   \@test_extra_fields,
        \@test_different_fields, \@test_nbr_fields
    );
}

my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

# Creating some orders
my $booksellerid = C4::Bookseller::AddBookseller(
    {
        name         => "my vendor",
        address1     => "bookseller's address",
        phone        => "0123456",
        active       => 1,
        deliverytime => 5,
    }
);

my $booksellerinfo = C4::Bookseller::GetBookSellerFromId($booksellerid);

is( $booksellerinfo->{deliverytime},
    5, 'set deliverytime when creating vendor (Bug 10556)' );

my ( $basket, $basketno );
ok(
    $basketno = NewBasket( $booksellerid, 1 ),
    "NewBasket(  $booksellerid , 1  ) returns $basketno"
);
ok( $basket = GetBasket($basketno), "GetBasket($basketno) returns $basket" );

my $budgetid = C4::Budgets::AddBudget(
    {
        budget_code => "budget_code_test_getordersbybib",
        budget_name => "budget_name_test_getordersbybib",
    }
);
my $budget = C4::Budgets::GetBudget($budgetid);

my @ordernumbers;
my ( $biblionumber1, $biblioitemnumber1 ) = AddBiblio( MARC::Record->new, '' );
my ( $biblionumber2, $biblioitemnumber2 ) = AddBiblio( MARC::Record->new, '' );
my ( $biblionumber3, $biblioitemnumber3 ) = AddBiblio( MARC::Record->new, '' );
my ( $biblionumber4, $biblioitemnumber4 ) = AddBiblio( MARC::Record->new, '' );

#
# Test NewOrder
#

my ( $mandatoryparams, $return_error, $basketnum );

# returns undef and croaks if basketno, quantity, biblionumber or budget_id is missing
eval { ( $basketnum, $ordernumbers[0] ) = C4::Acquisition::NewOrder() };
$return_error = $@;
ok(
    ( !( defined $basketnum || defined $ordernumbers[0] ) )
      && ( defined $return_error ),
    "NewOrder with no params returns undef and croaks"
);

$mandatoryparams = {
    basketno     => $basketno,
    quantity     => 24,
    biblionumber => $biblionumber1,
    budget_id    => $budget->{budget_id},
};
my @mandatoryparams_keys = keys %$mandatoryparams;
foreach my $mandatoryparams_key (@mandatoryparams_keys) {
    my %test_missing_mandatoryparams = %$mandatoryparams;
    delete $test_missing_mandatoryparams{$mandatoryparams_key};
    eval {
        ( $basketnum, $ordernumbers[0] ) =
          C4::Acquisition::NewOrder( \%test_missing_mandatoryparams );
    };
    $return_error = $@;
    my $expected_error = "Mandatory parameter $mandatoryparams_key missing";
    ok(
        ( !( defined $basketnum || defined $ordernumbers[0] ) )
          && ( index( $return_error, $expected_error ) >= 0 ),
"NewOrder with no $mandatoryparams_key returns undef and croaks with expected error message"
    );
}

# FIXME to do : test the other features of NewOrder

# Prepare 5 orders, and make distinction beween fields to be tested with eq and with ==
# Ex : a price of 50.1 will be stored internally as 5.100000

my @order_content = (
    {
        str => {
            basketno       => $basketno,
            biblionumber   => $biblionumber1,
            budget_id      => $budget->{budget_id},
            uncertainprice => 0,
            notes          => "some notes",
        },
        num => {
            quantity  => 24,
            listprice => 50.121111,
            ecost     => 38.15,
            rrp       => 40.15,
            discount  => 5.1111,
            gstrate   => 0.0515
        }
    },
    {
        str => {
            basketno     => $basketno,
            biblionumber => $biblionumber2,
            budget_id    => $budget->{budget_id}
        },
        num => { quantity => 42 }
    },
    {
        str => {
            basketno       => $basketno,
            biblionumber   => $biblionumber2,
            budget_id      => $budget->{budget_id},
            uncertainprice => 0,
            notes          => "ordernotes"
        },
        num => {
            quantity  => 4,
            ecost     => 42.1,
            rrp       => 42.1,
            listprice => 10.1,
            ecost     => 38.1,
            rrp       => 11.0,
            discount  => 5.1,
            gstrate   => 0.1
        }
    },
    {
        str => {
            basketno     => $basketno,
            biblionumber => $biblionumber3,
            budget_id    => $budget->{budget_id},
            notes        => "ordernotes"
        },
        num => {
            quantity       => 4,
            ecost          => 40,
            rrp            => 42,
            listprice      => 10,
            ecost          => 38.15,
            rrp            => 11.00,
            discount       => 0,
            uncertainprice => 0,
            gstrate        => 0
        }
    },
    {
        str => {
            basketno     => $basketno,
            biblionumber => $biblionumber4,
            budget_id    => $budget->{budget_id},
            notes        => "ordernotes"
        },
        num => {
            quantity       => 1,
            ecost          => 10,
            rrp            => 10,
            listprice      => 10,
            ecost          => 10,
            rrp            => 10,
            discount       => 0,
            uncertainprice => 0,
            gstrate        => 0
        }
    }
);

# Create 4 orders in database
for ( 0 .. 4 ) {
    my %ocontent;
    @ocontent{ keys %{ $order_content[$_]->{num} } } =
      values %{ $order_content[$_]->{num} };
    @ocontent{ keys %{ $order_content[$_]->{str} } } =
      values %{ $order_content[$_]->{str} };
    ( undef, $ordernumbers[$_] ) = C4::Acquisition::NewOrder( \%ocontent );
    $order_content[$_]->{str}->{ordernumber} = $ordernumbers[$_];
}

# Test UT sub _check_fields_of_order

my (
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_order(
    [qw /a b c d e/],
    { str => { a => "bla", b => "105" }, num => { c => 15.12 } },
    { a => "blabla", f => "f", b => "105", c => 15.1200, g => '' }
  );
ok(
    (
              ( $test_nbr_fields == 5 )
          and ( join( " ", sort @$test_missing_fields ) eq 'd e' )
          and ( join( " ", sort @$test_extra_fields )   eq 'f g' )
          and ( join( " ", @$test_different_fields )    eq 'a' )
    ),
    "_check_fields_of_order can check an order (test 1)"
);
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_order(
    [qw /a b c /],
    { str => { a => "bla", b => "105" }, num => { c => 15.00 } },
    { a => "bla", b => "105", c => 15 }
  );
ok(
    (
              ( $test_nbr_fields == 3 )
          and ( scalar @$test_missing_fields == 0 )
          and ( scalar @$test_extra_fields == 0 )
          and ( scalar @$test_different_fields == 0 )
    ),
    "_check_fields_of_order can check an order (test 2)"
);
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_order(
    [qw /a b c d e/],
    { str => { a => "bla", b => "105" }, num => { c => 15.12 } },
    { a => "blabla", b => "105", c => 15, d => "error" }
  );
ok(
    (
              ( $test_nbr_fields == 4 )
          and ( join( " ", sort @$test_missing_fields ) eq 'e' )
          and ( scalar @$test_extra_fields == 0 )
          and ( join( " ", @$test_different_fields ) eq 'a c' )
    ),
    "_check_fields_of_order can check an order (test 3)"
);

#
# test GetOrder
#

my @expectedfields = qw(
  ordernumber
  biblionumber
  entrydate
  quantity
  currency
  listprice
  totalamount
  datereceived
  invoiceid
  freight
  unitprice
  quantityreceived
  cancelledby
  datecancellationprinted
  notes
  supplierreference
  purchaseordernumber
  basketno
  timestamp
  rrp
  ecost
  unitpricesupplier
  unitpricelib
  gstrate
  discount
  budget_id
  budgetgroup_id
  budgetdate
  sort1
  sort2
  sort1_authcat
  sort2_authcat
  uncertainprice
  claims_count
  claimed_date
  subscriptionid
  parent_ordernumber
  orderstatus
  title
  author
  basketname
  branchcode
  publicationyear
  copyrightdate
  editionstatement
  isbn
  ean
  seriestitle
  publishercode
  publisher
  budget
  supplier
  supplierid
  estimateddeliverydate
  orderdate
  quantity_to_receive
  subtotal
  latesince
);
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_order( \@expectedfields, $order_content[0],
    GetOrder( $ordernumbers[0] ) );
is(
    $test_nbr_fields,
    scalar @expectedfields,
    "GetOrder gets an order with the right number of fields"
);
is( join( " ", @$test_missing_fields ),
    '', "GetOrder gets an order with no missing fields" );
is( join( " ", @$test_extra_fields ),
    '', "GetOrder gets an order with no unexpected fields" );
is( join( " ", @$test_different_fields ),
    '', "GetOrder gets an order with the right content in every fields" );

#
# Test GetOrders
#

my @base_expectedfields = qw(
  ordernumber
  ecost
  uncertainprice
  marc
  cancelledby
  url
  isbn
  copyrightdate
  serial
  cn_suffix
  cn_item
  marcxml
  freight
  cn_class
  title
  pages
  budget_encumb
  budget_name
  number
  itemtype
  totalissues
  author
  budget_permission
  parent_ordernumber
  size
  claims_count
  currency
  seriestitle
  timestamp
  editionstatement
  budget_parent_id
  publishercode
  unitprice
  collectionvolume
  budget_amount
  budget_owner_id
  datecreated
  claimed_date
  subscriptionid
  editionresponsibility
  sort2
  notes
  volumedate
  budget_id
  illus
  ean
  biblioitemnumber
  datereceived
  orderstatus
  supplierreference
  agerestriction
  budget_branchcode
  gstrate
  listprice
  budget_code
  budgetdate
  basketno
  discount
  abstract
  collectionissn
  publicationyear
  collectiontitle
  invoiceid
  budgetgroup_id
  place
  issn
  quantityreceived
  entrydate
  cn_source
  sort1_authcat
  budget_notes
  biblionumber
  unititle
  sort2_authcat
  budget_expend
  rrp
  cn_sort
  totalamount
  lccn
  sort1
  volume
  purchaseordernumber
  quantity
  budget_period_id
  frameworkcode
  volumedesc
  datecancellationprinted
);
@expectedfields =
  ( @base_expectedfields,
    ( 'transferred_from_timestamp', 'transferred_from' ) );
is( GetOrders(), undef, "GetOrders with no params returns undef" );
DelOrder( $order_content[3]->{str}->{biblionumber}, $ordernumbers[3] );
my @get_orders = GetOrders($basketno);
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_orders( \@expectedfields, \@order_content, \@get_orders );
is(
    $$test_nbr_fields[0],
    scalar @expectedfields,
    "GetOrders gets orders with the right number of fields"
);
is( join( " ", @$test_missing_fields ),
    '', "GetOrders gets orders with no missing fields" );
is( join( " ", @$test_extra_fields ),
    '', "GetOrders gets orders with no unexpected fields" );
is( join( " ", @$test_different_fields ),
    '', "GetOrders gets orders with the right content in every fields" );
ok(
    (
        ( scalar @get_orders == 4 )
          and !grep ( $_->{ordernumber} eq $ordernumbers[3], @get_orders )
    ),
    "GetOrders only gets non-cancelled orders"
);

#
# Test GetCancelledOrders
#

@expectedfields =
  ( @base_expectedfields, ( 'transferred_to_timestamp', 'transferred_to' ) );
is( GetCancelledOrders(), undef,
    "GetCancelledOrders with no params returns undef" );
@get_orders = GetCancelledOrders($basketno);
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_orders( \@expectedfields, \@order_content, \@get_orders );
is(
    $$test_nbr_fields[0],
    scalar @expectedfields,
    "GetCancelledOrders gets orders with the right number of fields"
);
is( join( " ", @$test_missing_fields ),
    '', "GetCancelledOrders gets orders with no missing fields" );
is( join( " ", @$test_extra_fields ),
    '', "GetCancelledOrders gets orders with no unexpected fields" );
is( join( " ", @$test_different_fields ),
    '',
    "GetCancelledOrders gets orders with the right content in every fields" );
ok(
    (
        ( scalar @get_orders == 1 )
          and grep ( $_->{ordernumber} eq $ordernumbers[3], @get_orders )
    ),
    "GetCancelledOrders only gets cancelled orders"
);

#
# Test SearchOrders
#

@expectedfields = qw (
  basketgroupid
  basketgroupname
  firstname
  biblioitemnumber
  ecost
  uncertainprice
  creationdate
  datereceived
  orderstatus
  supplierreference
  cancelledby
  isbn
  copyrightdate
  gstrate
  serial
  listprice
  budgetdate
  basketno
  discount
  surname
  freight
  abstract
  title
  closedate
  basketname
  budgetgroup_id
  invoiceid
  author
  parent_ordernumber
  claims_count
  entrydate
  currency
  quantityreceived
  seriestitle
  sort1_authcat
  timestamp
  biblionumber
  unititle
  sort2_authcat
  rrp
  unitprice
  totalamount
  sort1
  ordernumber
  datecreated
  purchaseordernumber
  quantity
  claimed_date
  subscriptionid
  frameworkcode
  sort2
  notes
  datecancellationprinted
  budget_id
  authorisedby
);

# note that authorisedby was added to the return of SearchOrder by the
# patch for bug 11777

my $invoiceid = AddInvoice(
    invoicenumber => 'invoice',
    booksellerid  => $booksellerid,
    unknown       => "unknown"
);

my ( $datereceived, $new_ordernumber ) =
  ModReceiveOrder( $biblionumber4, $ordernumbers[4], 1, undef, 10, 10,
    $invoiceid, 10, $order_content[4]->{str}->{budget_id} );

my $search_orders = SearchOrders({
    booksellerid => $booksellerid,
    basketno     => $basketno
});
isa_ok( $search_orders, 'ARRAY' );
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_orders( \@expectedfields, \@order_content,
    $search_orders );
is(
    $$test_nbr_fields[0],
    scalar @expectedfields,
    "SearchOrders gets orders with the right number of fields"
);
is( join( " ", @$test_missing_fields ),
    '', "SearchOrders gets orders with no missing fields" );
is( join( " ", @$test_extra_fields ),
    '', "SearchOrders gets orders with no unexpected fields" );
is( join( " ", @$test_different_fields ),
    '', "SearchOrders gets orders with the right content in every fields" );
ok(
    (
        ( scalar @$search_orders == 4 )
          and !grep ( $_->{ordernumber} eq $ordernumbers[3], @$search_orders )
    ),
    "SearchOrders only gets non-cancelled orders"
);

$search_orders = SearchOrders({
    booksellerid => $booksellerid,
    basketno     => $basketno,
    pending      => 1
});
ok(
    (
        ( scalar @$search_orders == 3 ) and !grep ( (
                     ( $_->{ordernumber} eq $ordernumbers[3] )
                  or ( $_->{ordernumber} eq $ordernumbers[4] )
            ),
            @$search_orders )
    ),
    "SearchOrders with pending params gets only pending orders (bug 10723)"
);

#
# Test GetBudgetByOrderNumber
#

ok( GetBudgetByOrderNumber( $ordernumbers[0] )->{'budget_id'} eq $budgetid,
    "GetBudgetByOrderNumber returns expected budget" );

#
# Test GetLateOrders
#

@expectedfields = qw (
  orderdate
  author
  budget
  supplierid
  claims_count
  supplier
  publisher
  ordernumber
  quantity
  basketno
  claimed_date
  branch
  estimateddeliverydate
  title
  publicationyear
  unitpricelib
  unitpricesupplier
  subtotal
  latesince
);
my @lateorders = GetLateOrders(0);
is( scalar grep ( $_->{basketno} eq $basketno, @lateorders ),
    0, "GetLateOrders does not get orders from opened baskets" );
C4::Acquisition::CloseBasket($basketno);
@lateorders = GetLateOrders(0);
isnt( scalar grep ( $_->{basketno} eq $basketno, @lateorders ),
    0, "GetLateOrders gets orders from closed baskets" );
ok( !grep ( $_->{ordernumber} eq $ordernumbers[3], @lateorders ),
    "GetLateOrders does not gets cancelled orders" );
ok( !grep ( $_->{ordernumber} eq $ordernumbers[4], @lateorders ),
    "GetLateOrders does not gets reveived orders" );
(
    $test_missing_fields,   $test_extra_fields,
    $test_different_fields, $test_nbr_fields
  )
  = _check_fields_of_orders( \@expectedfields, \@order_content, \@lateorders );
is(
    $$test_nbr_fields[0],
    scalar @expectedfields,
    "GetLateOrders gets orders with the right number of fields"
);
is( join( " ", @$test_missing_fields ),
    '', "GetLateOrders gets orders with no missing fields" );
is( join( " ", @$test_extra_fields ),
    '', "GetLateOrders gets orders with no unexpected fields" );
is( join( " ", @$test_different_fields ),
    '', "GetLateOrders gets orders with the right content in every fields" );

#
# Test AddClaim
#

my $order = $lateorders[0];
AddClaim( $order->{ordernumber} );
my $neworder = GetOrder( $order->{ordernumber} );
is(
    $neworder->{claimed_date},
    strftime( "%Y-%m-%d", localtime(time) ),
    "AddClaim : Check claimed_date"
);

( $datereceived, $new_ordernumber ) =
  ModReceiveOrder( $biblionumber2, $ordernumbers[1], 2, undef, 12, 12,
    $invoiceid, 42, );
my $order2 = GetOrder( $ordernumbers[1] );
is( $order2->{'quantityreceived'},
    0, 'Splitting up order did not receive any on original order' );
is( $order2->{'quantity'}, 40, '40 items on original order' );
is( $order2->{'budget_id'}, $budgetid,
    'Budget on original order is unchanged' );

$neworder = GetOrder($new_ordernumber);
is( $neworder->{'quantity'}, 2, '2 items on new order' );
is( $neworder->{'quantityreceived'},
    2, 'Splitting up order received items on new order' );
is( $neworder->{'budget_id'}, $budgetid, 'Budget on new order is unchanged' );

my $budgetid2 = C4::Budgets::AddBudget(
    {
        budget_code => "budget_code_test_modrecv",
        budget_name => "budget_name_test_modrecv",
    }
);

( $datereceived, $new_ordernumber ) =
  ModReceiveOrder( $biblionumber2, $ordernumbers[2], 2, undef, 12, 12,
    $invoiceid, 42, $budgetid2 );

my $order3 = GetOrder( $ordernumbers[2] );
is( $order3->{'quantityreceived'},
    0, 'Splitting up order did not receive any on original order' );
is( $order3->{'quantity'}, 2, '2 items on original order' );
is( $order3->{'budget_id'}, $budgetid,
    'Budget on original order is unchanged' );

$neworder = GetOrder($new_ordernumber);
is( $neworder->{'quantity'}, 2, '2 items on new order' );
is( $neworder->{'quantityreceived'},
    2, 'Splitting up order received items on new order' );
is( $neworder->{'budget_id'}, $budgetid2, 'Budget on new order is changed' );

( $datereceived, $new_ordernumber ) =
  ModReceiveOrder( $biblionumber2, $ordernumbers[2], 2, undef, 12, 12,
    $invoiceid, 42, $budgetid2 );

$order3 = GetOrder( $ordernumbers[2] );
is( $order3->{'quantityreceived'}, 2,          'Order not split up' );
is( $order3->{'quantity'},         2,          '2 items on order' );
is( $order3->{'budget_id'},        $budgetid2, 'Budget has changed' );

$dbh->rollback;
