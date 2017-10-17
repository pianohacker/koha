"use strict";

/* global __, Koha, fetch */

import _ from "lodash";
import React from "react";

import { DropDown, GroupedDropDown } from "./common";
import { RULE_KINDS, KINDS_BY_SCOPE } from "./core";
import rules from "./rules";
import RuleCell from "./rule-cell";

function AllHiddenHeader() {
    return <th className="all-hidden" title={__("All rules are currently hidden; to see them, change your filter in the toolbar.")}>
        {__("All rules hidden")}
    </th>;
}

class RuleEditor extends React.Component {
    constructor( props ) {
        super( props );

        this.state = {
            visibleChoices: _.union( [ "" ], _.sortBy( this._configuredChoices, choice => this._allChoices[choice] ) ),
            visibleKinds: _.uniq(
                KINDS_BY_SCOPE[this.scopeName]
                    .filter( kind => kind.showByDefault )
                    .map( kind => kind.name )
                    .concat( this._ownRules.map( rule => rule.rule_name ) )
            ),
        };
    }

    get branchcode() {
        return this.props.branch ? this.props.branch.branchcode : "";
    }

    get categorycode() {
        // We have to handle both the case where there's never a categorycode and where the category
        // is unset (default rules).
        if ( this.props.category === null ) {
            return "";
        } else if ( this.props.category === undefined ) {
            return undefined;
        } else {
            return this.props.category.categorycode;
        }
    }

    get _ownRules() {
        return rules.getAllDefined( { branchcode: this.branchcode, categorycode: this.categorycode, scope_name: this.scopeName } );
    }

    addChoice( choice ) {
        this.setState( {
            visibleChoices: this.state.visibleChoices.concat( [ choice ] ),
        } );
    }

    addRuleName( choice ) {
        this.setState( {
            visibleKinds: this.state.visibleKinds.concat( [ choice ] ),
        } );
    }

    render() {
        const { props, state } = this;
        let choices = this._allChoices;
        let availableChoices = _( choices )
            .filter( ( [ choice ] ) => !state.visibleChoices.includes( choice ) )
            .sortBy( 1 )
            .value();
        let choiceDescriptions = _.fromPairs( choices );
        let visibleChoices = _.sortBy( state.visibleChoices, choice => choice ? choiceDescriptions[choice] : "" );

        let allKinds = KINDS_BY_SCOPE[this.scopeName];
        let allKindNames = allKinds.map( rule => rule.name );
        let kindGroups = _( allKindNames )
            .difference( state.visibleKinds )
            .map( rule_name => [ rule_name, RULE_KINDS[rule_name].description ] )
            .sortBy( 1 )
            .groupBy( ( [ rule_name ] ) => RULE_KINDS[rule_name].group )
            .value();

        let kindChoices = _( props.kindGroup ? { [props.kindGroup]: kindGroups[props.kindGroup] } : kindGroups )
            .toPairs()
            .sortBy( 0 )
            .value();

        if ( kindChoices.length && kindChoices[0][1] == undefined ) kindChoices = null;

        let visibleKinds = state.visibleKinds.filter( rule_name => !props.kindGroup || RULE_KINDS[rule_name].group == props.kindGroup );

        return <table className="table">
            { props.caption && <caption>{props.caption}</caption> }
            <thead>
                <tr>
                    <th>&nbsp;</th>
                    { !visibleKinds.length ? <AllHiddenHeader /> : visibleKinds.map( rule_name =>
                        <th key={rule_name}>{ RULE_KINDS[rule_name].description }</th>
                    ) }
                    { _.isEmpty( kindChoices ) || <th className="add-rule">
                        <GroupedDropDown
                            caption={__("Choose rule...")}
                            value=""
                            choices={ kindChoices }
                            onChange={ choice => this.addRuleName(choice) }
                        />
                    </th> }
                </tr>
            </thead>
            <tbody>
                { visibleChoices.map( choice => <tr key={choice}>
                    <th scope="row" className={ choice == "" ? "default" : "" }>{ choice ? choiceDescriptions[choice] : __("Defaults") }</th>
                    { visibleKinds.map( rule_name => <td key={rule_name}>
                        <RuleCell
                            key={rule_name}
                            ruleProperties={{
                                branchcode: this.branchcode,
                                categorycode: props.category ? props.category.categorycode : undefined,
                                [this.ruleKey]: choice,
                                rule_name
                            }}
                            onChangeRule={props.onChangeRule}
                            onFocusRule={props.onFocusRule}
                        />
                   </td> ) }
                </tr> ) }
                { _.isEmpty( availableChoices ) || <tr>
                    <th scope="row">
                        <DropDown
                            caption={this._dropDownCaption}
                            value=""
                            choices={availableChoices}
                            onChange={ choice => this.addChoice(choice) }
                        />
                    </th>
                </tr> }
            </tbody>
        </table>;
    }
}

export class CategoryRuleEditor extends RuleEditor {
    get scopeName() { return "branchcode_categorycode"; }
    get ruleKey() { return "categorycode"; }
    get _dropDownCaption() { return __("Choose category..."); }

    get _allChoices() {
        return Object.keys( Koha.PATRON_CATEGORIES ).map( categorycode => [ categorycode, Koha.PATRON_CATEGORIES[categorycode].description ] );
    }

    get _configuredChoices() {
        return _.uniq( this._ownRules.map( rule => rule.categorycode ) );
    }
}

// This has to be slightly differently set up than the CategoryRuleEditor, because it's used for
// both branch/itemtype and branch/category/itemtype rules.
export class ItemTypeRuleEditor extends RuleEditor {
    static get defaultProps() {
        return { scopeName: "branchcode_itemtype" };
    }

    get scopeName() { return this.props.scopeName; }
    get ruleKey() { return "itemtype"; }
    get _dropDownCaption() { return __("Choose item type..."); }

    get _allChoices() {
        return Object.keys( Koha.ITEM_TYPES ).map( itemtype => [ itemtype, Koha.ITEM_TYPES[itemtype].translated_description ] );
    }

    get _configuredChoices() {
        return _.uniq( this._ownRules.map( rule => rule.itemtype ) );
    }
}

export class CategoryItemTypeRuleEditor extends React.Component {
    get branchname() {
        return this.props.branch ? this.props.branch.branchname : null;
    }

    render() {
        const props = this.props;
        var defaults = props.category == null;

        return <section className={ "category-rules" + ( defaults ? " category-default-rules" : "" ) }>
            <h4>{ defaults ? __("Defaults for all categories") : props.category.description }</h4>
            <div className="table-scroll-wrapper">
                <ItemTypeRuleEditor
                    branch={props.branch}
                    kindGroup={props.kindGroup}
                    category={props.category}
                    scopeName="branchcode_categorycode_itemtype"
                    onChangeRule={props.onChangeRule}
                    onFocusRule={props.onFocusRule}
                />
            </div>
        </section>;
    }
}

function BranchGlobalRuleEditor( { branch, kindGroup, onChangeRule, onFocusRule } ) {
    let allKinds = KINDS_BY_SCOPE["branchcode"];
    let allKindNames = allKinds.filter( rule => !kindGroup || RULE_KINDS[ rule.name ].group == kindGroup ).map( rule => rule.name );

    return <table className="table">
        <thead>
            <tr>
                { !allKindNames.length ? <AllHiddenHeader /> : allKindNames.map( rule_name =>
                    <th key={rule_name}>{ RULE_KINDS[rule_name].description }</th>
                ) }
            </tr>
        </thead>
        <tbody>
            <tr>
                { allKindNames.map( rule_name => <td key={rule_name}>
                    <RuleCell
                        key={rule_name}
                        ruleProperties={{
                            branchcode: branch ? branch.branchcode : "",
                            rule_name
                        }}
                        onChangeRule={onChangeRule}
                        onFocusRule={onFocusRule}
                    />
                </td> ) }
            </tr>
        </tbody>
    </table>;
}

export class BranchRuleEditor extends React.Component {
    constructor( props ) {
        super( props );
        this.state = {
            visibleCategories: _.union( [ "" ], _.uniq( rules.getAllDefined( { branchcode: this.branchcode, scope_name: "branchcode_categorycode_itemtype" } ) ).map( rule => rule.categorycode ) ),
        };
    }

    get branchcode() {
        return this.props.branch ? this.props.branch.branchcode : "";
    }

    addCategory( choice ) {
        this.setState( {
            visibleCategories: this.state.visibleCategories.concat( [ choice ] ),
        } );
    }

    render() {
        const { props, state } = this;
        var defaults = props.branch == null;

        let allCategories = Object.keys( Koha.PATRON_CATEGORIES ).map( categorycode => [ categorycode, Koha.PATRON_CATEGORIES[categorycode].description ] );
        let availableCategories = _( allCategories )
            .filter( ( [ categorycode ] ) => !state.visibleCategories.includes( categorycode ) )
            .sortBy( 1 )
            .value();
        let categoryDescriptions = _.fromPairs( allCategories );
        let visibleCategories = _.sortBy( state.visibleCategories, category => category ? categoryDescriptions[category] : "" );

        return <section className={ "branch-rules" + ( defaults ? " default-rules" : "" ) }>
            <h2>{ defaults ? __( "Defaults for all libraries" ) : props.branch.branchname }</h2>
            <h3>{__( "Rules only by library" )}</h3>
            <BranchGlobalRuleEditor
                branch={props.branch}
                kindGroup={props.kindGroup}
                onChangeRule={props.onChangeRule}
                onFocusRule={props.onFocusRule}
            />
            <CategoryRuleEditor
                caption={__( "Rules by category" )}
                branch={props.branch}
                kindGroup={props.kindGroup}
                onChangeRule={props.onChangeRule}
                onFocusRule={props.onFocusRule}
            />
            <ItemTypeRuleEditor
                caption={__( "Rules by item type" )}
                branch={props.branch}
                kindGroup={props.kindGroup}
                onChangeRule={props.onChangeRule}
                onFocusRule={props.onFocusRule}
            />
            <h3>{__( "Rules by category and item type" )}</h3>
            { visibleCategories.map( categorycode =>
                <CategoryItemTypeRuleEditor
                    key={categorycode}
                    branch={props.branch}
                    kindGroup={props.kindGroup}
                    category={categorycode ? Koha.PATRON_CATEGORIES[categorycode] : null}
                    onChangeRule={props.onChangeRule}
                    onFocusRule={props.onFocusRule}
                />
            ) }
            {_.isEmpty( availableCategories ) ||
            <h4>
                <DropDown
                    caption={__("Define item-type rules for category...")}
                    value=""
                    choices={ availableCategories }
                    onChange={ choice => this.addCategory(choice) }
                />
            </h4> }
        </section>;
    }
}
