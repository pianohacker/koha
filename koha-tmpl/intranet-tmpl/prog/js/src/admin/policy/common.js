"use strict";

/* global __ */

import React from "react";

export class DropDown extends React.Component {
    focus() {
        this.select.focus();
    }

    render() {
        const props = this.props;

        return <select ref={ c => this.select = c } value={props.value} onChange={ e => props.onChange( e.target.value ) }>
            { props.caption && <option disabled value="">{props.caption}</option> }
            { props.allowAll && <option value="">{__("Defaults")}</option> }
            { props.choices.map( ( [ key, description ] ) => <option key={key} value={key}>{description}</option> ) }
        </select>;
    }
}

export class GroupedDropDown extends React.Component {
    focus() {
        this.select.focus();
    }

    render() {
        const props = this.props;

        return <select ref={ c => this.select = c } value={props.value} onChange={ e => props.onChange( e.target.value ) }>
            { props.caption && <option disabled value="">{props.caption}</option> }
            { props.choices.map( ( [ groupName, choices ] ) => <optgroup label={groupName} key={groupName}>
                { choices.map( ( [ key, description ] ) => <option key={key} value={key}>{description}</option> ) }
            </optgroup> ) }
        </select>;
    }
}
