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

use Test::More tests => 8;
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Context;
use Koha::Database;

BEGIN {
    use_ok('Koha::Object');
    use_ok('Koha::CirculationRule');
    use_ok('Koha::RefundLostItemFeeRules');
}

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Koha::RefundLostItemFeeRule::delete() tests' => sub {

    plan tests => 5;

    # Start transaction
    $schema->storage->txn_begin;

    # Clean the table
    $schema->resultset('CirculationRule')->search()->delete;

    my $generated_default_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => undef,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
            }
        }
    );
    my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
    my $generated_other_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
            }
        }
    );

    my $default_rule = Koha::CirculationRules->search(
        {
            branchcode   => undef,
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'refund',
        }
    )->next();
    ok( defined $default_rule, 'Default rule created' );
    ok( $default_rule->_result->in_storage, 'Default rule actually in storage');

    my $other_rule = Koha::CirculationRules->search(
        {
            branchcode   => $generated_other_rule->{branchcode},
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'refund',
        }
    )->next();
    ok( defined $other_rule, 'Other rule created' );
    ok( $other_rule->_result->in_storage, 'Other rule actually in storage');

    # deleting the regular rule
    $other_rule->delete;
    ok( !$other_rule->_result->in_storage, 'Other rule deleted from storage' );

    # Rollback transaction
    $schema->storage->txn_rollback;
};

subtest 'Koha::RefundLostItemFeeRules::_default_rule() tests' => sub {

    plan tests => 6;

    # Start transaction
    $schema->storage->txn_begin;

    # Clean the table
    $schema->resultset('CirculationRule')->search()->delete;

    my $generated_default_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => undef,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 1,
            }
        }
    );
    my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
    my $generated_other_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
            }
        }
    );

    my $default_rule = Koha::CirculationRules->search(
        {
            branchcode   => undef,
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'refund',
        }
    )->next();
    ok( defined $default_rule, 'Default rule created' );
    ok( $default_rule->_result->in_storage, 'Default rule actually in storage');
    is( Koha::RefundLostItemFeeRules->_default_rule, 1, 'Default rule is set to refund' );

    # Change default rule to "Don't refund"
    $default_rule->rule_value(0);
    $default_rule->store;
    # Re-read from DB, to be sure
    $default_rule = Koha::CirculationRules->search(
        {
            branchcode   => undef,
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'refund',
        }
    )->next();
    ok( !Koha::RefundLostItemFeeRules->_default_rule, 'Default rule is set to not refund' );

    $default_rule->delete;
    ok( !$default_rule->_result->in_storage, 'Default rule effectively deleted from storage' );

    ok( Koha::RefundLostItemFeeRules->_default_rule, 'Default rule is set to refund if no default rule is present' );

    # Rollback transaction
    $schema->storage->txn_rollback;
};

subtest 'Koha::RefundLostItemFeeRules::_effective_branch_rule() tests' => sub {

    plan tests => 3;

    # Start transaction
    $schema->storage->txn_begin;

    # Clean the table
    $schema->resultset('CirculationRule')->search()->delete;

    my $default_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => undef,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 1,
            }
        }
    );
    my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
    my $specific_rule_false = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 0,
            }
        }
    );
    my $branchcode2 = $builder->build( { source => 'Branch' } )->{branchcode};
    my $specific_rule_true = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode2,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 1,
            }
        }
    );

    is( Koha::RefundLostItemFeeRules->_effective_branch_rule( $specific_rule_true->{ branchcode } ),
          1,'Specific rule is applied (true)');
    is( Koha::RefundLostItemFeeRules->_effective_branch_rule( $specific_rule_false->{ branchcode } ),
          0,'Specific rule is applied (false)');
    # Delete specific rules
    Koha::RefundLostItemFeeRules->find({ branchcode => $specific_rule_false->{ branchcode } })->delete;
    is( Koha::RefundLostItemFeeRules->_effective_branch_rule( $specific_rule_false->{ branchcode } ),
          1,'No specific rule defined, fallback to global (true)');

    # Rollback transaction
    $schema->storage->txn_rollback;
};

subtest 'Koha::RefundLostItemFeeRules::_choose_branch() tests' => sub {

    plan tests => 9;

    # Start transaction
    $schema->storage->txn_begin;

    my $params = {
        current_branch => 'current_branch_code',
        item_holding_branch => 'item_holding_branch_code',
        item_home_branch => 'item_home_branch_code'
    };

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'CheckinLibrary' );

    is( Koha::RefundLostItemFeeRules->_choose_branch( $params ),
        'current_branch_code', 'CheckinLibrary is honoured');

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHomeBranch' );
    is( Koha::RefundLostItemFeeRules->_choose_branch( $params ),
        'item_home_branch_code', 'ItemHomeBranch is honoured');

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHoldingBranch' );
    is( Koha::RefundLostItemFeeRules->_choose_branch( $params ),
        'item_holding_branch_code', 'ItemHoldingBranch is honoured');

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'CheckinLibrary' );
    eval {
        Koha::RefundLostItemFeeRules->_choose_branch();
    };
    is( ref($@), 'Koha::Exceptions::MissingParameter',
        'Missing parameter exception' );
    is( $@->message, 'CheckinLibrary requires the current_branch param',
        'Exception message is correct' );

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHomeBranch' );
    eval {
        Koha::RefundLostItemFeeRules->_choose_branch();
    };
    is( ref($@), 'Koha::Exceptions::MissingParameter',
        'Missing parameter exception' );
    is( $@->message, 'ItemHomeBranch requires the item_home_branch param',
        'Exception message is correct' );

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHoldingBranch' );
    eval {
        Koha::RefundLostItemFeeRules->_choose_branch();
    };
    is( ref($@), 'Koha::Exceptions::MissingParameter',
        'Missing parameter exception' );
    is( $@->message, 'ItemHoldingBranch requires the item_holding_branch param',
        'Exception message is correct' );

    # Rollback transaction
    $schema->storage->txn_rollback;
};

subtest 'Koha::RefundLostItemFeeRules::should_refund() tests' => sub {

    plan tests => 3;

    # Start transaction
    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'CheckinLibrary' );

    $schema->resultset('CirculationRule')->search()->delete;

    my $default_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => undef,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 1
            }
        }
    );
    my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
    my $specific_rule_false = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 0
            }
        }
    );
    my $branchcode2 = $builder->build( { source => 'Branch' } )->{branchcode};
    my $specific_rule_true = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode2,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
                rule_value   => 1
            }
        }
    );
    # Make sure we have an unused branchcode
    my $branchcode3 = $builder->build( { source => 'Branch' } )->{branchcode};
    my $specific_rule_dummy = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branchcode3,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund',
            }
        }
    );
    my $branch_without_rule = $specific_rule_dummy->{ branchcode };
    Koha::CirculationRules
        ->search(
            {
                branchcode   => $branch_without_rule,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => 'refund'
            }
          )
        ->next
        ->delete;

    my $params = {
        current_branch => $specific_rule_true->{ branchcode },
        # patron_branch  => $specific_rule_false->{ branchcode },
        item_holding_branch => $branch_without_rule,
        item_home_branch => $branch_without_rule
    };

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'CheckinLibrary' );
    is( Koha::RefundLostItemFeeRules->should_refund( $params ),
          1,'Specific rule is applied (true)');

    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHomeBranch' );
    is( Koha::RefundLostItemFeeRules->should_refund( $params ),
         1,'No rule for branch, global rule applied (true)');

    # Change the default value just to try
    Koha::CirculationRules->search({ branchcode => undef, rule_name => 'refund' })->next->rule_value(0)->store;
    t::lib::Mocks::mock_preference( 'RefundLostOnReturnControl', 'ItemHoldingBranch' );
    is( Koha::RefundLostItemFeeRules->should_refund( $params ),
         0,'No rule for branch, global rule applied (false)');

    # Rollback transaction
    $schema->storage->txn_rollback;
};

