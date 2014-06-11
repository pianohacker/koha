define( [ 'marc-record' ], function( MARC ) {
    var _options;
    var _records = {};
    var _last;

    var _pqfMapping = {
        author: '1=1004', // s=al',
        cn_dewey: '1=13',
        cn_lc: '1=16',
        date: '1=30', // r=r',
        isbn: '1=7',
        issn: '1=8',
        lccn: '1=9',
        local_number: '1=12',
        music_identifier: '1=51',
        standard_identifier: '1=1007',
        subject: '1=21', // s=al',
        term: '1=1016', // t=l,r s=al',
        title: '1=4', // s=al',
    }

    var Search = {
        Init: function( options ) {
            _options = options;
        },
        JoinTerms: function( terms ) {
            var q = '';

            $.each( terms, function( i, term ) {
                var term = '@attr ' + _pqfMapping[ term[0] ] + ' "' + term[1].replace( '"', '\\"' ) + '"'

                if ( q ) {
                    q = '@and ' + q + ' ' + term;
                } else {
                    q = term;
                }
            } );

            return q;
        },
        Run: function( servers, q, options ) {
            options = $.extend( {
                offset: 0,
                page_size: 20,
            }, _options, options );

            Search.includedServers = [];
            _records = {};
            _last = {
                servers: servers,
                q: q,
                options: options,
            };

            $.each( servers, function ( id, info ) {
                if ( info.checked ) Search.includedServers.push( id );
            } );

            $.get(
                '/cgi-bin/koha/svc/cataloguing/metasearch',
                {
                    q: q,
                    servers: Search.includedServers.join( ',' ),
                    offset: options.offset,
                    page_size: options.page_size,
                    sort_direction: options.sort_direction,
                    sort_key: options.sort_key,
                    resultset: options.resultset,
                }
            )
                .done( function( data ) {
                    _last.options.resultset = data.resultset;
                    $.each( data.hits, function( undef, hit ) {
                        var record = new MARC.Record();
                        record.loadMARCXML( hit.record );
                        hit.record = record;
                    } );

                    _options.onresults( data );
                } )
                .fail( function( error ) {
                    _options.onerror( error );
                } );

            return true;
        },
        Fetch: function( options ) {
            if ( !_last ) return;
            $.extend( _last.options, options );
            Search.Run( _last.servers, _last.q, _last.options );
        }
    };

    return Search;
} );
