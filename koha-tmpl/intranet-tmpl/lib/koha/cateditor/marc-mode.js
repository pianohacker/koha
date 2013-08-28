/**
 * Textual MARC mode for CodeMirror.
 * Copyright (c) 2013 ByWater
 */

// Expected format: 245 _ 1 $a Pizza |c 34ars

CodeMirror.defineMode( 'marc', function( config, modeConfig ) {
    modeConfig.nonRepeatableTags = modeConfig.nonRepeatableTags || {};
    modeConfig.nonRepeatableSubfields = modeConfig.nonRepeatableSubfields || {};

    return {
        startState: function( prevState ) {
            var state = prevState || {};

            if ( !prevState ) {
                state.seenTags = {};
            }

            state.indicatorNeeded = false;
            state.subAllowed = true;
            state.subfieldCode = undefined;
            state.tagNumber = undefined;
            state.seenSubfields = {};

            return state;
        },
        copyState: function( prevState ) {
            var result = $.extend( {}, prevState );
            result.seenTags = $.extend( {}, prevState.seenTags );
            result.seenSubfields = $.extend( {}, prevState.seenSubfields );

            return result;
        },
        token: function( stream, state ) {
            var match;
            if ( stream.sol() ) {
                this.startState( state );
                if ( match = stream.match( /[0-9A-Za-z]+/ ) ) {
                    match = match[0];
                    if ( match.length != 3 ) {
                        if ( stream.eol() && match.length < 3 ) {
                            // Don't show error for incomplete number
                            return 'tagnumber';
                        } else {
                            stream.skipToEnd();
                            return 'error';
                        }
                    }

                    state.tagNumber = match;
                    if ( state.tagNumber < '010' ) {
                        // Control field
                        state.subAllowed = false;
                    }

                    if ( state.seenTags[state.tagNumber] && modeConfig.nonRepeatableTags[state.tagNumber] ) {
                        return 'bad-tagnumber';
                    } else {
                        state.seenTags[state.tagNumber] = true;
                        return 'tagnumber';
                    }
                } else {
                    stream.skipToEnd();
                    return 'error';
                }
            }

            if ( stream.eol() ) {
                return;
            }

            if ( !state.subAllowed && stream.pos == 3 ) {
                if ( stream.next() == ' ' ) {
                    return 'reqspace';
                } else {
                    stream.skipToEnd();
                    return 'error';
                }
            }

            if ( stream.pos < 8 && state.subAllowed ) {
                switch ( stream.pos ) {
                    case 3:
                    case 5:
                    case 7:
                        if ( stream.next() == ' ' ) {
                            return 'reqspace';
                        } else {
                            stream.skipToEnd();
                            return 'error';
                        }
                    case 4:
                    case 6:
                        if ( /[0-9A-Za-z_]/.test( stream.next() ) ) {
                            return 'indicator';
                        } else {
                            stream.skipToEnd();
                            return 'error';
                        }
                }
            }

            if ( state.subAllowed ) {
                if ( stream.pos != 8 && stream.match( /[^$|ǂ‡]+/ ) ) return;

                if ( stream.eat( /[$|ǂ‡]/ ) ) {
                    var subfieldCode;
                    if ( ( subfieldCode = stream.eat( /[a-z0-9%]/ ) ) && stream.eat( ' ' ) ) {
                        state.subfieldCode = subfieldCode;
                        if ( state.seenSubfields[state.subfieldCode] && ( modeConfig.nonRepeatableSubfields[state.tagNumber] || {} )[state.subfieldCode] ) {
                            return 'bad-subfieldcode';
                        } else {
                            state.seenSubfields[state.subfieldCode] = true;
                            return 'subfieldcode';
                        }
                    }
                }

                if ( stream.pos < 11 && ( !stream.eol() || stream.pos == 8 ) ) {
                    stream.skipToEnd();
                    return 'error';
                }
            } else {
                stream.skipToEnd();
            }
        }
    };
} );
