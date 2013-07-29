<script src="/cgi-bin/koha/svc/cateditor/framework?frameworkcode=&amp;callback=var+_preloadDefault%3D"></script>

<script src="/intranet-tmpl/lib/codemirror/codemirror.js"></script>
<script src="/intranet-tmpl/lib/koha/cateditor/marc-mode.js"></script>
<script src="/intranet-tmpl/lib/require.js"></script>
<script>
require.config( {
    baseUrl: '/intranet-tmpl/lib/koha/cateditor/'
} );
</script>

[% IF marcflavour == 'MARC21' %]
[% PROCESS 'cateditor-widgets-marc21.inc' %]
[% ELSE %]
<script>var editorWidgets = {};</script>
[% END %]

<script>
require( [ 'koha-backend', 'text-marc', 'marc-record' ], function( KohaBackend, TextMARC, MARC ) {
    KohaBackend.SetDefaultFramework( _preloadDefault.framework );

    var state = {
        backend: '',
        record_id: undefined,
        saving: false
    };

    var widgetBase = {
        // Marker utils
        clearToText: function() {
            var range = this.mark.find();
            this.mark.doc.replaceRange( this.text, range.from, range.to, 'marcAware' );
        },

        // Fixed field utils
        bindFixed: function( sel, start, end ) {
            var $node = $( this.node ).find( sel );
            $node.val( this.getFixed( start, end ) );

            $node.change( $.proxy( function() {
                this.setFixed( start, end, $node.val() );
            }, this ) );
        },

        getFixed: function( start, end ) {
            return this.text.substring( start, end );
        },

        setFixed: function( start, end, value ) {
            this.text = this.text.substring( 0, start ) + this.padString( value.toString().substr( 0, end - start ), end - start ) + this.text.substring( end );
        },

        setText: function( text ) {
            this.text = text;
        },

        // Template utils
        insertTemplate: function( sel ) {
            var wsOnly = /^\s*$/;
            $( sel ).contents().clone().each( function() {
                if ( this.nodeType == Node.TEXT_NODE ) {
                    this.data = this.data.replace( /^\s+|\s+$/g, '' );
                }
            } ).appendTo( this.node );
        },

        padNum: function( number, length ) {
            var result = number.toString();

            while ( result.length < length ) result = '0' + result;

            return result;
        },

        padString: function( result, length ) {
            while ( result.length < length ) result = ' ' + result;

            return result;
        }
    };

    function makeHiddenWidgets( frameworkCode ) {

    }

    function updateWidgets( editor, line ) {
        var info = getLineInfo( editor, { line: line, ch: 0 } );

        if ( !info.tagNumber ) {
            var lineh = editor.getLineHandle( line );

            if ( lineh.markedSpans ) {
                $.each( lineh.markedSpans, function ( _, span ) {
                    var mark = span.marker;
                    if ( !mark.widget ) return;

                    mark.widget.clearToText();
                } );
            }
            return;
        }

        var subfields = [];

        var end = editor.getLine( line ).length;
        if ( info.tagNumber < '010' ) {
            if ( end >= 4 ) subfields.push( { code: '@', preFrom: { line: line - 1 }, from: 4, to: end } );
        } else {
            for ( var i = 0; i < info.subfields.length; i++ ) {
                var next = ( i < info.subfields.length - 1 ) ? info.subfields[i + 1].ch : end;
                subfields.push( { code: info.subfields[i].code, preFrom: { line: line, ch: info.subfields[i].ch }, from: info.subfields[i].ch + 3, to: next } );
            }
        }

        $.each( subfields, function ( _, subfield ) {
            var id = info.tagNumber + subfield.code;
            var marks = editor.findMarksAt( { line: line, ch: subfield.from } );

            if ( marks.length ) {
                if ( marks[0].id == id ) {
                    return;
                } else {
                    marks[0].widget.clearToText();
                }
            }

            if ( !editorWidgets[id] ) return;
            var fullBase = $.extend( Object.create( widgetBase ), editorWidgets[id] );
            var widget = Object.create( fullBase );

            if ( subfield.from == subfield.to ) {
                editor.replaceRange( widget.makeTemplate ? widget.makeTemplate() : '<empty>', { line: line, ch: subfield.from } );
                return; // We'll do the actual work when the change event is triggered again
            }

            var text = editor.getRange( { line: line, ch: subfield.from }, { line: line, ch: subfield.to } );

            widget.text = text;
            var node = widget.init();

            if ( node ) {
                var mark = editor.markText( { line: line, ch: subfield.from }, { line: line, ch: subfield.to }, {
                    inclusiveLeft: false,
                    inclusiveRight: false,
                    replacedWith: node,
                } );
            } else {
                // Hidden field/subfield
                var mark = editor.markText( subfield.preFrom, { line: line, ch: subfield.to }, {
                    collapsed: true,
                    inclusiveLeft: false,
                    inclusiveRight: false,
                } );
                widget.text = editor.getRange( subfield.preFrom, { line: line, ch: subfield.to } );
            }

            mark.id = id;
            mark.widget = widget;

            widget.node = node;
            widget.mark = mark;

            if ( widget.postCreate ) widget.postCreate();
        } );
    }

    // Editor helper functions
    var editorKeys = {
        Enter: function( editor ) {
            var cursor = editor.getCursor();
            editor.replaceRange( '\n', { line: cursor.line }, null, 'marcAware' );
            editor.setCursor( { line: cursor.line + 1, column: 0 } );
        }
    };

    function getLineInfo( editor, pos ) {
        var contents = editor.getLine( pos.line );
        var tagNumber = contents.match( /^([A-Za-z0-9]{3}) / );

        if ( !tagNumber ) return {}; // No tag at all on this line
        tagNumber = tagNumber[1];

        if ( tagNumber < '010' ) return { tagNumber: tagNumber }; // No current subfield

        var matcher = /[$|ǂ‡]([a-z0-9%]) /g;
        var match;

        var subfields = [];
        var currentSubfield;

        while ( ( match = matcher.exec(contents) ) ) {
            subfields.push( { code: match[1], ch: match.index } );
            if ( match.index < pos.ch ) currentSubfield = match[1];
        }

        return { tagNumber: tagNumber, subfields: subfields, currentSubfield: currentSubfield };
    }

    function editorCursorActivity( editor ) {
        if ( state.saving ) return;

        $('#status-tag-info').empty();
        $('#status-subfield-info').empty();

        var info = getLineInfo( editor, editor.getCursor() );

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
        if ( change.from.line !== change.to.line || Math.abs( change.from.ch - change.to.ch ) > 1 ) return; // Not single-char change

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
            var startLine = change.from.line;
            var endLine = change.to.line;
            if ( endLine < startLine ) {
                startLine = change.to.line;
                endLine = change.start.line;
            }

            for ( var line = startLine; line <= endLine; line++ ) {
                if ( updatedLines[line] ) continue;

                updateWidgets( editor, line );
                updatedLines[line] = true;
            }
        } while ( change = change.next )
    }

    // Record loading
    var backends = {
       'new': {
            record_label: _("new record"),
            get: function( id, display_cb ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record );

                display_cb( record );
            },
        },
        'new-full': {
            record_label: _("new full record"),
            get: function( id, display_cb ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record, true );

                display_cb( record );
            },
        },
        'catalog': {
            record_label: _("catalog record #{ID}"),
            save_label: _("To catalog"),
            get: function( id, display_cb ) {
                if ( !id ) return false;

                KohaBackend.GetRecord( id, display_cb );
            },
            save: function( id, record, done ) {
                function finish_cb( data ) {
                    done( { error: data.error, newRecord: data.marcxml, newId: data.biblionumber && [ 'catalog', data.biblionumber ] } );
                }

                if ( id ) {
                    KohaBackend.SaveRecord( id, record, finish_cb );
                } else {
                    KohaBackend.CreateRecord( record, finish_cb );
                }
            }
        }
    };

    function clearRecordInfo( name, value ) {
        $( '#record-info li' ).hide().find('span:eq(1)').text('');
    }

    function updateRecordInfo( name, value ) {
        $( '#record-info-' + name ).show().find('span:eq(1)').text(value);
    }

    function setSource(parts) {
        state.backend = parts[0];
        state.record_id = parts[1];

        document.location.hash = '#' + parts[0] + ':' + parts[1];
        $( '#title' ).text( _("Editing ") + backends[ parts[0] ].record_label.replace( '{ID}', parts[1] ) );
        $( 'title', document.head ).html( _("Koha &rsaquo; Cataloging &rsaquo; Editing ") + backends[ parts[0] ].record_label.replace( '{ID}', parts[1] ) );
    }

    function displayRecord( editor, record ) {
        editor.setValue( TextMARC.RecordToText(record) );

        for ( var line = 0; line < editor.lineCount(); line++ ) updateWidgets( editor, line );
    }

    function saveRecord( recid, editor, callback ) {
        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].save ) return false;

        state.saving = true;
        $.each( editor.getAllMarks(), function( _, mark ) {
            if ( mark.widget ) mark.widget.clearToText();
        } );
        var record = TextMARC.TextToRecord( editor.getValue() );
        state.saving = false;
        for ( var line = 0; line < editor.lineCount(); line++ ) updateWidgets( editor, line );
        if ( !record ) return;

        backends[ parts[0] ].save( parts[1], record, function(data) {
            if (data.newRecord) {
                var record = new MARC.Record();
                record.loadMARCXML(data.newRecord);
                displayRecord( editor, record );
            }

            if (data.newId) {
                setSource(data.newId);
            }

            if (callback) callback();
        } );
    }

    function openRecord( recid, editor, callback ) {
        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].get ) return false;

        clearRecordInfo();
        backends[ parts[0] ].get( parts[1], function( record ) {
            setSource( parts );

            displayRecord( editor, record );

            if (callback) callback(record);
        } );

        return true;
    }

    $(document).ready( function() {
        var editor = CodeMirror(
            function (elt) { $(elt).insertAfter('#toolbar') },
            {
                extraKeys: editorKeys,
                lineWrapping: true,
                mode: 'marc'
            }
        );

        makeHiddenWidgets('');

        editor.on( 'beforeChange', editorBeforeChange );
        editor.on( 'change', editorChange );
        editor.on( 'cursorActivity', editorCursorActivity );

        var resizeTimer = null;
        $( window ).resize( function() {
            if ( resizeTimer == null ) resizeTimer = setTimeout( function() {
                resizeTimer = null;

                var pos = $('#editor .CodeMirror').position();
                $('#editor .CodeMirror').height( $(window).height() - pos.top - 24 );
            }, 100);
        } ).resize();

        var saveable_backends = [];
        $.each( backends, function( id, backend ) {
            if ( backend.save ) saveable_backends.push( [ backend.save_label, id ] );
        } );
        saveable_backends.sort();
        $.each( saveable_backends, function( _, backend ) {
            $( '#save-dropdown' ).append( '<li><a href="#" data-backend="' + backend[1] + '">' + backend[0] + '</a></li>' );
        } );

        $( '#save-record, #save-dropdown a' ).click( function() {
            var backend = $( this ).data( 'backend' ) || 'catalog';
            if ( state.backend == backend ) {
                saveRecord( backend + ':' + state.record_id, editor );
            } else {
                saveRecord( backend + ':', editor );
            }

            return;
        } );

        function finish_cb() {
            $("#loading").hide();
        }

        if ( "[% auth_forwarded_hash %]" ) {
            document.location.hash = "[% auth_forwarded_hash %]";
        }

        if ( !document.location.hash || !openRecord( document.location.hash.slice(1), editor, finish_cb ) ) {
            openRecord( 'new:', editor, finish_cb );
        }
    } );
} )();

</script>
