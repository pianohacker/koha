define( [ 'marc-record', 'koha-backend', 'preferences', 'text-marc', 'widget' ], function( MARC, KohaBackend, Preferences, TextMARC, Widget ) {
    var NOTIFY_TIMEOUT = 250;

    function editorCursorActivity( cm ) {
        var editor = cm.marceditor;
        if ( editor.textMode ) return;

        $('#status-tag-info').empty();
        $('#status-subfield-info').empty();

        var info = editor.getLineInfo( cm.getCursor() );

        if ( !info ) return; // No tag at all on this line

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
        var editor = cm.marceditor;
        if ( editor.textMode || change.origin == 'marcAware' ) return;

        // FIXME: Should only cancel changes if this is a control field/subfield widget
        if ( change.from.line !== change.to.line || Math.abs( change.from.ch - change.to.ch ) > 1 || change.text.length != 1 || change.text[0].length != 0 ) return; // Not single-char change

        if ( change.from.ch == change.to.ch - 1 && cm.findMarksAt( { line: change.from.line, ch: change.from.ch + 1 } ).length ) {
            change.cancel();
        } else if ( change.from.ch == change.to.ch && cm.findMarksAt(change.from).length && !change.text[0].match(/^[$|ǂ‡]$/) ) {
            change.cancel();
        }
    }

    function editorChange( cm, change ) {
        var editor = cm.marceditor;
        if ( editor.textMode ) return;

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

                if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( cm.marceditor, line );
                if ( change.origin != 'setValue' && change.origin != 'marcWidgetPrefill' ) cm.addLineClass( line, 'wrapper', 'modified-line' );
                updatedLines[line] = true;
            }
        } while ( change = change.next )

        Widget.ActivateAt( cm, cm.getCursor() );
        cm.marceditor.startNotify();
    }

    // Editor helper functions
    function activateTabPosition( cm, cur, idx ) {
        cm.setCursor( cur );
        Widget.ActivateAt( cm, cur, idx );
    }

    function getTabPositions( editor, cur ) {
        var info = editor.getLineInfo( cur || editor.cm.getCursor() );

        if ( info ) {
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
            // Delete subfield (or cut)
            if ( cm.somethingSelected() ) return true;

            var cur = cm.getCursor();
            var info = cm.marceditor.getLineInfo( cur );
            if ( !info || !info.subfields ) return true;

            for (var i = 0; i < info.subfields.length; i++) {
                var end = i == info.subfields.length - 1 ? info.contents.length : info.subfields[i+1].ch;
                if (cur.ch > end) continue;

                cm.replaceRange( "", { line: cur.line, ch: info.subfields[i].ch }, { line: cur.line, ch: end }, 'marcAware' );
                return;
            }
        },

        'Shift-Ctrl-X': function( cm ) {
            // Delete line
            var cur = cm.getCursor();

            cm.replaceRange( "", { line: cur.line, ch: 0 }, { line: cur.line + 1, ch: 0 }, 'marcAware' );
        },

        Tab: function( cm ) {
            // Move through parts of tag/fixed fields
            var positions = getTabPositions( cm.marceditor );
            var cur = cm.getCursor();

            for ( var i = 0; i < positions.length; i++ ) {
                if ( positions[i] > cur.ch ) {
                    activateTabPosition( cm, { line: cur.line, ch: positions[i] } );
                    return false;
                }
            }

            cm.setCursor( { line: cur.line + 1, ch: 0 } );
        },

        'Shift-Tab': function( cm ) {
            // Move backwards through parts of tag/fixed fields
            var positions = getTabPositions( cm.marceditor );
            var cur = cm.getCursor();

            for ( var i = positions.length - 1; i >= 0; i-- ) {
                if ( positions[i] < cur.ch ) {
                    activateTabPosition( cm, { line: cur.line, ch: positions[i] } );
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

        this.subscribers = [];
        this.subscribe( function( marceditor ) {
            Widget.Notify( marceditor );
        } );
    }

    MARCEditor.prototype.setUseWidgets = function( val ) {
        if ( val ) {
            for ( var line = 0; line <= this.cm.lastLine(); line++ ) {
                Widget.UpdateLine( this, line );
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
            if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( this, line );
        }

        this.textMode = false;

        return record;
    };

    MARCEditor.prototype.getLineInfo = function( pos ) {
        var contents = this.cm.getLine( pos.line );
        if ( contents == null ) return {};

        var tagNumber = contents.match( /^([A-Za-z0-9]{3}) / );

        if ( !tagNumber ) return null; // No tag at all on this line
        tagNumber = tagNumber[1];

        if ( tagNumber < '010' ) return { tagNumber: tagNumber, contents: contents }; // No current subfield

        var matcher = /[$|ǂ‡]([a-z0-9%]) /g;
        var match;

        var subfields = [];
        var currentSubfield;

        while ( ( match = matcher.exec(contents) ) ) {
            subfields.push( { code: match[1], ch: match.index } );
            if ( match.index < pos.ch ) currentSubfield = match[1];
        }

        return { tagNumber: tagNumber, subfields: subfields, currentSubfield: currentSubfield, contents: contents };
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

    MARCEditor.prototype.getFixedField = function(field) {
        field += ' ';
        for ( var line = 0; line < this.cm.lineCount(); line++ ) {
            var contents = this.cm.getLine(line);
            if ( contents.substr( 0, 4 ) != field ) continue;

            var marks = this.cm.findMarksAt( { line: line, ch: 4 } );
            if ( marks[0] && marks[0].widget ) {
                return marks[0].widget.text;
            } else {
                return contents.substr(4);
            }
        }

        return null;
    };

    MARCEditor.prototype.startNotify = function() {
        if ( this.notifyTimeout ) clearTimeout( this.notifyTimeout );
        this.notifyTimeout = setTimeout( $.proxy( function() {
            this.notifyAll();

            this.notifyTimeout = null;
        }, this ), NOTIFY_TIMEOUT );
    };

    MARCEditor.prototype.notifyAll = function() {
        $.each( this.subscribers, $.proxy( function( undef, subscriber ) {
            subscriber(this);
        }, this ) );
    };

    MARCEditor.prototype.subscribe = function( subscriber ) {
        this.subscribers.push( subscriber );
    };

    return MARCEditor;
} );
