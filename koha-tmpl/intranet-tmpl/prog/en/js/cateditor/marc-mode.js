/**
 * Textual MARC mode for CodeMirror.
 * Copyright (c) 2013 ByWater
 */

// Expected format: 245 _ 1 $a Pizza |c 34ars

CodeMirror.defineMode( 'marc', function() {
    var result = {
        startState: function( prevState ) {
            var state = prevState || {};

            state.indicatorNeeded = false;
            state.subAllowed = true;
            state.subfieldCode = undefined;
            state.tagNumber = undefined;

            return state;
        },
        token: function( stream, state ) {
            var match;
            if ( stream.sol() ) {
                this.startState( state );
                if ( match = stream.match( /[0-9]+/ ) ) {
                    match = match[0];
                    if ( match.length != 3 ) {
                        if ( stream.eol() && match.length < 3 ) {
                            return 'tagnumber';
                        } else {
                            stream.skipToEnd();
                            return 'error';
                        }
                    }

                    state.tagNumber = parseInt( match );
                    if ( state.tagNumber < 10 ) {
                        // Control field
                        state.subAllowed = false;
                    }

                    return 'tagnumber';
                } else {
                    stream.skipToEnd();
                    return 'error';
                }
            }

            if ( stream.eol() ) {
                return;
            }

            if ( stream.pos < 8 && state.subAllowed ) {
                switch ( stream.pos ) {
                    case 3:
                    case 5:
                    case 7:
                        if ( stream.next() == ' ' ) {
                            return;
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
                if ( stream.match( /[^$|ǂ]+/ ) ) return;

                if ( stream.eat( /[$|ǂ]/ ) ) {
                    var subfieldCode;
                    if ( ( subfieldCode = stream.eat( /[a-z0-9]/ ) ) && ( stream.eol() || stream.eat( ' ' ) ) ) {
                        state.subfieldCode = subfieldCode;
                        return 'subfieldcode';
                    }
                }
            } else {
                stream.skipToEnd();
            }
        }
    };
    console.log( result.token );
    return result;
} );
