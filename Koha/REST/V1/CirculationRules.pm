package Koha::REST::V1::CirculationRules;

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

use Mojo::Base 'Mojolicious::Controller';

use C4::Auth;
use C4::Context;

use Koha::CirculationRules;
use Koha::Database;
use Koha::Exceptions::Authorization;

use Try::Tiny;

sub get_kinds {
    my $c = shift->openapi->valid_input or return;

    return $c->render(
        status => 200,
        openapi => Koha::CirculationRules->rule_kinds,
    );
}

sub get_rules {
    my $c = shift->openapi->valid_input or return;

    return $c->render(
        status => 200,
        openapi => [ Koha::CirculationRules->search ],
    );
}

sub save_rules {
    my $c = shift->openapi->valid_input or return;

    my $schema = Koha::Database->new->schema;

    my $uid = $c->stash( 'koha.user' )->userid;
    my $restricted_to_library = $uid && haspermission( $uid, { parameters => 'manage_circ_rules_restricted' }, { no_inherit => 1 } ) ? $c->stash( 'koha.user' )->branchcode : "";

    return try {
        my $rules = $c->req->json;

        $schema->storage->txn_do( sub {
            foreach my $rule ( @$rules ) {
                if ( $restricted_to_library && ( !$rule->{branchcode} || $rule->{branchcode} ne $restricted_to_library ) ) {
                    Koha::Exceptions::Authorization::Restricted->throw(
                        error => 'User can only modify settings for their branch.'
                    );
                }

                Koha::CirculationRules->set_rule( { %$rule, allow_null_out_of_scope => 1 } );
            }
        } );

        return $c->render( status => 200, openapi => "" );
    }
    catch {
        if ( $_->isa('Koha::Exceptions::Authorization::Restricted') ) {
            return $c->render( status  => 403,
                               openapi => { error => $_->message } );
        } else {
            warn $_;

            return $c->render( status => 500,
                openapi => { error => "Something went wrong, check the logs."} );
        }
    };

}

1;
