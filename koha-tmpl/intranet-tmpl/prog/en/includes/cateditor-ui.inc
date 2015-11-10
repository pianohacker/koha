<script src="[% interface %]/lib/codemirror/codemirror-compressed.js"></script>
<script src="[% interface %]/lib/filesaver.js"></script>
<script src="[% interface %]/lib/koha/cateditor/marc-mode.js"></script>
<script src="[% interface %]/lib/require.js"></script>
<script>
require.config( {
    baseUrl: '[% interface %]/lib/koha/cateditor/',
    config: {
        resources: {
            marcflavour: '[% marcflavour %]',
            themelang: '[% themelang %]',
        },
    },
    waitSeconds: 30,
} );
</script>

[% IF marcflavour == 'MARC21' %]
[% PROCESS 'cateditor-widgets-marc21.inc' %]
[% ELSE %]
<script>var editorWidgets = {};</script>
[% END %]

<script>
require( [ 'koha-backend', 'search', 'macros', 'marc-editor', 'marc-record', 'preferences', 'resources', 'text-marc', 'widget' ], function( KohaBackend, Search, Macros, MARCEditor, MARC, Preferences, Resources, TextMARC, Widget ) {
    var z3950Servers = {
        'koha:biblioserver': {
            name: _("Local catalog"),
            recordtype: 'biblio',
            checked: false,
        },
        [%- FOREACH batch = editable_batches -%]
            'batch:[% batch.import_batch_id %]': {
                name: _("Batch: ") + '[% batch.file_name %]',
                recordtype: 'biblio',
                checked: false,
            },
        [%- END -%]
        [%- FOREACH server = z3950_servers -%]
            [% server.id %]: {
                name: '[% server.servername %]',
                recordtype: '[% server.recordtype %]',
                checked: [% server.checked ? 'true' : 'false' %],
            },
        [%- END -%]
    };

    // The columns that should show up in a search, in order, and keyed by the corresponding <metadata> tag in the XSL and Pazpar2 config
    var z3950Labels = [
        [ "local_number", _("Local number") ],
        [ "title", _("Title") ],
        [ "series", _("Series title") ],
        [ "author", _("Author") ],
        [ "lccn", _("LCCN") ],
        [ "isbn", _("ISBN") ],
        [ "issn", _("ISSN") ],
        [ "medium", _("Medium") ],
        [ "edition", _("Edition") ],
        [ "notes", _("Notes") ],
    ];

    var state = {
        backend: '',
        recordID: undefined,
        saveTargets: {},
    };

    var editor;
    var macroEditor;

    function makeAuthorisedValueWidgets( frameworkCode ) {
        $.each( KohaBackend.GetAllTagsInfo( frameworkCode ), function( tag, tagInfo ) {
            $.each( tagInfo.subfields, function( subfield, subfieldInfo ) {
                if ( !subfieldInfo.authorised_value ) return;
                var authvals = KohaBackend.GetAuthorisedValues( subfieldInfo.authorised_value );
                if ( !authvals ) return;

                var defaultvalue = subfield.defaultvalue || authvals[0].value;

                Widget.Register( tag + subfield, {
                    init: function() {
                        var $result = $( '<span class="subfield-widget"></span>' );

                        return $result[0];
                    },
                    postCreate: function() {
                        this.setText( defaultvalue );

                        $( '<select></select>' ).appendTo( this.node );
                        var $node = $( this.node ).find( 'select' );
                        $.each( authvals, function( undef, authval ) {
                            $node.append( '<option value="' + authval.value + '"' + (authval.value == defaultvalue ? ' selected="selected"' : '') + '>' + authval.lib + '</option>' );
                        } );
                        $node.val( this.text );

                        $node.change( $.proxy( function() {
                            this.setText( $node.val() );
                        }, this ) );
                    },
                    makeTemplate: function() {
                        return defaultvalue;
                    },
                } );
            } );
        } );
    }

    function bindGlobalKeys() {
        shortcut.add( 'ctrl+s', function(event) {
            $( '#save-record' ).click();

            event.preventDefault();
        } );

        shortcut.add( 'alt+ctrl+k', function(event) {
            $( '#search-by-keywords' ).focus();

            return false;
        } );

        shortcut.add( 'alt+ctrl+a', function(event) {
            $( '#search-by-author' ).focus();

            return false;
        } );

        shortcut.add( 'alt+ctrl+i', function(event) {
            $( '#search-by-isbn' ).focus();

            return false;
        } );

        shortcut.add( 'alt+ctrl+t', function(event) {
            $( '#search-by-title' ).focus();

            return false;
        } );

        shortcut.add( 'ctrl+h', function() {
            var field = editor.getCurrentField();

            if ( !field ) return;

            window.open( getFieldHelpURL( field.tag ) );
        } );

        $('#quicksearch .search-box').each( function() {
            shortcut.add( 'enter', $.proxy( function() {
                var terms = [];

                $('#quicksearch .search-box').each( function() {
                    if ( !this.value ) return;

                    terms.push( [ $(this).data('qualifier'), this.value ] );
                } );

                if ( !terms.length ) return;

                if ( Search.Run( z3950Servers, Search.JoinTerms(terms) ) ) {
                    $("#search-overlay").show();
                    showResultsBox();
                }

                return false;
            }, this), { target: this, type: 'keypress' } );
        } );
    }

    function getFieldHelpURL( tag ) {
        [% IF ( marcflavour == 'MARC21' ) %]
            if ( tag == '000' ) {
                return "http://www.loc.gov/marc/bibliographic/bdleader.html";
            } else if ( tag >= '090' && tag < '100' ) {
                return "http://www.loc.gov/marc/bibliographic/bd09x.html";
            } else if ( tag < '900' ) {
                return "http://www.loc.gov/marc/bibliographic/bd" + tag + ".html";
            } else {
                return "http://www.loc.gov/marc/bibliographic/bd9xx.html";
            }
        [% ELSIF ( marcflavour == 'UNIMARC' ) %]
            /* http://archive.ifla.org/VI/3/p1996-1/ is an outdated version of UNIMARC, but
               seems to be the only version available that can be linked to per tag.  More recent
               versions of the UNIMARC standard are available on the IFLA website only as
               PDFs!
            */
            if ( tag == '000' ) {
               return  "http://archive.ifla.org/VI/3/p1996-1/uni.htm";
            } else {
                var first = tag[0];
                var url = "http://archive.ifla.org/VI/3/p1996-1/uni" + first + ".htm#";
                if ( first == '0' ) url += "b";
                if ( first != '9' ) url += tag;

                return url;
            }
        [% END %]
    }

    // Record loading
    var backends = {
       'new': {
            titleForRecord: _("Editing new record"),
            get: function( id, callback ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record );

                callback( record );
            },
        },
        'new-full': {
            titleForRecord: _("Editing new full record"),
            get: function( id, callback ) {
                record = new MARC.Record();
                KohaBackend.FillRecord( '', record, true );

                callback( record );
            },
        },
        'catalog': {
            titleForRecord: _("Editing catalog record #%s"),
            links: [
                { title: _("view"), href: "/cgi-bin/koha/catalogue/detail.pl?biblionumber=%s" },
                { title: _("edit items"), href: "/cgi-bin/koha/cataloguing/additem.pl?biblionumber=%s" },
            ],
            saveLabel: _("New catalog record"),
            saveExistingLabel: _("Catalog record #%s"),
            get: function( id, callback ) {
                if ( !id ) return false;

                KohaBackend.GetRecord( id, function( data ) {
                    if ( !data.error ) {
                        setSaveTargetChecked( 'catalog/', false );
                        addSaveTarget( {
                            label: backends.catalog.saveExistingLabel.format( id ),
                            id: 'catalog/' + id,
                            description: '',
                            checked: true
                        } );
                    }

                    callback(data);
                } );
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
        'iso2709': {
            saveLabel: _("New ISO2709 (.mrc) file"),
            save: function( id, record, done ) {
                saveAs( new Blob( [record.toISO2709()], { 'type': 'application/octet-stream;charset=utf-8' } ), 'record.mrc' );

                done( {} );
            }
        },
        'marcxml': {
            saveLabel: _("New MARCXML (.xml) file"),
            save: function( id, record, done ) {
                saveAs( new Blob( [record.toXML()], { 'type': 'application/octet-stream;charset=utf-8' } ), 'record.xml' );

                done( {} );
            }
        },
        'search': {
            titleForRecord: _("Editing search result"),
            get: function( id, callback ) {
                if ( !id ) return false;
                if ( !backends.search.records[ id ] ) {
                    callback( { error: _( "Invalid record" ) } );
                    return false;
                }

                callback( backends.search.records[ id ] );
            },
            records: {},
        },
    };

    var editable_batches = {
        [%- FOREACH batch = editable_batches -%]
            [% batch.import_batch_id %]: {
                'name': '[% batch.file_name %]',
            },
        [%- END -%]
    };

    function addSaveTarget( target ) {
        state.saveTargets[target.id] = target;
        if (target.enabled == null) target.enabled = true;

        // Have to check that Preferences has been initialized
        var saved_value = Preferences.user && Preferences.user.selected_save_targets[target.id];
        if ( saved_value != null ) target.checked = saved_value;

        var target_list = $.map( state.saveTargets, function( target ) {
            return target;
        } );

        target_list.sort( function( a, b ) {
            return a.label.localeCompare(b.label);
        } );

        $('#save-targets ol').empty();

        $.each( target_list, function( i, target ) {
            var $new_target = $(
                '<li><input type="checkbox" class="save-toggle-target" data-target-id="' + target.id + '" id="save-target-' + i + '"' + ( target.checked ? ' checked="checked"' : '' ) + '> <label for="save-target-' + i + '">' + target.label + '</label></li>'
            );

            $new_target.find('input').change( function() {
                target.checked = this.checked;
            } );

            $('#save-targets ol').append($new_target);

            if (!target.enabled) $new_target.hide();
        } );
    }

    function setSaveTargetChecked( target_id, checked ) {
        if ( state.saveTargets[target_id] == null ) return;

        state.saveTargets[target_id].checked = checked;
        $( '#save-targets input[data-target-id="' + target_id + '"]' )[0].checked = checked;
    }

    function setSaveTargetEnabled( target_id, enabled ) {
        if ( !enabled ) {
            setSaveTargetChecked( target_id, false );
        }

        state.saveTargets[target_id].enabled = enabled;
        $( '#save-targets input[data-target-id="' + target_id + '"]' ).closest('li').toggle(enabled);
    }

    function setSource(parts) {
        state.backend = parts[0];
        state.recordID = parts[1];
        state.canSave = backends[ state.backend ].save != null;
        state.saveBackend = state.canSave ? state.backend : 'catalog';

        var backend = backends[state.backend];

        document.location.hash = '#' + parts[0] + '/' + parts[1];

        $('#title').text( backend.titleForRecord.format( parts[1] ) );

        $.each( backend.links || [], function( i, link ) {
            $('#title').append(' <a target="_blank" href="' + link.href.format( parts[1] ) + '">(' + link.title + ')</a>' );
        } );
        $( 'title', document.head ).html( _("Koha &rsaquo; Cataloging &rsaquo; ") + backend.titleForRecord.format( parts[1] ) );
    }

    function saveRecord( recid, editor, callback ) {
        var parts = recid.split('/');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].save ) return false;

        editor.removeErrors();
        var record = editor.getRecord();

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
                editor.displayRecord( record );
            }

            if (data.newId) {
                setSource(data.newId);

                var backend = backends[ parts[0] ];

                setSaveTargetChecked( recid, false );
                addSaveTarget( {
                    label: backend.saveExistingLabel.format( data.newId[1] ),
                    id: data.newId.join('/'),
                    description: '',
                    checked: true
                } );
            } else {
                setSource( [ state.backend, state.recordID ] );
            }

            if (callback) callback( data );
        } );
    }

    function loadRecord( recid, editor, callback ) {
        var parts = recid.split('/');
        if ( parts.length != 2 ) return false;

        if ( !backends[ parts[0] ] || !backends[ parts[0] ].get ) return false;

        backends[ parts[0] ].get( parts[1], function( record ) {
            if ( !record.error ) {
                editor.displayRecord( record );
                editor.focus();
            }

            if (callback) callback(record);
        } );

        return true;
    }

    function openRecord( recid, editor, callback ) {
        return loadRecord( recid, editor, function ( record ) {
            setSource( recid.split('/') );

            if (callback) callback( record );
        } );
    }

    // Search functions
    function showAdvancedSearch() {
        $('#advanced-search-servers').empty();
        $.each( z3950Servers, function( server_id, server ) {
            $('#advanced-search-servers').append( '<li data-server-id="' + server_id + '"><label><input class="search-toggle-server" type="checkbox"' + ( server.checked ? ' checked="checked">' : '>' ) + server.name + '</label></li>' );
        } );
        $('#advanced-search-ui').modal('show');
    }

    function startAdvancedSearch() {
        var terms = [];

        $('#advanced-search-ui .search-box').each( function() {
            if ( !this.value ) return;

            terms.push( [ $(this).data('qualifier'), this.value ] );
        } );

        if ( !terms.length ) return;

        if ( Search.Run( z3950Servers, Search.JoinTerms(terms) ) ) {
            $('#advanced-search-ui').modal('hide');
            $("#search-overlay").show();
            showResultsBox();
        }
    }

    function showResultsBox(data) {
        $('#search-top-pages, #search-bottom-pages').find('.pagination').empty();
        $('#searchresults thead tr').empty();
        $('#searchresults tbody').empty();
        $('#search-serversinfo').empty().append('<li>' + _("Loading...") + '</li>');
        $('#search-results-ui').modal('show');
    }

    function showSearchSorting( sort_key, sort_direction ) {
        var $th = $('#searchresults thead tr th[data-sort-label="' + sort_key + '"]');
        $th.parent().find( 'th[data-sort-label]' ).attr( 'class', 'sorting' );

        if ( sort_direction == 'asc' ) {
            direction = 'asc';
            $th.attr( 'class', 'sorting_asc' );
        } else {
            direction = 'desc';
            $th.attr( 'class', 'sorting_desc' );
        }
    }

    function showSearchResults( editor, data ) {
        backends.search.records = {};

        $('#searchresults thead tr').empty();
        $('#searchresults tbody').empty();
        $('#search-serversinfo').empty();

        $.each( z3950Servers, function( server_id, server ) {
            var num_fetched = data.num_fetched[server_id];

            if ( data.errors[server_id] ) {
                num_fetched = data.errors[server_id];
            } else if ( num_fetched == null ) {
                num_fetched = '-';
            } else if ( num_fetched < data.num_hits[server_id] ) {
                num_fetched += '+';
            }

            $('#search-serversinfo').append( '<li data-server-id="' + server_id + '"><label><input class="search-toggle-server" type="checkbox"' + ( server.checked ? ' checked="checked">' : '>' ) + server.name + ' (' + num_fetched + ')' + '</label></li>' );
        } );

        var seenColumns = {};

        $.each( data.hits, function( undef, hit ) {
            $.each( hit.metadata, function(key) {
                seenColumns[key] = true;
            } );
        } );

        $('#searchresults thead tr').append('<th>' + _("Source") + '</th>');

        $.each( z3950Labels, function( undef, label ) {
            if ( seenColumns[ label[0] ] ) {
                $('#searchresults thead tr').append( '<th class="sorting" data-sort-label="' + label[0] + '">' + label[1] + '</th>' );
            }
        } );

        showSearchSorting( data.sort_key, data.sort_direction );

        $('#searchresults thead tr').append('<th>' + _("Tools") + '</th>');

        var bibnumMap = KohaBackend.GetSubfieldForKohaField('biblio.biblionumber');
        $.each( data.hits, function( undef, hit ) {
            backends.search.records[ hit.server + ':' + hit.index ] = hit.record;

            switch ( hit.server ) {
                case 'koha:biblioserver':
                    var bibnumField = hit.record.field( bibnumMap[0] );

                    if ( bibnumField && bibnumField.hasSubfield( bibnumMap[1] ) ) {
                        hit.id = 'catalog/' + bibnumField.subfield( bibnumMap[1] );
                        break;
                    }

                    // Otherwise, fallthrough

                default:
                    hit.id = 'search/' + hit.server + ':' + hit.index;
            }

            var result = '<tr>';
            result += '<td class="sourcecol">' + z3950Servers[ hit.server ].name + '</td>';

            $.each( z3950Labels, function( undef, label ) {
                if ( !seenColumns[ label[0] ] ) return;

                if ( hit.metadata[ label[0] ] ) {
                    result += '<td class="infocol">' + hit.metadata[ label[0] ] + '</td>';
                } else {
                    result += '<td class="infocol">&nbsp;</td>';
                }
            } );

            result += '<td class="toolscol"><ul><li><a href="#" class="marc-link">' + _("View MARC") + '</a></li>';
            result += '<li><a href="#" class="open-link">' + ( hit.server == 'koha:biblioserver' ? _("Edit") : _("Import") ) + '</a></li>';
            if ( state.canSave ) result += '<li><a href="#" class="substitute-link" title="' + _("Replace the current record's contents") + '">' + _("Substitute") + '</a></li>';
            result += '</ul></td></tr>';

            var $tr = $( result );
            $tr.find( '.marc-link' ).click( function() {
                var $info_columns = $tr.find( '.infocol' );
                var $marc_column = $tr.find( '.marccol' );

                if ( !$marc_column.length ) {
                    $marc_column = $( '<td class="marccol" colspan="' + $info_columns.length + '"></td>' ).insertAfter( $info_columns.eq(-1) ).hide();
                    CodeMirror.runMode( TextMARC.RecordToText( hit.record ), 'marc', $marc_column[0] );
                }

                if ( $marc_column.is(':visible') ) {
                    $tr.find('.marc-link').text( _("View MARC") );
                    $info_columns.show();
                    $marc_column.hide();
                } else {
                    $tr.find('.marc-link').text( _("Hide MARC") );
                    $marc_column.show();
                    $info_columns.hide();
                }

                return false;
            } );
            $tr.find( '.open-link' ).click( function() {
                $( '#search-results-ui' ).modal('hide');
                openRecord( hit.id, editor );

                return false;
            } );
            $tr.find( '.substitute-link' ).click( function() {
                $( '#search-results-ui' ).modal('hide');
                loadRecord( hit.id, editor );

                return false;
            } );
            $('#searchresults tbody').append( $tr );
        } );

        var pages = [];
        var cur_page = data.offset / data.page_size;
        var max_page = Math.ceil( data.total_fetched / data.page_size ) - 1;

        if ( cur_page != 0 ) {
            pages.push( '<li><a class="search-nav" href="#" data-offset="' + (data.offset - data.page_size) + '">&laquo; ' + _("Previous") + '</a></li>' );
        }

        for ( var page = Math.max( 0, cur_page - 9 ); page <= Math.min( max_page, cur_page + 9 ); page++ ) {
            if ( page == cur_page ) {
                pages.push( ' <li class="active"><a href="#">' + ( page + 1 ) + '</a></li>' );
            } else {
                pages.push( ' <li><a class="search-nav" href="#" data-offset="' + ( page * data.page_size ) + '">' + ( page + 1 ) + '</a></li>' );
            }
        }

        if ( cur_page < max_page ) {
            pages.push( ' <li><a class="search-nav" href="#" data-offset="' + (data.offset + data.page_size) + '">' + _("Next") + ' &raquo;</a></li>' );
        }

        $( '#search-top-pages, #search-bottom-pages' ).find( '.pagination' ).html( pages.length > 1 ? ( '<ul>' + pages.join( '' ) + '</ul>' ) : '' );

        var $overlay = $('#search-overlay');
        $overlay.find('span').text(_("Loading"));
        $overlay.find('.bar').css( { display: 'block', width: 100 * ( 1 - data.activeclients / Search.includedServers.length ) + '%' } );

        if ( data.activeclients ) {
            $overlay.find('.bar').css( { display: 'block', width: 100 * ( 1 - data.activeclients / Search.includedServers.length ) + '%' } );
            $overlay.show();
        } else {
            $overlay.find('.bar').css( { display: 'block', width: '100%' } );
            $overlay.fadeOut();
            $('#searchresults')[0].focus();
        }
    }

    function invalidateSearchResults() {
        var $overlay = $('#search-overlay');
        $overlay.find('span').text(_("Search expired, please try again"));
        $overlay.find('.bar').css( { display: 'none' } );
        $overlay.show();
    }

    function handleSearchError(error) {
        if (error.code == 1) {
            invalidateSearchResults();
            Search.Reconnect();
        } else {
            humanMsg.displayMsg( '<h3>' + _("Internal search error") + '</h3><p>' + error + '</p><p>' + _("Please refresh the page and try again.") + '</p>', { className: 'humanError' } );
        }
    }

    function handleSearchInitError(error) {
        $('#quicksearch-overlay').fadeIn().find('p').text(error);
    }

    // Preference functions
    function showPreference( pref ) {
        var value = Preferences.user[pref];

        switch (pref) {
            case 'enabledBatches':
                $.each( editable_batches, function( batch_id, batch ) {
                    $( '#batches-list li[data-batch-id=' + batch_id + '] input' )[0].checked = Preferences.user.enabledBatches[batch_id];
                    setSaveTargetEnabled( 'batch:' + batch_id + '/', Preferences.user.enabledBatches[batch_id] || false );
                } );
            case 'fieldWidgets':
                $( '#set-field-widgets' ).text( value ? _("Show fields verbatim") : _("Show helpers for fixed and coded fields") );
                break;
            case 'font':
                $( '#editor .CodeMirror' ).css( { fontFamily: value } );
                editor.refresh();
                break;
            case 'fontSize':
                $( '#editor .CodeMirror' ).css( { fontSize: value } );
                editor.refresh();
                break;
            case 'macros':
                // Macros loaded on first show of modal
                break;
            case 'selected_search_targets':
                $.each( z3950Servers, function( server_id, server ) {
                    var saved_val = Preferences.user.selected_search_targets[server_id];

                    if ( saved_val != null ) server.checked = saved_val;
                } );
                break;
            case 'selected_save_targets':
                $.each( state.saveTargets, function( target_id, target ) {
                    var saved_val = Preferences.user.selected_save_targets[target_id];

                    if ( saved_val != null ) setSaveTargetChecked( target_id, saved_val );
                } );
                break;
            case 'selected_search_targets':
                $.each( z3950Servers, function( server_id, server ) {
                    var saved_val = Preferences.user.selected_search_targets[server_id];

                    if ( saved_val != null ) server.checked = saved_val;
                } );
                break;
        }
    }

    function bindPreference( editor, pref ) {
        function _addHandler( sel, event, handler ) {
            $( sel ).on( event, function (e) {
                e.preventDefault();
                handler( e, Preferences.user[pref] );
                Preferences.Save( [% USER_INFO.borrowernumber %] );
                showPreference(pref);
            } );
        }

        function _addLiveHandler( sel, event, handler ) {
            $( document ).on( event, sel, function (e) {
                e.preventDefault();
                handler.call( this, e, Preferences.user[pref] );
                Preferences.Save( [% USER_INFO.0.borrowernumber %] );
                showPreference(pref);
            } );
        }

        switch (pref) {
            case 'enabledBatches':
                _addLiveHandler( '#batches-list input', 'change', function() {
                    Preferences.user.enabledBatches[ $( this ).closest('li').data('batch-id') ] = this.checked;
                } );
                break;
            case 'fieldWidgets':
                _addHandler( '#set-field-widgets', 'click', function( e, oldValue ) {
                    editor.setUseWidgets( Preferences.user.fieldWidgets = !Preferences.user.fieldWidgets );
                } );
                break;
            case 'font':
                _addHandler( '#prefs-menu .set-font', 'click', function( e, oldValue ) {
                    Preferences.user.font = $( e.target ).css( 'font-family' );
                } );
                break;
            case 'fontSize':
                _addHandler( '#prefs-menu .set-fontSize', 'click', function( e, oldValue ) {
                    Preferences.user.fontSize = $( e.target ).css( 'font-size' );
                } );
                break;
            case 'selected_save_targets':
                $( document ).on( 'change', 'input.save-toggle-target', function() {
                    var target_id = $( this ).data('target-id');
                    Preferences.user.selected_save_targets[target_id] = this.checked;
                    Preferences.Save( [% USER_INFO.0.borrowernumber %] );
                } );
                break;
            case 'selected_search_targets':
                $( document ).on( 'change', 'input.search-toggle-server', function() {
                    var server_id = $( this ).closest('li').data('server-id');
                    Preferences.user.selected_search_targets[server_id] = this.checked;
                    Preferences.Save( [% USER_INFO.borrowernumber %] );
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

    //> Macro functions
    function loadMacro( name ) {
        $( '#macro-list li' ).removeClass( 'active' );
        macroEditor.activeMacro = name;

        if ( !name ) {
            macroEditor.setValue( '' );
            return;
        }

        $( '#macro-list li[data-name="' + name + '"]' ).addClass( 'active' );
        var macro = Preferences.user.macros[name];
        macroEditor.setValue( macro.contents );
        macroEditor.setOption( 'readOnly', false );
        $( '#macro-format' ).val( macro.format || 'its' );
        if ( macro.history ) macroEditor.setHistory( macro.history );
    }

    function storeMacro( name, macro ) {
        if ( macro ) {
            Preferences.user.macros[name] = macro;
        } else {
            delete Preferences.user.macros[name];
        }

        Preferences.Save( [% USER_INFO.borrowernumber %] );
    }

    function showSavedMacros( macros ) {
        var scrollTop = $('#macro-list').scrollTop();
        $( '#macro-list' ).empty();
        var macro_list = $.map( Preferences.user.macros, function( macro, name ) {
            return $.extend( { name: name }, macro );
        } );
        macro_list.sort( function( a, b ) {
            return a.name.localeCompare(b.name);
        } );
        $.each( macro_list, function( undef, macro ) {
            var $li = $( '<li data-name="' + macro.name + '"><a href="#">' + macro.name + '</a><ol class="macro-info"></ol></li>' );
            $li.click( function() {
                loadMacro(macro.name);
                return false;
            } );
            if ( macro.name == macroEditor.activeMacro ) $li.addClass( 'active' );
            var modified = macro.modified && new Date(macro.modified);
            $li.find( '.macro-info' ).append(
                '<li><span class="label">' + _("Last changed:") + '</span>' +
                ( modified ? ( modified.toLocaleDateString() + ', ' + modified.toLocaleTimeString() ) : _("never") ) + '</li>'
            );
            $('#macro-list').append($li);
        } );
        var $new_li = $( '<li class="new-macro"><a href="#">' + _("New macro...") + '</a></li>' );
        $new_li.click( function() {
            // TODO: make this a bit less retro
            var name = prompt(_("Please enter the name for the new macro:"));
            if (!name) return;

            if ( !Preferences.user.macros[name] ) storeMacro( name, { format: "rancor", contents: "" } );
            showSavedMacros();
            loadMacro( name );
        } );
        $('#macro-list').append($new_li);
        $('#macro-list').scrollTop(scrollTop);
    }

    function saveMacro() {
        var name = macroEditor.activeMacro;

        if ( !name || macroEditor.savedGeneration == macroEditor.changeGeneration() ) return;

        macroEditor.savedGeneration = macroEditor.changeGeneration();
        storeMacro( name, { contents: macroEditor.getValue(), modified: (new Date()).valueOf(), history: macroEditor.getHistory(), format: $('#macro-format').val() } );
        $('#macro-save-message').text(_("Saved"));
        showSavedMacros();
    }

    function addImportBatch(batch) {
        var backend_id = 'batch:' + batch.batch_id;
        backends[backend_id] = {
            titleForRecord: _("Editing record from batch: ") + batch.name,
            saveLabel: _("Batch: ") + batch.name,
            saveExistingLabel: batch.name + ": #%s",
            get: function( id, callback ) {
                KohaBackend.GetBatchRecord( batch.batch_id, id, function( data ) {
                    if ( !data.error ) {
                        setSaveTargetChecked( backend_id + '/', false );
                        addSaveTarget( {
                            label: batch.name + ": #" + id,
                            id: backend_id + '/' + id,
                            description: '',
                            checked: true
                        } );
                    }

                    callback(data);
                } );
            },
            save: function( id, record, done, options ) {
                function finishCb( data ) {
                    done( {
                        error: data.message || data.error,
                        newRecord: data.updated_record,
                        newId: data.import_record_id && [ backend_id, data.import_record_id ]
                    } );
                }

                if ( id ) {
                    KohaBackend.SaveBatchRecord( batch.batch_id, id, record, finishCb, { allow_control_number_conflict: options.override_warnings } );
                } else {
                    KohaBackend.CreateBatchRecord( record, batch.batch_id, finishCb, { allow_control_number_conflict: options.override_warnings } );
                }
            },
        };

        // Build batch UI
        var $batch_entry = $( '<li data-batch-id="' + batch.batch_id + '"><input type="checkbox" />' + batch.name + '</li>' );

        var $batch_buttons = $('<span class="batch-buttons"></span>').appendTo($batch_entry);
        var $export_button = $( '<button>' + _("Export...") + '</button>' ).appendTo($batch_buttons).click( function() {
            $('#batches-list .batch-export').hide();
            $export_screen.show();
        } );

        var $export_screen = $(
            '<form class="batch-export form-horizontal" style="display: none">'
            + '<div class="control-group">'
            + '<label class="control-label">' + _("Control number range:") + '</label>'
            + '<div class="controls"><input class="batch-control-number-start" type="text"> - <input class="batch-control-number-end" type="text"></div>'
            + '</div>'
            + '<label class="control-label">' + _("Timestamp range (YYYYMMDD or YYYMMDDHHMMSS):") + '</label>'
            + '<div class="controls"><input class="batch-timestamp-start" type="text"> - <input class="batch-timestamp-end" type="text"></div>'
            + '</div>'
            + '<div class="control-group">'
            + '<div class="controls"><button class="batch-export-start">' + _("Start export") + '</div>'
            + '</form>'
        ).appendTo($batch_entry);

        $export_screen.find('.batch-export-start').click( function() {
            function getFormVal(name) {
                return $export_screen.find( '.batch-' + name ).val();
            }

            var options = {
                start_control_number: getFormVal('control-number-start'),
                end_control_number: getFormVal('control-number-end'),
                start_timestamp: getFormVal('timestamp-start'),
                end_timestamp: getFormVal('timestamp-end'),
            };

            KohaBackend.StartBatchExport( batch.batch_id, options );
        } );

        $('#batches-list').append( $batch_entry );
    }

    $(document).ready( function() {
        // Editor setup
        editor = new MARCEditor( {
            onCursorActivity: function() {
                $('#status-tag-info').empty();
                $('#status-subfield-info').empty();

                var field = editor.getCurrentField();
                var cur = editor.getCursor();

                if ( !field ) return;

                var taginfo = KohaBackend.GetTagInfo( '', field.tag );
                $('#status-tag-info').html( '<strong>' + field.tag + ':</strong> ' );

                if ( taginfo ) {
                    $('#status-tag-info').append( '<a href="' + getFieldHelpURL( field.tag ) + '" target="_blank" class="show-field-help" title="' + _("Show help for this tag") + '">[?]</a> '  + taginfo.lib );

                    var subfield = field.getSubfieldAt( cur.ch );
                    if ( !subfield ) return;

                    var subfieldinfo = taginfo.subfields[ subfield.code ];
                    $('#status-subfield-info').html( '<strong>‡' + subfield.code + ':</strong> ' );

                    if ( subfieldinfo ) {
                        $('#status-subfield-info').append( subfieldinfo.lib );
                    } else {
                        $('#status-subfield-info').append( '<em>' + _("Unknown subfield") + '</em>' );
                    }
                } else {
                    $('#status-tag-info').append( '<em>' + _("Unknown tag") + '</em>' );
                }
            },
            position: function (elt) { $(elt).insertAfter('#toolbar') },
        } );

        // Automatically detect resizes and change the height of the editor and position of modals.
        var resizeTimer = null;
        function onResize() {
            if ( resizeTimer == null ) resizeTimer = setTimeout( function() {
                resizeTimer = null;

                var pos = $('#editor .CodeMirror').position();
                $('#editor .CodeMirror').height( $(window).height() - pos.top - 24 - $('#changelanguage').height() ); // 24 is hardcoded value but works well

                $('.modal-body').each( function() {
                    $(this).height( $(window).height() * .8 - $(this).prevAll('.modal-header').height() );
                } );
            }, 100);

            $(".ui-modal").css( {
                marginLeft: function() {
                    return -($(this).width() / 2);
                }
            } );
        }

        $( '#macro-ui' ).on( 'shown', function() {
            if ( macroEditor ) return;

            macroEditor = CodeMirror(
                $('#macro-editor')[0],
                {
                    extraKeys: {
                        'Ctrl-D': function( cm ) {
                            var cur = cm.getCursor();

                            cm.replaceRange( "‡", cur, null );
                        },
                    },
                    mode: 'null',
                    lineNumbers: true,
                    readOnly: true,
                }
            );
            var saveTimeout;
            macroEditor.on( 'change', function( cm, change ) {
                $('#macro-save-message').empty();
                if ( change.origin == 'setValue' ) return;

                if ( saveTimeout ) clearTimeout( saveTimeout );
                saveTimeout = setTimeout( function() {
                    saveMacro();

                    saveTimeout = null;
                }, 500 );
            } );

            showSavedMacros();
        } );

        var saveableBackends = [];
        $.each( backends, function( id, backend ) {
            if ( backend.save ) saveableBackends.push( [ backend.saveLabel, id ] );
        } );

        var batch_list = [];

        $.each( editable_batches, function( batch_id, batch ) {
            batch_list.push( $.extend( { batch_id: batch_id }, batch ) );
        } );
        batch_list.sort( function( a, b ) {
            return a.name.localeCompare(b.name);
        } );
        $.each( batch_list, function() {
            addImportBatch( this );
        } );

        var macro_format_list = $.map( Macros.formats, function( format, name ) {
            return $.extend( { name: name }, format );
        } );
        macro_format_list.sort( function( a, b ) {
            return a.description.localeCompare(b.description);
        } );
        $.each( macro_format_list, function() {
            $('#macro-format').append( '<option value="' + this.name + '">' + this.description + '</option>' );
        } );

        // Click bindings
        $( '#save-record, #save-dropdown a' ).click( function() {
            var enabledTargets = [];
            var targetNames = [];
            $.each( state.saveTargets, function() {
                if ( this.checked ) {
                    enabledTargets.push(this);
                    targetNames.push(this.label);
                }
            } );
            if ( enabledTargets.length == 0 ) {
                humanMsg.displayAlert( _("Please select a save target"), { className: 'humanError' } );
                return false;
            }

            $( '#save-record' ).find('i').attr( 'class', 'icon-loading' ).siblings( 'span' ).text( _("Saving...") );

            var targets_left = enabledTargets.length;
            var errors = false;

            function finishCb(result) {
                targets_left--;
                if ( result.error ) {
                    if ( result.error == 'syntax' ) {
                        humanMsg.displayAlert( _("Incorrect syntax, cannot save"), { className: 'humanError' } );
                    } else if ( result.error == 'invalid' ) {
                        humanMsg.displayAlert( _("Record structure invalid, cannot save"), { className: 'humanError' } );
                    } else if ( result.error.type == 'control_number_match' ) {
                        humanMsg.displayAlert( _("Control number conflict, cannot save"), { className: 'humanError' } );
                    } else {
                        humanMsg.displayAlert( _("Unknown error, record not saved to one or more targets"), { className: 'humanError' } );
                    }
                    errors = true;
                }

                $.each( result.errors || [], function( undef, error ) {
                    switch ( error.type ) {
                        case 'noTag':
                            editor.addError( error.line, _("Invalid tag number") );
                            break;
                        case 'noIndicators':
                            editor.addError( error.line, _("Invalid indicators") );
                            break;
                        case 'noSubfields':
                            editor.addError( error.line, _("Tag has no subfields") );
                            break;
                        case 'missingTag':
                            editor.addError( null, _("Missing mandatory tag: ") + error.tag );
                            break;
                        case 'missingSubfield':
                            if ( error.subfield == '@' ) {
                                editor.addError( error.line, _("Missing control field contents") );
                            } else {
                                editor.addError( error.line, _("Missing mandatory subfield: ‡") + error.subfield );
                            }
                            break;
                        case 'unrepeatableTag':
                            editor.addError( error.line, _("Tag ") + error.tag + _(" cannot be repeated") );
                            break;
                        case 'unrepeatableSubfield':
                            editor.addError( error.line, _("Subfield ‡") + error.subfield + _(" cannot be repeated") );
                            break;
                        case 'itemTagUnsupported':
                            editor.addError( error.line, _("Item tags cannot currently be saved") );
                            break;
                    }
                } );


                if ( targets_left == 0 ) {
                    if ( !errors ) {
                        humanMsg.displayMsg( "<h3>" + _("Record saved to:</h3>") + "</h3>" + '<ul><li>' + targetNames.join('</li><li>') + '</li></ul>', { className: 'humanSuccess' } );
                    }

                    $( '#save-record' ).find('i').attr( 'class', 'icon-hdd' ).end().find('span').text( _("Save") );
                }
            }

            $.each( enabledTargets, function() {
                saveRecord( this.id, editor, finishCb, options );
            } );

            return false;
        } );

        $('#import-records').click( function() {
            $('#import-records-input')
                .off('change')
                .change( function() {
                    if ( !this.files || !this.files.length ) return;

                    var file = this.files[0];
                    var reader = new FileReader();

                    reader.onload = function() {
                        var record = new MARC.Record();

                        if ( /\.(mrc|marc|iso|iso2709|marcstd)$/.test( file.name ) ) {
                            record.loadISO2709( reader.result );
                        } else if ( /\.(xml|marcxml)$/.test( file.name ) ) {
                            record.loadMARCXML( reader.result );
                        } else {
                            humanMsg.displayAlert( _("Unknown record type, cannot import"), { className: 'humanError' } );
                            return;
                        }

                        if (record.marc8_corrupted) humanMsg.displayMsg( '<h3>' + _("Possible record corruption") + '</h3><p>' + _("Record not marked as UTF-8, may be corrupted") + '</p>', { className: 'humanError' } );

                        editor.displayRecord( record );
                    };

                    reader.readAsText( file );
                } )
                .click();

            return false;
        } );

        $('#open-macros').click( function() {
            $('#macro-ui').modal('show');

            return false;
        } );

        $('#run-macro').click( function() {
            var result = Macros.Run( editor, $('#macro-format').val(), macroEditor.getValue() );

            if ( !result.errors.length ) {
                $('#macro-ui').modal('hide');
                return false;
            }

            var errors = [];
            $.each( result.errors, function() {
                var error = '<b>' + _("Line ") + (this.line + 1) + ':</b> ';

                switch ( this.error ) {
                    case 'failed': error += _("failed to run"); break;
                    case 'unrecognized': error += _("unrecognized command"); break;
                }

                errors.push(error);
            } );

            humanMsg.displayMsg( '<h3>' + _("Failed to run macro:") + '</h3><ul><li>' + errors.join('</li><li>') + '</li></ul>', { className: 'humanError' } );

            return false;
        } );

        $('#delete-macro').click( function() {
            if ( !macroEditor.activeMacro || !confirm( _("Are you sure you want to delete this macro?") ) ) return;

            storeMacro( macroEditor.activeMacro, undefined );
            showSavedMacros();
            loadMacro( undefined );

            return false;
        } );

        $( '#switch-editor' ).click( function() {
            if ( !confirm( _("Any changes will not be saved. Continue?") ) ) return;

            $.cookie( 'catalogue_editor_[% USER_INFO.borrowernumber %]', 'basic', { expires: 365, path: '/' } );

            if ( state.backend == 'catalog' ) {
                window.location = '/cgi-bin/koha/cataloguing/addbiblio.pl?biblionumber=' + state.recordID;
            } else if ( state.backend == 'new' ) {
                window.location = '/cgi-bin/koha/cataloguing/addbiblio.pl';
            } else {
                humanMsg.displayAlert( _("Cannot open this record in the basic editor"), { className: 'humanError' } );
            }
        } );

        $( '#show-advanced-search' ).click( function() {
            showAdvancedSearch();

            return false;
        } );

        $('#advanced-search').submit( function() {
            startAdvancedSearch();

            return false;
        } );

        $( document ).on( 'click', 'a.search-nav', function() {
            if ( Search.Fetch( { offset: $( this ).data( 'offset' ) } ) ) {
                $("#search-overlay").show();
            }

            return false;
        });

        $( document ).on( 'click', 'th[data-sort-label]', function() {
            var direction;

            if ( $( this ).hasClass( 'sorting_asc' ) ) {
                direction = 'desc';
            } else {
                direction = 'asc';
            }

            if ( Search.Fetch( { sort_key: $( this ).data( 'sort-label' ), sort_direction: direction } ) ) {
                showSearchSorting( $( this ).data( 'sort-label' ), direction );

                $("#search-overlay").show();
            }

            return false;
        });

        $( document ).on( 'change', 'input.search-toggle-server', function() {
            var server = z3950Servers[ $( this ).closest('li').data('server-id') ];
            server.checked = this.checked;

            if ( $('#search-results-ui').is( ':visible' ) && Search.Fetch() ) {
                $("#search-overlay").show();
            }
        } );

        $('#open-batches').click( function() {
            $('#batches-ui').modal();

            return false;
        } );

        $('#create-batch').click( function() {
            var batch_name = prompt( _("Name of new import batch:") );
            if (batch_name == null) return false;

            KohaBackend.CreateBatch( batch_name, function( data ) {
                if ( data.error ) {
                    humanMsg.displayAlert( _("Could not create import batch"), { className: 'humanError' } );
                } else {
                    humanMsg.displayAlert( _("Import batch created"), { className: 'humanSuccess' } );

                    addImportBatch( editable_batches[data.batch_id] = { batch_id: data.batch_id, name: batch_name } );

                    var backend_id = 'batch:' + data.batch_id;
                    addSaveTarget( {
                        label: backends[backend_id].saveLabel,
                        id: backend_id + '/',
                        description: '',
                        enabled: false,
                    } );
                }
            } );

            return false;
        } );

        $('#manage-batches').click( function() {
            window.open('/cgi-bin/koha/tools/manage-marc-import.pl');

            return false;
        } );

        // Key bindings
        bindGlobalKeys();

        // Setup UI
        $(".ui-modal").each( function() {
            $(this).modal({ show: false });
        } );

        var $quicksearch = $('#quicksearch fieldset');
        $('<div id="quicksearch-overlay"><h3>' + _("Search unavailable") + '</h3> <p></p></div>').css({
            position: 'absolute',
            top: $quicksearch.offset().top,
            left: $quicksearch.offset().left,
            height: $quicksearch.outerHeight(),
            width: $quicksearch.outerWidth(),
        }).appendTo(document.body).hide();

        var prevAlerts = [];
        humanMsg.logMsg = function(msg, options) {
            $('#show-alerts').popover('hide');
            prevAlerts.unshift('<li>' + msg + '</li>');
            prevAlerts.splice(5, 999); // Truncate old messages
        };

        $('#show-alerts').popover({
            html: true,
            placement: 'bottom',
            content: function() {
                return '<div id="alerts-container"><ul>' + prevAlerts.join('') + '</ul></div>';
            },
        });

        $('#show-shortcuts').popover({
            html: true,
            placement: 'bottom',
            content: function() {
                return '<div id="shortcuts-container">' + $('#shortcuts-contents').html() + '</div>';
            },
        });

        $('#new-record' ).click( function() {
            if ( editor.modified && !confirm( _("Are you sure you want to erase your changes?") ) ) return;

            openRecord( 'new/', editor );
            return false;
        } );

        $.each( backends, function( name ) {
            if ( !this.save ) return; // Not a saving backend

            addSaveTarget( {
                label: this.saveLabel,
                id: name + '/',
                description: '',
            } );
        } );

        // Start editor
        Preferences.Load( [% USER_INFO.borrowernumber || 0 %] );
        displayPreferences(editor);
        makeAuthorisedValueWidgets( '' );
        Search.Init( {
            page_size: 20,
            onresults: function(data) { showSearchResults( editor, data ) },
            onerror: handleSearchError,
        } );

        function finishCb( data ) {
            if ( data.error ) openRecord( 'new/', editor, finishCb );

            Resources.GetAll().done( function() {
                $("#loading").hide();
                $( window ).resize( onResize ).resize();
                editor.focus();
            } );
        }

        if ( "[% auth_forwarded_hash %]" ) {
            document.location.hash = "[% auth_forwarded_hash %]";
        }

        if ( !document.location.hash || !openRecord( document.location.hash.slice(1), editor, finishCb ) ) {
            openRecord( 'new/', editor, finishCb );
        }
    } );
} )();

</script>
