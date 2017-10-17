"use strict";

/* global __, fetch */

import _ from "lodash";
import rules from "./rules";

const RULE_DISPLAY_INFO = {
    refund: {
        description: __("Refund lost item fee"),
        group: __("Fines"),
        choices: [
            [ 0, __("No") ],
            [ 1, __("Yes") ],
        ],
        showByDefault: true,
    },

    patron_maxissueqty: {
        description: __("Total current checkouts allowed"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("Unlimited"),
        showByDefault: true,
    },
    patron_maxonsiteissueqty: {
        description: __("Total current on-site checkouts allowed"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("Unlimited"),
        showByDefault: true,
    },
    max_holds: {
        description: __("Maximum total holds allowed"),
        group: __("Holds"),
        type: "amount",
        defaultText: __("Unlimited"),
        showByDefault: true,
    },

    holdallowed: {
        description: __("Hold policy"),
        group: __("Holds"),
        choices: [
            [ 2, __("From any library") ],
            [ 1, __("From home library") ],
            [ 0, __("No holds allowed") ],
        ],
        showByDefault: true,
    },
    hold_fulfillment_policy: {
        description: __("Hold pickup library match"),
        group: __("Holds"),
        choices: [
            [ "any", __("any library") ],
            [ "homebranch", __("item's home library") ],
            [ "holdingbranch", __("item's holding library") ],
        ],
        showByDefault: true,
    },
    returnbranch: {
        description: __("Return policy"),
        group: __("Circulation"),
        choices: [
            [ "homebranch", __("Item returns home") ],
            [ "holdingbranch", __("Item returns to issuing library") ],
            [ "noreturn", __("Item floats") ],
        ],
        showByDefault: true,
    },

    article_requests: {
        description: __("Article requests"),
        group: __("Circulation"),
        choices: [
            [ "no", __("No") ],
            [ "yes", __("Yes") ],
            [ "bib_only", __("Record only") ],
            [ "item_only", __("Item only") ],
        ],
    },
    auto_renew: {
        description: __("Automatic renewal"),
        group: __("Circulation"),
        choices: [
            [ "no", __("No") ],
            [ "yes", __("Yes") ],
        ],
    },
    cap_fine_to_replacement_price: {
        description: __("Cap fine at replacement price"),
        group: __("Fines"),
        choices: [
            [ 0, __("No") ],
            [ 1, __("Yes") ],
        ],
    },
    chargeperiod: {
        description: __("Fine charging interval"),
        group: __("Fines"),
        type: "amount",
    },
    chargeperiod_charge_at: {
        description: __("When to charge"),
        group: __("Circulation"),
        choices: [
            [ 0, __("End of interval") ],
            [ 1, __("Start of interval") ],
        ],
    },
    fine: {
        description: __("Fine amount"),
        group: __("Fines"),
        type: "currency",
        showByDefault: true,
    },
    finedays: {
        description: __("Suspension in days"),
        group: __("Fines"),
        type: "amount",
    },
    firstremind: {
        description: __("Fine grace period"),
        group: __("Fines"),
        type: "amount",
        showByDefault: true,
    },
    hardduedate: {
        description: __("Hard due date"),
        group: __("Circulation"),
        type: "date",
        defaultText: __("None"),
    },
    hardduedatecompare: {
        description: __("Hard due date type"),
        group: __("Circulation"),
        choices: [
            [ -1, __("Before") ],
            [ 0, __("Exactly on") ],
            [ 1, __("After") ],
        ],
    },
    holds_per_record: {
        description: __("Holds per record (count)"),
        group: __("Holds"),
        type: "amount",
    },
    issuelength: {
        description: __("Loan period"),
        group: __("Circulation"),
        type: "amount",
        showByDefault: true,
    },
    lengthunit: {
        description: __("Loan period unit"),
        group: __("Circulation"),
        choices: [
            [ "days", __("Days") ],
            [ "hours", __("Hours") ],
        ],
        showByDefault: true,
    },
    maxissueqty: {
        description: __("Current checkouts allowed"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("Unlimited"),
        showByDefault: true,
    },
    maxonsiteissueqty: {
        description: __("Current on-site checkouts allowed"),
        group: __("Circulation"),
        defaultText: __("Unlimited"),
        type: "amount",
    },
    maxsuspensiondays: {
        description: __("Max. suspension duration (days)"),
        group: __("Fines"),
        defaultText: __("Unlimited"),
        type: "amount",
    },
    no_auto_renewal_after: {
        description: __("No automatic renewal after"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("Unset"),
    },
    no_auto_renewal_after_hard_limit: {
        description: __("No automatic renewal after (hard limit)"),
        group: __("Circulation"),
        type: "date",
        defaultText: __("Unset"),
    },
    norenewalbefore: {
        description: __("No renewal before"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("Unset"),
    },
    onshelfholds: {
        description: __("On shelf holds allowed"),
        group: __("Holds"),
        choices: [
            [ 1, __("Yes") ],
            [ 0, __("If any unavailable") ],
            [ 2, __("If all unavailable") ],
        ],
    },
    opacitemholds: {
        description: __("Item-level holds"),
        group: __("Holds"),
        choices: [
            [ "N", __("Don't allow") ],
            [ "Y", __("Allow") ],
            [ "F", __("Force") ],
        ],
    },
    overduefinescap: {
        description: __("Overdue fines cap (amount)"),
        group: __("Fines"),
        type: "currency",
        defaultText: __("Unlimited"),
    },
    renewalperiod: {
        description: __("Renewal period"),
        group: __("Circulation"),
        type: "amount",
    },
    renewalsallowed: {
        description: __("Renewals allowed (count)"),
        group: __("Circulation"),
        type: "amount",
        defaultText: __("None"),
    },
    rentaldiscount: {
        description: __("Rental discount (%)"),
        group: __("Circulation"),
        type: "percent",
        defaultText: __("None"),
    },
    reservesallowed: {
        description: __("Holds allowed (count)"),
        group: __("Holds"),
        type: "amount",
        defaultText: __("None"),
    },
    // Not included (deprecated?):
    //   * accountsent
    //   * chargename
    //   * reservecharge
    //   * restrictedtype
};

export var RULE_KINDS = {}, KINDS_BY_SCOPE = {};

export function load() {
    return Promise.all( [
        fetch( "/api/v1/circulation-rules/kinds" ).then( result => result.json() ).then( result => {
            _.merge( RULE_KINDS, RULE_DISPLAY_INFO, result );
            for ( let [ name, kind ] of Object.entries( RULE_KINDS ) ) {
                // Display _something_ sensible for unknown rule kinds.
                if ( !kind.description ) kind.description = name;
            }

            KINDS_BY_SCOPE = _( RULE_KINDS )
                .map( ( kind, name ) => Object.assign( kind, { name, scope_name: kind.scope.join( "_" ) } ) )
                .groupBy( kind => kind.scope_name )
                .value();
        } ),
        fetch( "/api/v1/circulation-rules" ).then( result => result.json() ).then( result => {
            rules.load( result );
        } ),
    ] );
}
