"use strict";

/* global __, __x, Koha, fetch, is_valid_date, MSG_PLEASE_ENTER_A_VALID_DATE, get_dateformat_str */

import _ from "lodash";
import React from "react";
import ReactDOM from "react-dom";

import { DropDown } from "./common";
import { RULE_KINDS } from "./core";
import rules from "./rules";

const RULE_DEBOUNCE_MS = 200;

export function focusCell( cell, scrollTo = false ) {
    let cellInput = cell.querySelector( "input, select" );
    cellInput.focus();

    if ( scrollTo ) {
        // Get the cell in view (for horizontal scrolling), get the table itself all the way in
        // view, then fudge a bit for the floating toolbar.
        cell.scrollIntoView( true, { block: "start", inline: "nearest", behavior: "smooth" } );
        let tableTop = $( cell ).closest( 'table' )[0].offsetTop;
        ( document.scrollingElement || document.documentElement || document.body ).scrollTop = tableTop - document.querySelector("#toolbar").clientHeight * 2;
    }

    if ( cellInput.nodeName == "INPUT" && cellInput.type == "text" ) {
        cellInput.setSelectionRange( 0, cellInput.value.length );
    }
}

export default class RuleCell extends React.Component {
    constructor(props) {
        super(props);

        this.state = { toFocus: false };
        this.debounceTimeout = null;
    }

    shouldComponentUpdate( nextProps, nextState ) {
        const { ruleProperties: { branchcode, categorycode = "", itemtype = "", rule_name } } = nextProps;
        if ( nextProps != this.props || nextState != this.state ) return true;

        return rules.isChangedRule( { branchcode, categorycode, itemtype, rule_name } );
    }

    render() {
        const { ruleProperties: { branchcode, categorycode = "", itemtype = "", rule_name }, onChangeRule, onFocusRule } = this.props;

        let rule = rules.lookup( {
            branchcode,
            categorycode,
            itemtype,
            rule_name
        } ) || {};
        let kindInfo = RULE_KINDS[rule_name];
        let kindChoices = kindInfo.choices ? kindInfo.choices : null;
        let kindDescriptions = kindInfo.choices ? _.fromPairs(kindInfo.choices) : {};

        let onInheritedClick = ( e ) => {
            let defaultValue = "";

            if ( rule.rule_value ) {
                defaultValue = rule.rule_value;
            } else if ( kindInfo.choices ) {
                defaultValue = kindInfo.choices[0][0];
            }

            onChangeRule( { branchcode, categorycode, itemtype, rule_name, rule_value: defaultValue } );
            this.setState( { toFocus: true } );

            e.preventDefault();
        };

        let onInputChange = ( value ) => {
            if ( value === rule.rule_value ) return;

            onChangeRule( { branchcode, categorycode, itemtype, rule_name, rule_value: value } );
        };

        let onUnsetClick = ( e ) => {
            onChangeRule( { branchcode, categorycode, itemtype, rule_name, rule_value: null } );

            e.preventDefault();
        };

        let checkInput = () => {
            if ( kindInfo.type == "date" ) {
                if ( !is_valid_date( this.input.value ) ) {
                    this.input.setCustomValidity( MSG_PLEASE_ENTER_A_VALID_DATE.format( get_dateformat_str( Koha.Preferences.dateformat ) ) );
                } else {
                    this.input.setCustomValidity( "" );
                }
            }

            return !( this.input.validity.patternMismatch || this.input.validity.customError );
        };

        let onKeyDown = ( e ) => {
            if ( e.key == "Enter" ) {
                if ( checkInput() ) {
                    onInputChange( this.input.value );
                }
                e.preventDefault();
            }
        };

        let onChange = () => {
            if ( this.debounceTimeout ) {
                clearTimeout( this.debounceTimeout );
            }

            this.debounceTimeout = setTimeout( () => {
                if ( checkInput() ) {
                    onInputChange( this.input.value );
                }
            }, RULE_DEBOUNCE_MS );
        };

        let isBuiltInDefaultRule = ( rule ) => ( rule.branchcode === null && rule.categorycode === null && rule.itemtype === null );

        let renderRulePath = ( rule ) => {
            let result = [];

            if ( isBuiltInDefaultRule( rule ) ) {
                return __("Built-in default value");
            }

            for ( let part of RULE_KINDS[ rule.rule_name ].scope ) {
                switch ( part ) {
                    case "branchcode":
                        result.push(
                            rule.branchcode == "" ?
                                __("Library defaults") :
                                ( "\u201c" + Koha.BRANCHES[ rule.branchcode ].branchname + "\u201d" )
                        );
                        break;

                    case "categorycode":
                        result.push(
                            rule.categorycode == "" ?
                                __("Category defaults") :
                                ( "\u201c" + Koha.PATRON_CATEGORIES[ rule.categorycode ].description + "\u201d" )
                        );
                        break;

                    case "itemtype":
                        result.push(
                            rule.itemtype == "" ?
                                __("Item type defaults") :
                                ( "\u201c" + Koha.ITEM_TYPES[ rule.itemtype ].translated_description + "\u201d" )
                        );
                        break;
                }
            }

            return result.join( " \u203a " );
        };

        let contents, tools;

        if ( branchcode === rule.branchcode && categorycode === rule.categorycode && itemtype === rule.itemtype ) {
            // The rule we found is actually defined for the given combination
            if ( kindChoices ) {
                contents = <DropDown
                    ref={ input => this.input = input }
                    choices={kindChoices}
                    value={rule.rule_value}
                    onChange={onInputChange}
                />;
            } else {
                let pattern;

                switch ( kindInfo.type ) {
                    case "amount":
                        pattern = String.raw`\d+`;
                        break;

                    case "currency":
                        pattern = String.raw`\d+|\d*\.\d+?`;
                        break;
                }

                contents = <input
                    type={ kindInfo.type == "amount" ? "number" : "text" }
                    min={ kindInfo.type == "amount" ? 0 : null }
                    ref={ input => this.input = input }
                    defaultValue={rule.rule_value}
                    pattern={pattern}
                    onBlur={ e => {
                        if ( checkInput() ) {
                            onInputChange( this.input.value );
                        }

                        e.preventDefault();
                    } }
                    onChange={onChange}
                    onKeyDown={onKeyDown}
                />;
            }
            tools = <div className="rule-tools">
                <a href="#" title={__("Unset this rule")} onClick={onUnsetClick}><i className="fa fa-remove"></i></a>
            </div>;
        } else {
            let value = rule.rule_value;

            if ( rule.rule_value == null ) {
                value = __("Unset");
            } else if ( kindChoices && kindDescriptions[rule.rule_value] ) {
                value = kindDescriptions[rule.rule_value];
            } else if ( isBuiltInDefaultRule( rule ) && RULE_KINDS[rule_name].defaultText ) {
                value = RULE_KINDS[rule_name].defaultText;
            }

            let inheritedRuleID = `rule-${rule.branchcode}-${rule.categorycode}-${rule.itemtype}-${rule_name}`;
            contents = <span className="inherited-rule">{value}</span>;
            tools = <div className="rule-tools">
                <a href="#" title={__("Define this rule")} onClick={onInheritedClick}><i className="fa fa-pencil"></i></a>
                {rule.rule_value != null && <a
                    onClick={ ( e ) => {
                        if ( !isBuiltInDefaultRule( rule ) ) {
                            onFocusRule( rule, inheritedRuleID );
                        }

                        e.preventDefault();
                    } }
                    href={ "#" + inheritedRuleID }
                    title={ __x( "Set by: {path}", {
                        path: renderRulePath( rule )
                    } ) }>
                    <i className="fa fa-question"></i>
                </a>}
            </div>;
        }

        return <div
            className={"policy-rule" + (
                (
                    rules.isChangedRule( { branchcode, categorycode, itemtype, rule_name } ) ||
                    rules.isChangedRule( rule )
                ) ? " changed-rule" : "" )
            }
            id={`rule-${branchcode}-${categorycode}-${itemtype}-${rule_name}`}
        >
            {contents}
            {tools}
        </div>;
    }

    componentDidUpdate() {
        if ( this.state.toFocus && this.input ) {
            focusCell( ReactDOM.findDOMNode( this ) );
            this.setState( { toFocus: false } );
        }
    }
}
