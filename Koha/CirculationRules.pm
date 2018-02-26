package Koha::CirculationRules;

# Copyright ByWater Solutions 2017
#
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

use Carp qw(croak);

use Koha::CirculationRule;

use base qw(Koha::Objects);

=head1 NAME

Koha::CirculationRules - Koha CirculationRule Object set class

=head1 API

=head2 Class Methods

=cut

=head3 rule_kinds

This structure describes the possible rules that may be set, and what scopes they can be set at.

Any attempt to set a rule with a nonsensical scope (for instance, setting the C<patron_maxissueqty> for a branchcode and itemtype), is an error.

=cut

our $RULE_KINDS = {
    refund => {
        scope => [ 'branchcode' ],
    },

    patron_maxissueqty => {
        scope => [ 'branchcode', 'categorycode' ],
    },
    patron_maxonsiteissueqty => {
        scope => [ 'branchcode', 'categorycode' ],
    },
    max_holds => {
        scope => [ 'branchcode', 'categorycode' ],
    },

    holdallowed => {
        scope => [ 'branchcode', 'itemtype' ],
    },
    hold_fulfillment_policy => {
        scope => [ 'branchcode', 'itemtype' ],
    },
    returnbranch => {
        scope => [ 'branchcode', 'itemtype' ],
    },

    article_requests => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    auto_renew => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    cap_fine_to_replacement_price => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    chargeperiod => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    chargeperiod_charge_at => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    fine => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    finedays => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    firstremind => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    hardduedate => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    hardduedatecompare => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    holds_per_record => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    issuelength => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    lengthunit => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxissueqty => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxonsiteissueqty => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxsuspensiondays => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    no_auto_renewal_after => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    no_auto_renewal_after_hard_limit => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    norenewalbefore => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    onshelfholds => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    opacitemholds => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    overduefinescap => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    renewalperiod => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    renewalsallowed => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    rentaldiscount => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    reservesallowed => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    # Not included (deprecated?):
    #   * accountsent
    #   * chargename
    #   * reservecharge
    #   * restrictedtype
};

sub rule_kinds {
    return $RULE_KINDS;
}

=head3 get_effective_rule

=cut

sub get_effective_rule {
    my ( $self, $params ) = @_;

    $params->{categorycode} //= undef;
    $params->{branchcode}   //= undef;
    $params->{itemtype}     //= undef;

    my $rule_name    = $params->{rule_name};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $branchcode   = $params->{branchcode};

    my $order_by = $params->{order_by}
      // { -desc => [ 'branchcode', 'categorycode', 'itemtype' ] };

    croak q{No rule name passed in!} unless $rule_name;

    my $search_params;
    $search_params->{rule_name} = $rule_name;

    $search_params->{categorycode} = defined $categorycode ? [ $categorycode, undef ] : undef;
    $search_params->{itemtype}     = defined $itemtype     ? [ $itemtype,     undef ] : undef;
    $search_params->{branchcode}   = defined $branchcode   ? [ $branchcode,   undef ] : undef;

    my $rule = $self->search(
        $search_params,
        {
            order_by => $order_by,
            rows => 1,
        }
    )->single;

    return $rule;
}

=head3 get_effective_rule

=cut

sub get_effective_rules {
    my ( $self, $params ) = @_;

    my $rules        = $params->{rules};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $branchcode   = $params->{branchcode};

    my $r;
    foreach my $rule (@$rules) {
        my $effective_rule = $self->get_effective_rule(
            {
                rule_name    => $rule,
                categorycode => $categorycode,
                itemtype     => $itemtype,
                branchcode   => $branchcode,
            }
        );

        $r->{$rule} = $effective_rule->rule_value if $effective_rule;
    }

    return $r;
}

=head3 set_rule

=cut

sub set_rule {
    my ( $self, $params ) = @_;

    croak q{set_rule requires the parameter 'rule_name'!}
        unless exists $params->{rule_name};
    croak q{set_rule requires the parameter 'rule_value'!}
        unless exists $params->{rule_value};

    my $kind_info = $RULE_KINDS->{ $params->{rule_name} };
    croak "set_rule given unknown rule '$params->{rule_name}'!"
        unless defined $kind_info;

    # Enforce scope; a rule should be set for its defined scope, no more, no less.
    foreach my $scope_level ( qw( branchcode categorycode itemtype ) ) {
        if ( grep /$scope_level/, @{ $kind_info->{scope} } ) {
            croak "set_rule needs '$scope_level' to set '$params->{rule_name}'!"
                unless exists $params->{$scope_level};
        } else {
            croak "set_rule cannot set '$params->{rule_name}' for a '$scope_level'!"
                if exists $params->{$scope_level};
        }
    }

    my $branchcode   = $params->{branchcode};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $rule_name    = $params->{rule_name};
    my $rule_value   = $params->{rule_value};

    my $rule = $self->search(
        {
            rule_name    => $rule_name,
            branchcode   => $branchcode,
            categorycode => $categorycode,
            itemtype     => $itemtype,
        }
    )->next();

    if ($rule) {
        if ( defined $rule_value ) {
            $rule->rule_value($rule_value);
            $rule->update();
        }
        else {
            $rule->delete();
        }
    }
    else {
        if ( defined $rule_value ) {
            $rule = Koha::CirculationRule->new(
                {
                    branchcode   => $branchcode,
                    categorycode => $categorycode,
                    itemtype     => $itemtype,
                    rule_name    => $rule_name,
                    rule_value   => $rule_value,
                }
            );
            $rule->store();
        }
    }

    return $rule;
}

=head3 set_rules

=cut

sub set_rules {
    my ( $self, $params ) = @_;

    my %set_params;
    $set_params{branchcode} = $params->{branchcode} if exists $params->{branchcode};
    $set_params{categorycode} = $params->{categorycode} if exists $params->{categorycode};
    $set_params{itemtype} = $params->{itemtype} if exists $params->{itemtype};
    my $rules        = $params->{rules};

    my $rule_objects = [];
    while ( my ( $rule_name, $rule_value ) = each %$rules ) {
        my $rule_object = Koha::CirculationRules->set_rule(
            {
                %set_params,
                rule_name    => $rule_name,
                rule_value   => $rule_value,
            }
        );
        push( @$rule_objects, $rule_object );
    }

    return $rule_objects;
}

=head3 get_onshelfholds_policy

    my $on_shelf_holds = Koha::CirculationRules->get_onshelfholds_policy({ item => $item, patron => $patron });

=cut

sub get_onshelfholds_policy {
    my ( $class, $params ) = @_;
    my $item = $params->{item};
    my $itemtype = $item->effective_itemtype;
    my $patron = $params->{patron};
    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            categorycode => ( $patron ? $patron->categorycode : undef ),
            itemtype     => $itemtype,
            branchcode   => $item->holdingbranch,
            rule_name    => 'onshelfholds',
        }
    );
    return $rule ? $rule->rule_value : undef;
}

=head3 type

=cut

sub _type {
    return 'CirculationRule';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::CirculationRule';
}

1;
