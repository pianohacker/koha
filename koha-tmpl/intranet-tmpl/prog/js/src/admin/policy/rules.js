"use strict";

import _ from "lodash";

import { RULE_KINDS } from "./core";

export default ( window.rules = new class {
    constructor() {
        this.rules = {};
        this.changedRules = {};
    }

    load( ruleData ) {
        // NOTE: We use "" within the frontend, as distinguishing "null" and null gets too funky.
        for ( let { branchcode, categorycode, itemtype, rule_name, rule_value } of ruleData ) {
            this.set( {
                branchcode: branchcode || "",
                categorycode: categorycode || "",
                itemtype: itemtype || "",
                rule_name,
                rule_value
            } );
        }

        this.clearChangedRules();
    }

    // Find all the defined rules for a given set of criteria.
    getAllDefined( { branchcode, categorycode, itemtype, scope_name } ) {
        let result = [];

        for ( let ruleBranchCode of (
            branchcode === undefined ?
                Object.keys( this.rules ) :
                [ branchcode ]
        ) ) {
            if ( !this.rules[ruleBranchCode] ) continue;

            for ( let ruleCategoryCode of (
                categorycode === undefined ?
                    Object.keys( this.rules[ruleBranchCode] ) :
                    [ categorycode ]
            ) ) {
                if ( !this.rules[ruleBranchCode][ruleCategoryCode] ) continue;

                for ( let ruleItemType of (
                    itemtype === undefined ?
                        Object.keys( this.rules[ruleBranchCode][ruleCategoryCode] ) :
                        [ itemtype ]
                ) ) {

                    if ( !this.rules[ruleBranchCode][ruleCategoryCode][ruleItemType] ) continue;

                    for ( let [ rule_name, rule_value ] of Object.entries( this.rules[ruleBranchCode][ruleCategoryCode][ruleItemType] ) ) {
                        if ( scope_name !== undefined && scope_name != RULE_KINDS[rule_name].scope_name ) continue;

                        result.push( {
                            rule_name,
                            rule_value,

                            branchcode: ruleBranchCode,
                            categorycode: ruleCategoryCode,
                            itemtype: ruleItemType,
                        } );
                    }
                }
            }
        }

        return result;
    }

    lookup( { branchcode, categorycode, itemtype, rule_name } ) {
        for ( let ruleBranchCode of [ branchcode, "" ] ) {
            if ( !this.rules[ruleBranchCode] ) continue;

            for ( let ruleCategoryCode of [ categorycode, "" ] ) {
                if ( !this.rules[ruleBranchCode][ruleCategoryCode] ) continue;

                for ( let ruleItemType of [ itemtype, "" ] ) {
                    let itemTypeRules = this.rules[ruleBranchCode][ruleCategoryCode][ruleItemType];

                    if( itemTypeRules && itemTypeRules[rule_name] !== undefined ) {
                        return {
                            rule_name: rule_name,
                            rule_value: itemTypeRules[rule_name],

                            branchcode: ruleBranchCode,
                            categorycode: ruleCategoryCode,
                            itemtype: ruleItemType,
                        };
                    }
                }
            }
        }

        return {
            branchcode: null,
            categorycode: null,
            itemtype: null,

            rule_name,
            rule_value: RULE_KINDS[rule_name].default_value
        };
    }

    set( { branchcode, categorycode, itemtype, rule_name, rule_value } ) {
        _.set( this.rules, [branchcode, categorycode, itemtype, rule_name ], rule_value );
        _.set( this.changedRules, [branchcode, categorycode, itemtype, rule_name ], rule_value );
    }

    unset( { branchcode, categorycode, itemtype, rule_name } ) {
        _.unset( this.rules, [branchcode, categorycode, itemtype, rule_name ] );
        _.set( this.changedRules, [branchcode, categorycode, itemtype, rule_name ], null );
    }

    // Returns a list of changed rules (with defaults as null, per the backend).
    pullChangedRules() {
        let changedRules = [];

        for ( let [ ruleBranchCode, branchRules ] of Object.entries( this.changedRules ) ) {
            for ( let [ ruleCategoryCode, categoryRules ] of Object.entries( branchRules ) ) {
                for ( let [ ruleItemType, itemtypeRules ] of Object.entries( categoryRules ) ) {
                    for ( let [ rule_name, rule_value ] of Object.entries( itemtypeRules ) ) {
                        changedRules.push( {
                            branchcode: ruleBranchCode || null,
                            categorycode: ruleCategoryCode || null,
                            itemtype: ruleItemType || null,
                            rule_name,
                            rule_value
                        } );
                    }
                }
            }
        }

        return changedRules;
    }

    hasChangedRules() {
        return !_.isEmpty( this.changedRules );
    }

    isChangedRule( { branchcode, categorycode, itemtype, rule_name } ) {
        return _.has( this.changedRules, [branchcode, categorycode, itemtype, rule_name ] );
    }

    clearChangedRules() {
        this.changedRules = {};
    }
} );
