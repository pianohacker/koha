<script src="/intranet-tmpl/lib/codemirror/codemirror.js"></script>
<script src="/intranet-tmpl/lib/codemirror/lib/runmode.js"></script>
<script src="/intranet-tmpl/lib/koha/cateditor/marc-mode.js"></script>
<script src="/intranet-tmpl/lib/require.js"></script>
<script src="/intranet-tmpl/lib/jquery/plugins/jquery.lightbox_me.js"></script>
<script>
require.config( {
    baseUrl: '/intranet-tmpl/lib/koha/cateditor/',
    paths: {
        pz2: '../../pz2',
    },
    shim: {
        pz2: { exports: 'pz2' },
    },
} );
</script>

[% IF marcflavour == 'MARC21' %]
[% PROCESS 'cateditor-widgets-marc21.inc' %]
[% ELSE %]
<script>var editorWidgets = {};</script>
[% END %]

<script>
require( [ 'koha-backend', 'search', 'marc-record', 'preferences', 'text-marc', 'widget-utils', 'xslt' ], function( KohaBackend, Search, MARC, Preferences, TextMARC, Widget, XSLT ) {
    var xsltResultStylesheets = {
        [% FOREACH stylesheet IN xslt_result_stylesheets %]
        '[% stylesheet.syntax %]': XSLT.Get( '[% stylesheet.url %]' ),
        [% END %]
    };

    var xsltDetailStylesheets = {
        [% FOREACH stylesheet IN xslt_detail_stylesheets %]
        '[% stylesheet.syntax %]': XSLT.Get( '[% stylesheet.url %]' ),
        [% END %]
    };

    var z3950Targets = {
        [% FOREACH target = z3950_targets %]
            '[% target.host %]:[% target.port %]/[% target.db %]': {
                'name': '[% target.name %]',
                'authentication': '[% target.userid %]:[% target.password %]',
                'syntax': '[% target.syntax %]',
                'kohasyntax': '[% target.syntax == 'USMARC' ? 'MARC21' : target.syntax %]',
                'encoding': '[% target.encoding %]',
                'checked': [% target.checked ? 'true' : 'false' %],
            },
        [% END %]
    };

    var state = {
        backend: '',
        saveBackend: 'catalog',
        recordID: undefined,
        saving: false
    };

    function makeHiddenWidgets( frameworkCode ) {
        var hiddenWidget = {
            clearToText: function() {
                var range = this.mark.find();
                this.mark.doc.replaceRange( '', range.from, range.to, 'marcAware' );
            },
            init: function() {
                return $( '<span class="subfield-widget hidden-widget hint">' + _("hidden") + '</span>' )[0];
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

    function bindGlobalKeys() {
        function bindKey( key, handler ) {
            $( document ).bind( 'keydown', key, handler );
            $( document ).bind( 'keypress', key, handler );
            $( '#sidebar input' ).bind( 'keydown', key, handler );
            $( '#editor textarea' ).bind( 'keydown', key, handler );
        }

        bindKey( 'ctrl+s', function(event) {
            $( '#save-record' ).click();

            event.preventDefault();
        } );

        bindKey( 'ctrl+k', function(event) {
            $( '#catalog-source' )[0].checked = true;
            $( '#q' ).focus();

            return false;
        } );

        bindKey( 'alt+ctrl+k', function(event) {
            $( '#reservoir-source' )[0].checked = true;
            $( '#q' ).focus();

            return false;
        } );

        bindKey( 'ctrl+shift+k', function(event) {
            $( '#z3950-source' )[0].checked = true;
            $( '#q' ).focus();

            return false;
        } );
    }

    // Editor helper functions
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

        'Ctrl-D': function( editor ) {
            // Delete line
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
                    editor.setCursor( { line: cur.line, ch: positions[i] } );
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
                    editor.setCursor( { line: cur.line, ch: positions[i] } );
                    done = true;
                    return false;
                }
            }

            if ( cur.line == 0 ) return;

            var prevPositions = getTabPositions( editor, { line: cur.line - 1, ch: editor.getLine( cur.line - 1 ).length } );
            editor.setCursor( { line: cur.line - 1, ch: prevPositions.length ? prevPositions[ prevPositions.length - 1 ] : 0 }  );
        },
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
            var startLine = change.from.line;
            var endLine = change.to.line;
            if ( endLine < startLine ) {
                startLine = change.to.line;
                endLine = change.start.line;
            }

            for ( var line = startLine; line <= endLine + change.text.length - 1; line++ ) {
                if ( updatedLines[line] ) continue;

                if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( editor, line );
                if ( change.origin != 'setValue' && change.origin != 'marcWidgetPrefill' ) editor.addLineClass( line, 'wrapper', 'modified-line' );
                updatedLines[line] = true;
            }
        } while ( change = change.next )
    }

    // Record loading
    var backends = {
       'new': {
            recordLabel: _("new record"),
            get: function( id, callback ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record );

                callback( record );
            },
        },
        'new-full': {
            recordLabel: _("new full record"),
            get: function( id, callback ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record, true );

                callback( record );
            },
        },
        'catalog': {
            recordLabel: _("catalog record #{ID}"),
            saveLabel: _("to catalog"),
            get: function( id, callback ) {
                if ( !id ) return false;

                KohaBackend.GetRecord( id, callback );
            },
            save: function( id, record, done ) {
                function finishCb( data ) {
                    done( { error: data.error, newRecord: data.marcxml && data.marcxml[0], newId: data.biblionumber && [ 'catalog', data.biblionumber ] } );
                }

                if ( id ) {
                    KohaBackend.SaveRecord( id, record, finishCb );
                } else {
                    KohaBackend.CreateRecord( record, finishCb );
                }
            }
        },
        'search': {
            recordLabel: _("search result"),
            get: function( id, callback ) {
                if ( !id ) return false;

                Search.GetDetailedRecord( decodeURIComponent(id), callback );
            },
        },
    };

    function clearRecordInfo( name, value ) {
        $( '#record-info li' ).hide().find('span:eq(1)').text('');
    }

    function updateRecordInfo( name, value ) {
        $( '#record-info-' + name ).show().find('span:eq(1)').text(value);
    }

    function setSource(parts) {
        state.backend = parts[0];
        state.recordID = parts[1];
        state.canSave = backends[ state.backend ].save != null;
        state.saveBackend = state.canSave ? state.backend : 'catalog';

        document.location.hash = '#' + parts[0] + ':' + parts[1];
        $( '#title' ).text( _("Editing ") + backends[ state.backend ].recordLabel.replace( '{ID}', parts[1] ) );
        $( 'title', document.head ).html( _("Koha &rsaquo; Cataloging &rsaquo; Editing ") + backends[ state.backend ].recordLabel.replace( '{ID}', parts[1] ) );
        $( '#save-record span' ).text( _("Save ") + backends[ state.saveBackend ].saveLabel );
    }

    function displayRecord( editor, record ) {
        editor.setValue( TextMARC.RecordToText(record) );
    }

    function saveRecord( recid, editor, callback ) {
        if (state.saving) return;
        state.saving = true;

        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].save ) return false;

        Widget.RemoveErrors( editor );

        $.each( editor.getAllMarks(), function( undef, mark ) {
            if ( mark.widget ) mark.widget.clearToText();
        } );
        var record = TextMARC.TextToRecord( editor.getValue() );
        for ( var line = 0; line <= editor.lastLine(); line++ ) {
            if ( Preferences.user.fieldWidgets ) Widget.UpdateLine( editor, line );
        }
        if ( record.errors ) {
            state.saving = false;
            callback( { error: 'syntax', errors: record.errors } );
            return;
        }

        var errors = KohaBackend.ValidateRecord( '', record );
        if ( errors.length ) {
            state.saving = false;
            callback( { error: 'invalid', errors: errors } );
            return;
        }

        backends[ parts[0] ].save( parts[1], record, function(data) {
            state.saving = false;

            if (data.newRecord) {
                var record = new MARC.Record();
                record.loadMARCXML(data.newRecord);
                displayRecord( editor, record );
            }

            if (data.newId) {
                setSource(data.newId);
            }

            if (callback) callback( data );
        } );
    }

    function loadRecord( recid, editor, callback ) {
        var parts = recid.split(':');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].get ) return false;

        backends[ parts[0] ].get( parts[1], function( record ) {
            displayRecord( editor, record );

            if (callback) callback(record);
        } );

        return true;
    }

    function openRecord( recid, editor, callback ) {
        return loadRecord( recid, editor, function ( record ) {
            clearRecordInfo();
            setSource( recid.split(':') );

            if (callback) callback( record );
        } );
    }

    // Search functions
    function showResultsBox(data) {
        $('#searchresults table').empty();
        $('#search-targetsinfo').empty().append('<li>' + _("Loading...") + '</li>');
        $('#search-results-ui').lightbox_me();
    }

    function showDetailedResult( hit, $tr, fetchOnly ) {
        Search.GetDetailedRecord( hit.recid, function( record ) {
            if ( fetchOnly ) return;

            xsltResultStylesheets[ z3950Targets[ hit.location[0]['@id'] ].kohasyntax ].done( function( xslDoc ) {
                $tr.find( '.results-info' ).html( XSLT.TransformToFragment( record.xmlSource, xslDoc ) );
            } );
        } );
    }

    function showSearchResults( editor, data ) {
        $('#searchresults table').empty();

        $.each( data.hits, function( undef, hit ) {
            var result = '<tr>';
            result += '<td class="sourcecol">' + hit.location[0]['@name'] + '</td>';
            result += '<td><div class="results-info">' + hit['md-work-title'][0] + '</div></td>';
            result += '<td class="toolscol"><ul><li><a href="#" class="marc-link">' + _("View MARC") + '</a></li>';
            result += '<li><a href="#" class="open-link">' + _("Import") + '</a></li>';
            if ( state.canSave ) result += '<li><a href="#" class="substitute-link" title=' + _("Replace the current record's contents") + '>' + _("Substitute") + '</li>';
            result += '</ul></td></tr>';

            var $tr = $( result );
            $tr.find( '.marc-link' ).click( function() {
                $tr.find( '.results-info' ).addClass( 'results-marc' ).empty();

                Search.GetDetailedRecord( hit.recid, function( record ) {
                    CodeMirror.runMode( TextMARC.RecordToText( record ), 'marc', $tr.find( '.results-info' )[0] );
                } );

                return false;
            } );
            $tr.find( '.open-link' ).click( function() {
                $( '#search-results-ui' ).trigger( 'close' );
                openRecord( hit.id, editor );

                return false;
            } );
            $tr.find( '.substitute-link' ).click( function() {
                $( '#search-results-ui' ).trigger( 'close' );
                loadRecord( hit.id, editor );

                return false;
            } );
            $('#searchresults table').append( $tr );

            showDetailedResult( hit, $tr, !!data.activeclients );
        } );

        var $loadingOverlay = $('#search-loading-overlay');

        if ( data.activeclients ) {
            if ( !$loadingOverlay.length ) {
                $loadingOverlay = $( '<div id="search-loading-overlay">' + _("Loading...") + '</div>' );
                $loadingOverlay.css( { position: 'absolute', zIndex: 9001, top: 0, right: 0, bottom: 0, left: 0 } );
                $loadingOverlay.appendTo( '#searchresults' );
            }
            $loadingOverlay.show();
        } else {
            $loadingOverlay.fadeOut();
        }
    }

    function showSearchTargets(data) {
        $('#search-targetsinfo').empty();

        $.each( data, function( undef, target ) {
            $('#search-targetsinfo').append( '<li>' + target.name + ' (' + target.hits + ')' + '</li>' );
        } );
    }

    // Preference functions
    function showPreference( pref ) {
        var value = Preferences.user[pref];

        switch (pref) {
            case 'fieldWidgets':
                $( '#set-field-widgets' ).text( value ? _("Show fields verbatim") : _("Show helpers for fixed and coded fields") );
                break;
        }
    }

    function bindPreference( editor, pref ) {
        function _addHandler( sel, event, handler ) {
            $( sel ).on( event, function (e) {
                e.preventDefault();
                handler( e, Preferences.user[pref] );
                Preferences.Save( [% USER_INFO.0.borrowernumber %] );
                showPreference(pref);
            } );
        }

        switch (pref) {
            case 'fieldWidgets':
                _addHandler( '#set-field-widgets', 'click', function( e, oldValue ) {
                    if ( oldValue ) {
                        Preferences.user.fieldWidgets = false;
                        $.each( editor.getAllMarks(), function( undef, mark ) {
                            if ( mark.widget ) mark.widget.clearToText();
                        } );
                    } else {
                        Preferences.user.fieldWidgets = true;
                        for ( var line = 0; line <= editor.lastLine(); line++ ) {
                            Widget.UpdateLine( editor, line );
                        }
                    }
                } );
                break;
        }
    }

    function displayPreferences( editor ) {
        $.each( Preferences.user, function( pref, value ) {
            showPreference( pref );
            bindPreference( editor, pref );
        } );
    }

    $(document).ready( function() {
        // Editor setup
        var editor = CodeMirror(
            function (elt) { $(elt).insertAfter('#toolbar') },
            {
                extraKeys: editorKeys,
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

        var saveableBackends = [];
        $.each( backends, function( id, backend ) {
            if ( backend.save ) saveableBackends.push( [ backend.saveLabel, id ] );
        } );
        saveableBackends.sort();
        $.each( saveableBackends, function( undef, backend ) {
            $( '#save-dropdown' ).append( '<li><a href="#" data-backend="' + backend[1] + '">' + _("Save ") + backend[0] + '</a></li>' );
        } );

        // Click bindings
        $( '#save-record, #save-dropdown a' ).click( function() {
            $( '#save-record' ).find('i').attr( 'class', 'icon-loading' ).siblings( 'span' ).text( _("Saving...") );

            function finishCb(result) {
                if ( result.error == 'syntax' ) {
                    humanMsg.displayAlert( _("Incorrect syntax, cannot save"), { className: 'humanError' } );
                } else if ( result.error == 'invalid' ) {
                    humanMsg.displayAlert( _("Record structure invalid, cannot save"), { className: 'humanError' } );
                } else if ( !result.error ) {
                    humanMsg.displayAlert( _("Record saved "), { className: 'humanSuccess' } );
                }

                $.each( result.errors || [], function( undef, error ) {
                    switch ( error.type ) {
                        case 'noTag':
                            Widget.AddError( editor, error.line, _("Invalid tag number") );
                            break;
                        case 'noIndicators':
                            Widget.AddError( editor, error.line, _("Invalid indicators") );
                            break;
                        case 'missingTag':
                            Widget.AddError( editor, null, _("Missing mandatory tag: ") + error.tag );
                            break;
                        case 'missingSubfield':
                            if ( error.subfield == '@' ) {
                                Widget.AddError( editor, error.line, _("Missing control field contents") );
                            } else {
                                Widget.AddError( editor, error.line, _("Missing mandatory subfield: $") + error.subfield );
                            }
                            break;
                        case 'unrepeatableTag':
                            Widget.AddError( editor, error.line, _("Tag ") + error.tag + _(" cannot be repeated") );
                            break;
                        case 'unrepeatableSubfield':
                            Widget.AddError( editor, error.line, _("Subfield $") + error.subfield + _(" cannot be repeated") );
                            break;
                    }
                } );

                $( '#save-record' ).find('i').attr( 'class', 'icon-hdd' );

                if ( result.error ) {
                    // Reset backend info
                    setSource( [ state.backend, state.recordID ] );
                }
            }

            var backend = $( this ).data( 'backend' ) || ( state.saveBackend );
            if ( state.backend == backend ) {
                saveRecord( backend + ':' + state.recordID, editor, finishCb );
            } else {
                saveRecord( backend + ':', editor, finishCb );
            }

            return false;
        } );

        $( '#switch-editor' ).click( function() {
            if ( !confirm( _("Any changes will not be saved. Continue?") ) ) return;

            $.cookie( 'catalogue_editor_[% USER_INFO.0.borrowernumber %]', 'basic', { expires: 365, path: '/' } );

            if ( state.backend == 'catalog' ) {
                window.location = '/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=' + state.recordID;
            } else if ( state.backend == 'new' ) {
                window.location = '/cgi-bin/koha/cataloguing/addbiblio.pl';
            } else {
                humanMsg.displayAlert( _("Cannot open this record in the basic editor"), { className: 'humanError' } );
            }
        } );

        // Key bindings
        bindGlobalKeys();

        $('#quicksearch').submit( function() {
            var q = this.q.value;
            if (!q) return false;

            showResultsBox();
            Search.Start( z3950Targets, q, 20 );

            return false;
        } );

        // Start editor
        Preferences.Load( [% USER_INFO.0.borrowernumber %] );
        displayPreferences(editor);
        Search.Init( z3950Targets, { onresults: function(data) { showSearchResults( editor, data ) }, onbytarget: showSearchTargets } );

        function finishCb() {
            $("#loading").hide();
        }

        if ( "[% auth_forwarded_hash %]" ) {
            document.location.hash = "[% auth_forwarded_hash %]";
        }

        if ( !document.location.hash || !openRecord( document.location.hash.slice(1), editor, finishCb ) ) {
            openRecord( 'new:', editor, finishCb );
        }
    } );
} )();

</script>
