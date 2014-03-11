define( [ 'widget' ], function( Widget ) {
    function _setIndicators( editor, ind1, ind2 ) {
        var info = editor.getLineInfo( editor.cm.getCursor() );
        if (!info || !info.subfields) return false;

        var cur = editor.cm.getCursor();

        var indicators = [ ind1 || info.contents.substring(4, 5) || '_', ind2 || info.contents.substring(6, 7) || '_' ];

        editor.cm.replaceRange(
            info.tagNumber + ' ' + indicators.join(' ') + ' ' + info.contents.substring(8),
            { line: cur.line, ch: 0 },
            { line: cur.line },
            'marcAware'
        );

        return true;
    }

    var _commandGenerators = [
        [ /^copy field data$/i, function() {
            return function( editor, state ) {
                var info = editor.getLineInfo( editor.cm.getCursor() );
                if (!info) return false;

                if (info.subfields) {
                    state.clipboard = info.contents.substring(4);
                } else {
                    state.clipboard = info.contents.substring(8);
                }
            };
        } ],
        [ /^copy subfield data$/i, function() {
            return function( editor, state ) {
                var info = editor.getLineInfo( editor.cm.getCursor() );
                if (!info) return false;

                var cur = editor.cm.getCursor();

                if (info.subfields) {
                    for (var i = 0; i < info.subfields.length; i++) {
                        var end = i == info.subfields.length - 1 ? info.contents.length : info.subfields[i+1].ch;
                        if (cur.ch > end) continue;

                        state.clipboard = info.contents.substring(info.subfields[i].ch + 3, end);
                        return;
                    }
                }

                return false;
            }
        } ],
        [ /^delete field$/i, function() {
            return function( editor, state ) {
                var cur = editor.cm.getCursor();

                editor.cm.replaceRange( "", { line: cur.line, ch: 0 }, { line: cur.line + 1, ch: 0 }, 'marcAware' );
            }
        } ],
        [ /^goto field end$/i, function() {
            return function( editor, state ) {
                editor.cm.setCursor( { line: editor.cm.lastLine() } );
            }
        } ],
        [ /^goto field (\w{3})$/i, function(field) {
            var matcher = new RegExp('^' + field + ' ');
            return function( editor, state ) {
                for ( var line = 0, contents; (contents = editor.cm.getLine(line)); line++ ) {
                    if ( matcher.exec( contents ) ) {
                        editor.cm.setCursor( { line: line, ch: 0 } );
                        return;
                    }
                }

                return false;
            }
        } ],
        [ /^goto subfield end$/i, function() {
            return function( editor, state ) {
                var cur = editor.cm.getCursor();

                editor.cm.setCursor( { line: cur.line } );
            }
        } ],
        [ /^goto subfield (\w)$/i, function( code ) {
            return function( editor, state ) {
                var info = editor.getLineInfo( editor.cm.getCursor() );
                if (!info || !info.subfields) return false;

                var cur = editor.cm.getCursor();

                for (var i = 0; i < info.subfields.length; i++) {
                    if ( info.subfields[i].code != code ) continue;

                    var end = i == info.subfields.length - 1 ? info.contents.length : info.subfields[i+1].ch;
                    editor.cm.setCursor( { line: cur.line, ch: end } );
                    return;
                }

                return false;
            }
        } ],
        [ /^insert (new )?field (\w{3}) data=(.*)/i, function(undef, field, data) {
            var new_contents = field + ( field < '100' ? ' ' : ' _ _ ' ) + data.replace(/\\([0-9a-z])/g, '$$$1 ');
            return function( editor, state ) {
                var line, contents;

                for ( line = 0; (contents = editor.cm.getLine(line)); line++ ) {
                    if ( contents && contents[0] > field[0] ) break;
                }

                if ( line > editor.cm.lastLine() ) {
                    new_contents = '\n' + new_contents;
                } else {
                    new_contents = new_contents + '\n';
                }

                editor.cm.replaceRange( new_contents, { line: line, ch: 0 }, null, 'marcAware' );
                editor.cm.setCursor( { line: line, ch: 0 } );
            }
        } ],
        [ /^insert (new )?subfield (\w) data=(.*)/i, function(undef, subfield, data) {
            return function( editor, state ) {
                editor.cm.replaceRange( '$' + subfield + ' ' + data, { line: editor.cm.getCursor().line }, null, 'marcAware' );
            }
        } ],
        [ /^paste$/i, function() {
            return function( editor, state ) {
                var cur = editor.cm.getCursor();

                editor.cm.replaceRange( state.clipboard, cur, null, 'marcAware' );
            }
        } ],
        [ /^set indicator([12])=([ _0-9])$/i, function( ind, value ) {
            return function( editor, state ) {
                return ind == '1' ? _setIndicators( editor, ind1, null ) : _setIndicators( editor, null, ind2 );
            }
        } ],
        [ /^set indicators=([ _0-9])([ _0-9])$/i, function( ind1, ind2 ) {
            return function( editor, state ) {
                return _setIndicators( editor, ind1, ind2 );
            }
        } ],
    ];

    var Macros = {
        Compile: function( macro ) {
            var result = { commands: [], errors: [] };

            $.each( macro.split(/\r\n|\n/), function( line, contents ) {
                var command;

                if ( contents.match(/^\s*$/) ) return;

                $.each( _commandGenerators, function( undef, gen ) {
                    var match;

                    if ( !( match = gen[0].exec( contents ) ) ) return;

                    command = gen[1].apply(null, match.slice(1));
                    return false;
                } );

                if ( !command ) {
                    result.errors.push( { line: line, error: 'unrecognized' } );
                }

                result.commands.push( { func: command, orig: contents, line: line } );
            } );

            return result;
        },
        Run: function( editor, macro ) {
            var compiled = Macros.Compile(macro);
            if ( compiled.errors.length ) return { errors: compiled.errors };
            var state = {
                clipboard: '',
            };

            var result = { errors: [] };

            editor.cm.operation( function() {
                $.each( compiled.commands, function( undef, command ) {
                    if ( command.func( editor, state ) === false ) {
                        result.errors.push( { line: command.line, error: 'failed' } );
                        return false;
                    }
                } );
            } );

            return result;
        },
    };

    return Macros;
} );
