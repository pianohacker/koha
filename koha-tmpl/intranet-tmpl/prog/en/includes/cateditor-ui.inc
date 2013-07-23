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
[% INCLUDE 'cateditor-widgets-marc21.inc' %]
[% ELSE %]
<script>var editorWidgets = {};</script>
[% END %]

<script>
require( [ 'koha-backend', 'text-marc', 'marc-record' ], function( KohaBackend, TextMARC, MARC ) {
    KohaBackend.SetDefaultFramework( _preloadDefault.framework );

    // Editor helper functions
    var editorKeys = {
        Enter: function( editor ) {
            var cursor = editor.getCursor();
            editor.replaceRange( '\n', { line: cursor.line } );
            editor.setCursor( { line: cursor.line + 1, column: 0 } );
        }
    };

    function getLineInfo( editor, pos ) {
        var contents = editor.getLine( pos.line );
        var tagNumber = contents.match( /^[A-Za-z0-9]{3}/ );

        if ( !tagNumber ) return {}; // No tag at all on this line
        tagNumber = tagNumber[0];

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
        // FIXME: Should only cancel changes if this is a control field/subfield widget
        if ( editor.findMarksAt(change.from).length && editor.findMarksAt(change.to).length && !change.text[0].match(/^[$|ǂ‡]$/) ) change.cancel();
    }

    function updateWidgets( editor, line ) {
        var info = getLineInfo( editor, { line: line, ch: 0 } );

        if ( !info.tagNumber ) return;

        var subfields = [];

        var end = editor.getLine( line ).length;
        if ( info.tagNumber < '010' ) {
            if ( end >= 4 ) subfields.push( { code: '@', from: 4, to: end } );
        } else {
            for ( var i = 0; i < info.subfields.length; i++ ) {
                var next = ( i < info.subfields.length - 1 ) ? info.subfields[i + 1].ch : end;
                subfields.push( { code: info.subfields[i].code, from: info.subfields[i].ch + 3, to: next } );
            }
        }

        $.each( subfields, function ( _, subfield ) {
            var id = info.tagNumber + subfield.code;
            var marks = editor.findMarksAt( { line: line, ch: subfield.from } );

            if ( marks.length ) {
                if ( marks[0].id == id ) {
                    return;
                } else {
                    marks[0].clear();
                }
            }

            if ( !editorWidgets[id] ) return;

            if ( subfield.from == subfield.to ) {
                editor.replaceRange( widget.makeTemplate ? widget.makeTemplate() : '<empty>', { line: line, ch: subfield.from } );
                return; // We'll do the actual work when the change event is triggered again
            }

            var widget = editorWidgets[id];
            var node = widget.init( editor.getRange( { line: line, ch: subfield.from }, { line: line, ch: subfield.to } ) );

            var mark = editor.markText( { line: line, ch: subfield.from }, { line: line, ch: subfield.to }, {
                collapsed: true,
                inclusiveLeft: false,
                inclusiveRight: false,
                replacedWith: node,
            } );

            mark.id = id;
            mark.isWidget = true;

            if ( widget.postCreate ) widget.postCreate( node, mark );
        } );
    }

    function editorChange( editor, change ) {
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
            record_label: _("New record"),
            label: _("New record"),
            get: function( id, display_cb ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record );

                display_cb( record );
            },
        },
        'new-full': {
            record_label: _("New full record"),
            label: _("New record"),
            get: function( id, display_cb ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record, true );

                display_cb( record );
            },
        },
        'catalog': {
            record_label: _("Catalog record #{ID}"),
            label: _("Catalog"),
            get: function( id, display_cb ) {
                if ( !id ) return false;

                KohaBackend.GetRecord( id, display_cb );
            },
        }
    };

    function clearRecordInfo( name, value ) {
        $( '#record-info li' ).hide().find('span:eq(1)').text('');
    }

    function updateRecordInfo( name, value ) {
        $( '#record-info-' + name ).show().find('span:eq(1)').text(value);
    }

    function openRecord( recid, editor, callback ) {
        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].get ) return false;

        clearRecordInfo();
        backends[ parts[0] ].get( parts[1], function( record ) {
            updateRecordInfo( 'source', backends[ parts[0] ].record_label.replace( '{ID}', parts[1] ) );

            editor.setValue( TextMARC.RecordToText(record) );

            for ( var line = 0; line < editor.lineCount(); line++ ) updateWidgets( editor, line );

            if (callback) callback(record);
        } );

        return true;
    }

    $(document).ready( function() {
        var editor = CodeMirror(
            function (elt) { $('#editor').prepend(elt) },
            {
                extraKeys: editorKeys,
                lineWrapping: true,
                mode: 'marc'
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

        function finish_cb() {
            $("#loading").hide();
        }
        if ( !document.location.hash || !openRecord( document.location.hash.slice(1), editor, finish_cb ) ) {
            openRecord( 'new:', editor, finish_cb );
        }
    } );
} )();

</script>
