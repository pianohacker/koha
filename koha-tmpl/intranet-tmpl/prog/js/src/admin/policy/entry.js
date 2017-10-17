"use strict";

/* global __ */

import React from "react";
import ReactDOM from "react-dom";

import PromisePolyfill from "promise-polyfill";
if ( !window.Promise ) window.Promise = PromisePolyfill;

// This polyfill installs itself
import "whatwg-fetch";

import { load } from "./core";
import PolicyApp from "./app";
import rules from "./rules";

window.addEventListener( "beforeunload", ( e ) => {
    // NOTE: This string is not shown in most browsers; its exact contents aren't critical.
    if ( rules.hasChangedRules() ) e.returnValue = __("Unsaved changes to rules, please save before closing the page");
} );

load().then( () => {
    ReactDOM.render(
        <PolicyApp />,
        document.getElementById( "react-base" )
    );
} );
