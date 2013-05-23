#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use C4::Acquisition;
use C4::Biblio;
use C4::Bookseller;
use C4::Budgets;
use MARC::Record;

my $booksellerid = C4::Bookseller::AddBookseller(
    {
        name => "my vendor",
        address1 => "bookseller's address",
        phone => "0123456",
        active => 1
    }
);

my $basketno = C4::Acquisition::NewBasket(
    $booksellerid
);

my $budgetid = C4::Budgets::AddBudget(
    {
        budget_code => "budget_code_test_getordersbybib",
        budget_name => "budget_name_test_getordersbybib",
    }
);

my $budget = C4::Budgets::GetBudget( $budgetid );

my ($ordernumber1, $ordernumber2, $ordernumber3);
my ($biblionumber1, $biblioitemnumber1) = AddBiblio(MARC::Record->new, '');
my ($biblionumber2, $biblioitemnumber2) = AddBiblio(MARC::Record->new, '');
( undef, $ordernumber1 ) = C4::Acquisition::NewOrder(
    {
        basketno => $basketno,
        quantity => 24,
        biblionumber => $biblionumber1,
        budget_id => $budget->{budget_id},
    }
);

( undef, $ordernumber2 ) = C4::Acquisition::NewOrder(
    {
        basketno => $basketno,
        quantity => 42,
        biblionumber => $biblionumber2,
        budget_id => $budget->{budget_id},
    }
);

( undef, $ordernumber3 ) = C4::Acquisition::NewOrder(
    {
        basketno => $basketno,
        quantity => 4,
        biblionumber => $biblionumber2,
        budget_id => $budget->{budget_id},
    }
);

my @orders = GetOrdersByBiblionumber();
is(scalar(@orders), 0, 'GetOrdersByBiblionumber : no argument, return undef');

@orders = GetOrdersByBiblionumber( $biblionumber1 );
is(scalar(@orders), 1, '1 order on biblionumber 1');

@orders = GetOrdersByBiblionumber( $biblionumber2 );
is(scalar(@orders), 2, '2 orders on biblionumber 2');

END {
    C4::Acquisition::DelOrder( 1, $ordernumber1 );
    C4::Acquisition::DelOrder( 2, $ordernumber2 );
    C4::Acquisition::DelOrder( 3, $ordernumber3 );
    C4::Budgets::DelBudget( $budgetid );
    C4::Acquisition::DelBasket( $basketno );
    C4::Bookseller::DelBookseller( $booksellerid );
    C4::Biblio::DelBiblio($biblionumber1);
    C4::Biblio::DelBiblio($biblionumber2);
};

done_testing;
