define( [ 'marc-record', 'pz2' ], function( MARC, Pazpar2 ) {
    var _pz;
    var _onresults;
    var _recordCache = {};

    var Search = {
        Init: function( targets, options ) {
            var initOpts = {};

            _onresults = options.onresults;

            $.each( targets, function ( url, info ) {
                initOpts[ 'pz:name[' + url + ']' ] = info.name;
                initOpts[ 'pz:queryencoding[' + url + ']' ] = info.encoding;
                initOpts[ 'pz:xslt[' + url + ']' ] = info.kohasyntax.toLowerCase() + '-work-groups.xsl';
                initOpts[ 'pz:requestsyntax[' + url + ']' ] = info.syntax;

                // Load in default CCL mappings
                initOpts[ 'pz:cclmap:au['  + url + ']' ] = 'u=1004 s=al';
                initOpts[ 'pz:cclmap:ti['  + url + ']' ] = 'u=4 s=al';
                initOpts[ 'pz:cclmap:su['  + url + ']' ] = 'u=21 s=al';
                initOpts[ 'pz:cclmap:isbn['  + url + ']' ] = 'u=7';
                initOpts[ 'pz:cclmap:issn['  + url + ']' ] = 'u=8';
                initOpts[ 'pz:cclmap:date['  + url + ']' ] = 'u=30 r=r';

                if ( info.authentication ) initOpts[ 'pz:authentication[' + url + ']' ] = info.authentication;
            } );

            _pz = new Pazpar2( $.extend( {
                initopts: initOpts,
                onshow: Search._onshow,
                errorhandler: function ( error ) { callback( { error: error } ) },
            }, options ) );
        },
        Start: function( targets, q, limit ) {
            var includedTargets = [];
            recordcache = {};

            $.each( targets, function ( url, info ) {
                if ( !info.disabled ) includedTargets.push( url );
            } );

            _pz.search( q, limit, 'relevance:0', 'pz:id=' + includedTargets.join( '|' ) );
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
        _onshow: function( data ) {
            $.each( data.hits, function( undef, hit ) {
                hit.id = 'search:' + encodeURIComponent( hit.recid[0] );
            } );

            _onresults( data );
        },
    };

    return Search;
} );
