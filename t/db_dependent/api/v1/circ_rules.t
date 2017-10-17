#!/usr/bin/env perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Test::More tests => 5;
use Test::Deep qw( cmp_deeply set superhashof );
use Test::Mojo;
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Auth;
use Koha::Acquisition::Booksellers;
use Koha::CirculationRules;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# FIXME: sessionStorage defaults to mysql, but it seems to break transaction handling
# this affects the other REST api tests
t::lib::Mocks::mock_preference( 'SessionStorage', 'tmp' );

my $remote_address = '127.0.0.1';
my $t              = Test::Mojo->new('Koha::REST::V1');

sub tx_maker {
    my $args = shift;

    my ( $borrowernumber, $session_id ) = create_user_and_session( $args );

    return sub {
        my $tx = shift->ua->build_tx( @_ );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
        $tx->req->env( { REMOTE_ADDR => $remote_address } );

        return $tx;
    }
}

subtest 'rule_kinds' => sub {
    plan tests => 3;

    my $tx_maker = tx_maker( { permissions => 'authorized' } );

    my $tx = $tx_maker->( $t, GET => '/api/v1/circulation-rules/kinds' );
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is( Koha::CirculationRules->rule_kinds );
};

subtest 'get_rules' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    Koha::CirculationRules->search->delete;

    my $tx_maker = tx_maker( { permissions => 'authorized' } );

    my $tx = $tx_maker->( $t, GET => '/api/v1/circulation-rules' );
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is( [] );

    my $branchcode = $builder->build({ source => 'Branch' })->{'branchcode'};
    my @rules = (
        {
            branchcode => undef,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 10,
        },
        {
            branchcode => $branchcode,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 20,
        },
    );

    Koha::CirculationRules->set_rule( $_ ) for ( @rules );

    $tx = $tx_maker->( $t, GET => '/api/v1/circulation-rules' );
    $t->request_ok($tx)
      ->status_is(200);
    cmp_deeply( $tx->res->json, set( map { superhashof( $_ ) } @rules ), 'rules retrieved correctly' );

    $schema->storage->txn_rollback;
};

subtest 'set_rules | unauthorized' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    Koha::CirculationRules->search->delete;

    my $tx_maker = tx_maker( { permissions => 'none' } );

    my $rule = {
        branchcode => undef,
        categorycode => undef,
        itemtype => undef,
        rule_name => 'maxissueqty',
        rule_value => 10,
    };

    my $tx = $tx_maker->( $t, POST => '/api/v1/circulation-rules', json => $rule );
    $t->request_ok($tx)
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'set_rules' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    Koha::CirculationRules->search->delete;

    my $tx_maker = tx_maker( { permissions => 'authorized' } );

    my @rules = (
        {
            branchcode => undef,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 10,
        },
    );

    my $tx = $tx_maker->( $t, POST => '/api/v1/circulation-rules', json => \@rules );
    $t->request_ok($tx)
      ->status_is(200);

    my $stored_rule = Koha::CirculationRules->search( {
        branchcode => undef,
        categorycode => undef,
        itemtype => undef,
    } )->next;

    cmp_deeply(
        $stored_rule && $stored_rule->unblessed,
        superhashof( $rules[0] ),
        'rule stored correctly'
    );

    $schema->storage->txn_rollback;
};

subtest 'set_rules | restricted' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    Koha::CirculationRules->search->delete;

    my $branchcode = $builder->build({ source => 'Branch' })->{'branchcode'};
    my $other_branchcode = $builder->build({ source => 'Branch' })->{'branchcode'};
    my $tx_maker = tx_maker( { permissions => 'authorized_restricted', branchcode => $branchcode } );

    my @allowed_rules = (
        {
            branchcode => $branchcode,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 10,
        },
    );

    my @forbidden_rules = (
        {
            branchcode => undef,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 10,
        },
        {
            branchcode => $other_branchcode,
            categorycode => undef,
            itemtype => undef,
            rule_name => 'maxissueqty',
            rule_value => 20,
        },
    );

    for my $rule ( @allowed_rules ) {
        my $tx = $tx_maker->( $t, POST => '/api/v1/circulation-rules', json => [ $rule ] );
        $t->request_ok($tx)
          ->status_is(200);
    }

    for my $rule ( @forbidden_rules ) {
        my $tx = $tx_maker->( $t, POST => '/api/v1/circulation-rules', json => [ $rule ] );
        $t->request_ok($tx)
          ->status_is(403);
    }

    $schema->storage->txn_rollback;
};

sub create_user_and_session {

    my $args = shift;
    my $flags = {
        none => 0,
        # catalogue and parameters permissions
        authorized => (1 << 2) | (1 << 3),
        # Just catalogue
        authorized_restricted => (1 << 2),
    }->{ $args->{permissions} || ( $args->{authorized} ? 'authorized' : 'none' ) };

    my %branch_flags;
    $branch_flags{branchcode} = $args->{branchcode} if ( $args->{branchcode} );

    # my $flags = ( $args->{authorized} ) ? $args->{authorized} : 0;
    my $dbh = C4::Context->dbh;

    my $user = $builder->build(
        {   source => 'Borrower',
            value  => { flags => $flags, %branch_flags }
        }
    );

    # Create a session for the authorized user
    my $session = C4::Auth::get_session('');
    $session->param( 'number',   $user->{borrowernumber} );
    $session->param( 'id',       $user->{userid} );
    $session->param( 'ip',       '127.0.0.1' );
    $session->param( 'lasttime', time() );
    $session->flush;

    if ( $args->{permissions} eq 'authorized_restricted' ) {
        $dbh->do(
            q{
            INSERT INTO user_permissions (borrowernumber,module_bit,code)
            VALUES (?,3,'manage_circ_rules_restricted'), (?,3,'manage_circ_rules')},
            undef, $user->{borrowernumber}, $user->{borrowernumber}
        );
    }

    return ( $user->{borrowernumber}, $session->id );
}

1;
