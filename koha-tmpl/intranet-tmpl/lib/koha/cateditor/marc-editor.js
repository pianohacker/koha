define( [ 'marc-record', 'koha-backend', 'text-marc', 'widget-utils' ], function( MARC, KohaBackend, TextMARC, Widget ) {
    function editorCursorActivity( editor ) {
        if ( state.saving ) return;

        $('#status-tag-info').empty();
        $('#status-subfield-info').empty();

        var info = Widget.GetLineInfo( editor, editor.getCursor() );

        if ( !info.tagNumber ) return; // No tag at all on this line

        var taginfo = KohaBackend.GetTagInfo( '', info.tagNumber );
        $('#status-tag-info').html( '<strong>' + info.tagNumber + ':</strong> ' );

        if ( taginfo ) {
            $('#status-tag-info').append( taginfo.lib );

            if ( !info.currentSubfield ) return; // No current subfield

            var subfieldinfo = taginfo.subfields[info.currentSubfield];
            $('#status-subfield-info').html( '<strong>$' + info.currentSubfield + ':</strong> ' );

            if ( subfieldinfo ) {
                $('#status-subfield-info').append( subfieldinfo.lib );
            } else {
                $('#status-subfield-info').append( '<em>' + _("Unknown subfield") + '</em>' );
            }
        } else {
            $('#status-tag-info').append( '<em>' + _("Unknown tag") + '</em>' );
        }
    }

    function editorBeforeChange( editor, change ) {
        if ( state.saving || change.origin == 'marcAware' ) return;

        // FIXME: Should only cancel changes if this is a control field/subfield widget
        if ( change.from.line !== change.to.line || Math.abs( change.from.ch - change.to.ch ) > 1 || change.text.length != 1 || change.text[0].length != 0 ) return; // Not single-char change

        if ( change.from.ch == change.to.ch - 1 && editor.findMarksAt( { line: change.from.line, ch: change.from.ch + 1 } ).length ) {
            change.cancel();
        } else if ( change.from.ch == change.to.ch && editor.findMarksAt(change.from).length && !change.text[0].match(/^[$|ǂ‡]$/) ) {
            change.cancel();
        }
    }

    function editorChange( editor, change ) {
        if ( state.saving ) return;

        var updatedLines = {};
        do {
            var from = change.from;
            var to = change.to;
            if ( to.line < from.line || to.ch < from.ch ) {
                var temp = from;
                from = to;
                to = temp;
            }

            var startLine, endLine;
            if ( change.text.length == 2 && from.line == to.line && from.ch == to.ch) {
                if ( from.ch == 0 ) {
                    startLine = endLine = from.line;
                } else if ( from.ch == editor.getLine(from.line).length ){
                    startLine = endLine = from.line + 1;
                }
            } else {
                startLine = (from.ch == editor.getLine(from.line).length && from.line < to.line) ? Math.min(editor.lastLine(), from.line + 1) : from.line;
                endLine = ((to.ch == 0 && from.line < to.line) ? Math.max(to.line - 1, 0) : to.line) + change.text.length - 1;
            }

            for ( var line = startLine; line <= endLine; line++ ) {
                if ( updatedLines[line] ) continue;

                if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( editor, line );
                if ( change.origin != 'setValue' && change.origin != 'marcWidgetPrefill' ) editor.addLineClass( line, 'wrapper', 'modified-line' );
                updatedLines[line] = true;
            }
        } while ( change = change.next )

        Widget.ActivateAt( editor, editor.getCursor() );
    }

    // Editor helper functions
    function activateTabPosition( editor, cur, idx ) {
        editor.setCursor( cur );
        Widget.ActivateAt( editor, cur, idx );
    }

    function getTabPositions( editor, cur ) {
        var info = Widget.GetLineInfo( editor, cur || editor.getCursor() );

        if ( info.tagNumber ) {
            if ( info.subfields ) {
                var positions = [ 0, 4, 6 ];

                $.each( info.subfields, function( undef, subfield ) {
                    positions.push( subfield.ch + 3 );
                } );

                return positions;
            } else {
                return [ 0, 4 ];
            }
        } else {
            return [];
        }
    }

    var editorKeys = {
        Enter: function( editor ) {
            var cursor = editor.getCursor();
            editor.replaceRange( '\n', { line: cursor.line }, null, 'marcAware' );
            editor.setCursor( { line: cursor.line + 1, ch: 0 } );
        },

        'Shift-Enter': function( editor ) {
            var cursor = editor.getCursor();
            editor.replaceRange( '\n', { line: cursor.line, ch: 0 }, null, 'marcAware' );
            editor.setCursor( { line: cursor.line, ch: 0 } );
        },

        'Ctrl-X': function( editor ) {
            // Delete line (or cut)
            if ( editor.somethingSelected() ) return true;
            var cur = editor.getCursor();

            editor.replaceRange( "", { line: cur.line, ch: 0 }, { line: cur.line + 1, ch: 0 }, 'marcAware' );
        },

        Tab: function( editor ) {
            // Move through parts of tag/fixed fields
            var positions = getTabPositions( editor );
            var cur = editor.getCursor();
            var done = false;

            for ( var i = 0; i < positions.length; i++ ) {
                if ( positions[i] > cur.ch ) {
                    activateTabPosition( editor, { line: cur.line, ch: positions[i] } );
                    done = true;
                    return false;
                }
            }

            editor.setCursor( { line: cur.line + 1, ch: 0 } );
        },

        'Shift-Tab': function( editor ) {
            // Move backwards through parts of tag/fixed fields
            var positions = getTabPositions( editor );
            var cur = editor.getCursor();
            var done = false;

            for ( var i = positions.length - 1; i >= 0; i-- ) {
                if ( positions[i] < cur.ch ) {
                    activateTabPosition( editor, { line: cur.line, ch: positions[i] } );
                    done = true;
                    return false;
                }
            }

            if ( cur.line == 0 ) return;

            var prevPositions = getTabPositions( editor, { line: cur.line - 1, ch: editor.getLine( cur.line - 1 ).length } );

            if ( prevPositions.length ) {
                activateTabPosition( editor, { line: cur.line - 1, ch: prevPositions[ prevPositions.length - 1 ] }, -1 );
            } else {
                editor.setCursor( { line: cur.line - 1, ch: 0 } );
            }
        },
    };

    function MARCEditor( position ) {
        this.cm = CodeMirror(
            position,
            {
                extraKeys: _editorKeys,
                gutters: [
                    'modified-line-gutter',
                ],
                lineWrapping: true,
                mode: {
                    name: 'marc',
                    nonRepeatableTags: KohaBackend.GetTagsBy( '', 'repeatable', '0' ),
                    nonRepeatableSubfields: KohaBackend.GetSubfieldsBy( '', 'repeatable', '0' )
                }
            }
        );
        this.cm.marceditor = this;

        this.cm.on( 'beforeChange', editorBeforeChange );
        this.cm.on( 'change', editorChange );
        this.cm.on( 'cursorActivity', editorCursorActivity );
    }

    MARCEditor.prototype.addError = function( line, error ) {
        var found = false;
        var options = {};

        if ( line == null ) {
            line = 0;
            options.above = true;
        }

        $.each( this.cm.getLineHandle(line).widgets || [], function( undef, widget ) {
            if ( !widget.isErrorMarker ) return;

            found = true;

            $( widget.node ).append( '; ' + error );
            widget.changed();

            return false;
        } );

        if ( found ) return;

        var node = $( '<div class="structure-error"><i class="icon-remove"></i> ' + error + '</div>' )[0];
        var widget = this.cm.addLineWidget( line, node, options );

        widget.node = node;
        widget.isErrorMarker = true;
    },

    MARCEditor.prototype.removeErrors: function() {
        for ( var line = 0; line < this.cm.lineCount(); line++ ) {
            $.each( this.cm.getLineHandle( line ).widgets || [], function( undef, lineWidget ) {
                if ( lineWidget.isErrorMarker ) lineWidget.clear();
            } );
        }
    },

    return MARCEditor;
} );
