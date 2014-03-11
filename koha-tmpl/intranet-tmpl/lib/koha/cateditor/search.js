define( [ 'marc-record', 'pz2' ], function( MARC, Pazpar2 ) {
    //var _pz;
    var _onresults;
    var _recordCache = {};
    var _options;

    var Search = {
        Init: function( targets, options ) {
            var initOpts = {};

            $.each( targets, function ( url, info ) {
                initOpts[ 'pz:name[' + url + ']' ] = info.name;
                initOpts[ 'pz:queryencoding[' + url + ']' ] = info.encoding;
                initOpts[ 'pz:xslt[' + url + ']' ] = info.kohasyntax.toLowerCase() + '-work-groups.xsl';
                initOpts[ 'pz:requestsyntax[' + url + ']' ] = info.syntax;

                // Load in default CCL mappings
                // Pazpar2 seems to have a bug where wildcard cclmaps are ignored.
                // What an incredible surprise.
                initOpts[ 'pz:cclmap:term[' + url + ']' ] = 'u=1016 t=l,r s=al';
                initOpts[ 'pz:cclmap:Author-name[' + url + ']' ] = 'u=1004 s=al';
                initOpts[ 'pz:cclmap:Classification-Dewey[' + url + ']' ] = 'u=13';
                initOpts[ 'pz:cclmap:Classification-LC[' + url + ']' ] = 'u=16';
                initOpts[ 'pz:cclmap:Date[' + url + ']' ] = 'u=30 r=r';
                initOpts[ 'pz:cclmap:Identifier-ISBN[' + url + ']' ] = 'u=7';
                initOpts[ 'pz:cclmap:Identifier-ISSN[' + url + ']' ] = 'u=8';
                initOpts[ 'pz:cclmap:Identifier-publisher-for-music[' + url + ']' ] = 'u=51';
                initOpts[ 'pz:cclmap:Identifier-standard[' + url + ']' ] = 'u=1007';
                initOpts[ 'pz:cclmap:LC-card-number[' + url + ']' ] = 'u=9';
                initOpts[ 'pz:cclmap:Local-number[' + url + ']' ] = 'u=12';
                initOpts[ 'pz:cclmap:Subject[' + url + ']' ] = 'u=21 s=al';
                initOpts[ 'pz:cclmap:Title[' + url + ']' ] = 'u=4 s=al';

                if ( info.authentication ) initOpts[ 'pz:authentication[' + url + ']' ] = info.authentication;
            } );

            _options =  $.extend( {
                initopts: initOpts,
                onshow: Search._onshow,
                errorhandler: Search._onerror,
            }, options );

            _pz = new Pazpar2( _options );
        },
        Reconnect: function() {
            _pz.reset();
            _pz = new Pazpar2( _options );
        },
        Start: function( targets, q, limit ) {
            Search.includedTargets = [];
            recordcache = {};

            $.each( targets, function ( url, info ) {
                if ( !info.disabled ) Search.includedTargets.push( url );
            } );

            _pz.search( q, limit, 'relevance:0', 'pz:id=' + Search.includedTargets.join( '|' ) );
            return true;
        },
        Fetch: function( offset ) {
            _pz.show( offset );
        },
        GetDetailedRecord: function( recid, callback ) {
            if ( _recordCache[recid] ) {
                callback( _recordCache[recid] );
                return;
            }

            _pz.record( recid, 0, undefined, { callback: function(data) {
                var record = _recordCache[recid] = new MARC.Record();
                record.loadMARCXML(data.xmlDoc);

                callback(record);
            } } );
        },
        IsAvailable: function() {
            return _pz.initStatusOK;
        },
        _onshow: function( data ) {
            $.each( data.hits, function( undef, hit ) {
                hit.id = 'search:' + encodeURIComponent( hit.recid[0] );
            } );

            _options.onresults( data );
        },
        _onerror: function( error ) {
            if ( _options.oniniterror && !_pz.initStatusOK ) {
                _options.oniniterror( error );
            } else {
                _options.onerror( error );
            }
        }
    };

    return Search;
} );
