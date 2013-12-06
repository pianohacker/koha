define( [ 'marc-record', 'koha-backend', 'preferences', 'text-marc', 'widget-utils' ], function( MARC, KohaBackend, Preferences, TextMARC, Widget ) {
    function editorCursorActivity( cm ) {
        if ( this.textMode ) return;

        $('#status-tag-info').empty();
        $('#status-subfield-info').empty();

        var info = Widget.GetLineInfo( cm, cm.getCursor() );

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

    function editorBeforeChange( cm, change ) {
        if ( this.textMode || change.origin == 'marcAware' ) return;

        // FIXME: Should only cancel changes if this is a control field/subfield widget
        if ( change.from.line !== change.to.line || Math.abs( change.from.ch - change.to.ch ) > 1 || change.text.length != 1 || change.text[0].length != 0 ) return; // Not single-char change

        if ( change.from.ch == change.to.ch - 1 && cm.findMarksAt( { line: change.from.line, ch: change.from.ch + 1 } ).length ) {
            change.cancel();
        } else if ( change.from.ch == change.to.ch && cm.findMarksAt(change.from).length && !change.text[0].match(/^[$|ǂ‡]$/) ) {
            change.cancel();
        }
    }

    function editorChange( cm, change ) {
        if ( this.textMode ) return;

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
                } else if ( from.ch == cm.getLine(from.line).length ){
                    startLine = endLine = from.line + 1;
                }
            } else {
                startLine = (from.ch == cm.getLine(from.line).length && from.line < to.line) ? Math.min(cm.lastLine(), from.line + 1) : from.line;
                endLine = ((to.ch == 0 && from.line < to.line) ? Math.max(to.line - 1, 0) : to.line) + change.text.length - 1;
            }

            for ( var line = startLine; line <= endLine; line++ ) {
                if ( updatedLines[line] ) continue;

                if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( cm, line );
                if ( change.origin != 'setValue' && change.origin != 'marcWidgetPrefill' ) cm.addLineClass( line, 'wrapper', 'modified-line' );
                updatedLines[line] = true;
            }
        } while ( change = change.next )

        Widget.ActivateAt( cm, cm.getCursor() );
    }

    // Editor helper functions
    function activateTabPosition( cm, cur, idx ) {
        cm.setCursor( cur );
        Widget.ActivateAt( cm, cur, idx );
    }

    function getTabPositions( cm, cur ) {
        var info = Widget.GetLineInfo( cm, cur || cm.getCursor() );

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

    var _editorKeys = {
        Enter: function( cm ) {
            var cursor = cm.getCursor();
            cm.replaceRange( '\n', { line: cursor.line }, null, 'marcAware' );
            cm.setCursor( { line: cursor.line + 1, ch: 0 } );
        },

        'Shift-Enter': function( cm ) {
            var cursor = cm.getCursor();
            cm.replaceRange( '\n', { line: cursor.line, ch: 0 }, null, 'marcAware' );
            cm.setCursor( { line: cursor.line, ch: 0 } );
        },

        'Ctrl-X': function( cm ) {
            // Delete line (or cut)
            if ( cm.somethingSelected() ) return true;
            var cur = cm.getCursor();

            cm.replaceRange( "", { line: cur.line, ch: 0 }, { line: cur.line + 1, ch: 0 }, 'marcAware' );
        },

        Tab: function( cm ) {
            // Move through parts of tag/fixed fields
            var positions = getTabPositions( cm );
            var cur = cm.getCursor();
            var done = false;

            for ( var i = 0; i < positions.length; i++ ) {
                if ( positions[i] > cur.ch ) {
                    activateTabPosition( cm, { line: cur.line, ch: positions[i] } );
                    done = true;
                    return false;
                }
            }

            cm.setCursor( { line: cur.line + 1, ch: 0 } );
        },

        'Shift-Tab': function( cm ) {
            // Move backwards through parts of tag/fixed fields
            var positions = getTabPositions( cm );
            var cur = cm.getCursor();
            var done = false;

            for ( var i = positions.length - 1; i >= 0; i-- ) {
                if ( positions[i] < cur.ch ) {
                    activateTabPosition( cm, { line: cur.line, ch: positions[i] } );
                    done = true;
                    return false;
                }
            }

            if ( cur.line == 0 ) return;

            var prevPositions = getTabPositions( cm, { line: cur.line - 1, ch: cm.getLine( cur.line - 1 ).length } );

            if ( prevPositions.length ) {
                activateTabPosition( cm, { line: cur.line - 1, ch: prevPositions[ prevPositions.length - 1 ] }, -1 );
            } else {
                cm.setCursor( { line: cur.line - 1, ch: 0 } );
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

    MARCEditor.prototype.setUseWidgets = function( val ) {
        if ( val ) {
            for ( var line = 0; line <= this.cm.lastLine(); line++ ) {
                Widget.UpdateLine( this.cm, line );
            }
        } else {
            $.each( this.cm.getAllMarks(), function( undef, mark ) {
                if ( mark.widget ) mark.widget.clearToText();
            } );
        }
    };

    MARCEditor.prototype.focus = function() {
        this.cm.focus();
    };

    MARCEditor.prototype.refresh = function() {
        this.cm.refresh();
    };

    MARCEditor.prototype.displayRecord = function( record ) {
        this.cm.setValue( TextMARC.RecordToText(record) );
    };

    MARCEditor.prototype.getRecord = function() {
        this.textMode = true;

        $.each( this.cm.getAllMarks(), function( undef, mark ) {
            if ( mark.widget ) mark.widget.clearToText();
        } );
        var record = TextMARC.TextToRecord( this.cm.getValue() );
        for ( var line = 0; line <= this.cm.lastLine(); line++ ) {
            if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( this.cm, line );
        }

        this.textMode = false;

        return record;
    };

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
    };

    MARCEditor.prototype.removeErrors = function() {
        for ( var line = 0; line < this.cm.lineCount(); line++ ) {
            $.each( this.cm.getLineHandle( line ).widgets || [], function( undef, lineWidget ) {
                if ( lineWidget.isErrorMarker ) lineWidget.clear();
            } );
        }
    };

    return MARCEditor;
} );
