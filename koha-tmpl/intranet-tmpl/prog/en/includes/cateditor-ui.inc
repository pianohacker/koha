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
require( [ 'koha-backend', 'marc-record', 'text-marc', 'widget-utils' ], function( KohaBackend, MARC, TextMARC, Widget ) {
    var state = {
        backend: '',
        record_id: undefined,
        saving: false
    };

    function makeHiddenWidgets( frameworkCode ) {
        var hiddenWidget = {
            init: function() {
                return $( '<span class="subfield-widget hidden-widget"><span class="hint">hidden</span></span>' )[0];
            },
            postCreate: function( node, mark ) {
            }
        };

        $.each( KohaBackend.GetAllTagsInfo( frameworkCode ), function( tag, tagInfo ) {
            $.each( tagInfo.subfields, function( subfield, subfieldInfo ) {
                if ( subfieldInfo.hidden < -3 || subfieldInfo.hidden > 4 ) editorWidgets[ tag + subfield ] = hiddenWidget;
            } );
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

                Widget.UpdateLine( editor, line );
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
                    done( { error: data.error, newRecord: data.marcxml && data.marcxml[0], newId: data.biblionumber && [ 'catalog', data.biblionumber ] } );
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

        for ( var line = 0; line < editor.lineCount(); line++ ) Widget.UpdateLine( editor, line );
    }

    function saveRecord( recid, editor, callback ) {
        if (state.saving) return;
        state.saving = true;

        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].save ) return false;

        $.each( editor.getAllMarks(), function( _, mark ) {
            if ( mark.widget ) mark.widget.clearToText();
        } );
        var record = TextMARC.TextToRecord( editor.getValue() );
        for ( var line = 0; line < editor.lineCount(); line++ ) Widget.UpdateLine( editor, line );
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

            state.saving = false;
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
        makeHiddenWidgets('');

        var editor = CodeMirror(
            function (elt) { $(elt).insertAfter('#toolbar') },
            {
                extraKeys: editorKeys,
                lineWrapping: true,
                mode: {
                    name: 'marc',
                    nonRepeatableTags: KohaBackend.GetTagsBy( '', 'repeatable', '0' ),
                    nonRepeatableSubfields: KohaBackend.GetSubfieldsBy( '', 'repeatable', '0' )
                }
            }
        );

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
            $( '#save-record' ).find('i').attr( 'class', 'icon-loading' ).siblings( 'span' ).text( _( 'Saving...' ) );
            function finish_cb() {
                $( '#save-record' ).find('i').attr( 'class', 'icon-hdd' ).siblings( 'span' ).text( _( 'Save' ) );
            }

            var backend = $( this ).data( 'backend' ) || 'catalog';
            if ( state.backend == backend ) {
                saveRecord( backend + ':' + state.record_id, editor, finish_cb );
            } else {
                saveRecord( backend + ':', editor, finish_cb );
            }

            return false;
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
