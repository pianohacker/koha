"use strict";

/* global __, Koha, fetch, $, humanMsg */

import _ from "lodash";
import React from "react";

import { DropDown } from "./common";
import rules from "./rules";
import { focusCell } from "./rule-cell";
import { BranchRuleEditor } from "./rule-editors";

function RuleGroupSelector( { group: selectedGroup, onChangeGroup } ) {
    let renderButton = ( group, className="btn-default", text = group ) => {
        return <button
            type="button"
            className={ "btn " + ( selectedGroup == group ? "active " : "" ) + className }
            onClick={ () => { onChangeGroup( group ); } }>
            <i className={ "fa " + ( selectedGroup == group ? "fa-check-circle-o" : "fa-circle-o" ) } />
            {" " + text}
        </button>;
    };

    return <div id="toolbar-right" className="btn-group">
        { renderButton( null, "btn-primary", __("Show all rules") ) }
        { renderButton(__("Circulation")) }
        { renderButton(__("Fines")) }
        { renderButton(__("Holds")) }
    </div>;
}

class PolicyAppToolbar extends React.Component {
    constructor( props ) {
        super( props );

        this.state = {
            selectedBranch: props.branch,
        };
    }

    render() {
        let selectedBranch = this.props.branch == "*" ? this.state.selectedBranch : this.props.branch;
        let hasChanges= rules.hasChangedRules();

        return <div id="toolbar" className="btn-toolbar" ref={ el => { this.toolbarElem = el; } }>
            <div id="toolbar-left">
                <button className="btn btn-success save-all" type="submit" disabled={ !hasChanges } onClick={this.props.onSaveClick}><i className="fa fa-save" /> {__("Save rules")}</button>
                <button className="btn btn-default" type="button" onClick={this.props.onCleanupClick}><i className="fa fa-clone" /> {__("Cleanup rules")}</button>
            </div>
            { window.restricted_to_library ? <div id="toolbar-center"></div> : <div id="toolbar-center">
                <label>
                    {__("Select a library: ")}
                    <DropDown
                        value={selectedBranch}
                        choices={
                            [ [ "", "Defaults for all libraries" ] ].concat(
                                _( Object.keys( Koha.BRANCHES ) )
                                    .map( branchcode => [ branchcode, Koha.BRANCHES[ branchcode ].branchname ] )
                                    .sortBy( 1 )
                                    .value()
                            )
                        }
                        onChange={ branch => {
                            this.setState( { selectedBranch: branch } );
                            this.props.onChange( branch );
                        } }
                    />
                </label>
                <label className="show-all">
                    <input type="checkbox" checked={ this.props.branch == "*" } onChange={ e => this.props.onChange( e.target.checked ? "*" : this.state.selectedBranch ) } />
                    {__("Show all")}
                </label>
            </div> }
            <RuleGroupSelector group={this.props.group} onChangeGroup={this.props.onChangeGroup} />
        </div>;
    }

    componentDidMount() {
        $( this.toolbarElem ).fixFloat();
    }
}

export default class PolicyApp extends React.Component {
    constructor( props ) {
        super( props );

        this.state = {
            branch: window.restricted_to_library || "",
            kindGroup: null,
        };
    }

    onSaveClick() {
        fetch( "/api/v1/circulation-rules", {
            method: "POST",
            credentials: "include",
            body: JSON.stringify( rules.pullChangedRules() ),
        } ).then( response => {
            switch( response.status ) {
                case 200:
                    rules.clearChangedRules();
                    humanMsg.displayMsg( __("<h3>Rules saved.</h3>"), { className: "humanSuccess" } );
                    this.forceUpdate();
                    break;

                case 401:
                    humanMsg.displayAlert( __("<h3>Rules not saved</h3><p>Please reload the page to log in again</p>"), { className: "humanError" } );
                    break;

                default:
                    humanMsg.displayAlert( __("<h3>Rules not saved</h3><p>Internal error</p>"), { className: "humanError" } );
                    break;
            }
        } );
    }

    onCleanupClick() {
        if ( !confirm( __("This will remove any redundant rules (ones that are set to the default value).\n\nThis should not change any circulation behavior, but you will be able to review these changes before saving.") ) ) {
            return;
        }

        for ( let rule of rules.getAllDefined( {} ) ) {
            let defaultRule = {};

            // We are trying to find any default rules, ignoring any scopes that we're already a
            // default rule for.
            //
            // If we have found a default rule besides the built-in default, the scope will be
            // something besides null.

            if ( rule.itemtype != "" && defaultRule.itemtype == null ) {
                defaultRule = rules.lookup( {
                    branchcode: rule.branchcode,
                    categorycode: rule.categorycode,
                    itemtype: null,
                    rule_name: rule.rule_name,
                } );
            }

            if ( rule.categorycode != "" && defaultRule.categorycode == null ) {
                defaultRule = rules.lookup( {
                    branchcode: rule.branchcode,
                    categorycode: null,
                    itemtype: rule.itemtype,
                    rule_name: rule.rule_name,
                } );
            }

            if ( rule.branchcode != "" && defaultRule.branchcode == null ) {
                defaultRule = rules.lookup( {
                    branchcode: null,
                    categorycode: rule.categorycode,
                    itemtype: rule.itemtype,
                    rule_name: rule.rule_name,
                } );
            }

            if ( rule.rule_value == defaultRule.rule_value ) {
                rules.unset( {
                    branchcode: rule.branchcode,
                    categorycode: rule.categorycode,
                    itemtype: rule.itemtype,
                    rule_name: rule.rule_name,
                } );
            }
        }

        this.forceUpdate();
    }

    render() {
        let onChangeRule = ( rule ) => {
            if ( rule.rule_value === null ) {
                rules.unset( rule );
            } else {
                rules.set( rule );
            }
            this.forceUpdate();
        };

        let onFocusRule = ( rule, inheritedRuleID ) => {
            let callback = () => {
                focusCell( document.getElementById( inheritedRuleID ), true );
            };

            if ( this.state.branch == "*" || rule.branchcode == this.state.branch ) {
                callback();
            } else {
                this.setState( { branch: rule.branchcode }, callback );
            }
        };

        let branchEditors;

        if ( this.state.branch == "*" ) {
            branchEditors = [ <BranchRuleEditor branch={null} key="" onChangeRule={onChangeRule} /> ].concat(
                Object.keys( Koha.BRANCHES ).map( branchcode => <BranchRuleEditor
                    key={branchcode}
                    branch={Koha.BRANCHES[ branchcode ]}
                    onChangeRule={onChangeRule}
                    onFocusRule={onFocusRule}
                /> )
            );
        } else {
            branchEditors = <BranchRuleEditor
                branch={this.state.branch ? Koha.BRANCHES[ this.state.branch ] : null}
                kindGroup={this.state.kindGroup}
                key={this.state.branch}
                onChangeRule={onChangeRule}
                onFocusRule={onFocusRule}
            />;
        }

        return <section>
            <h1>{__( "Circulation, fine and hold policy" )}</h1>
            <PolicyAppToolbar
                branch={this.state.branch}
                group={this.state.kindGroup}
                onChange={ branch => this.setState( { branch } ) }
                onChangeGroup={ group => this.setState( { kindGroup: group } ) }
                onSaveClick={ () => { this.onSaveClick(); } }
                onCleanupClick={ () => { this.onCleanupClick(); } }
            />
            {branchEditors}
        </section>;
    }
}
