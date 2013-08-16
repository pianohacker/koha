define( [ 'marc-record', 'pz2' ], function( MARC, Pazpar2 ) {
    function _transformToFragment( xmlDoc, xslDoc ) {
        if ( window.XSLTProcessor ) {
            var proc = new XSLTProcessor();
            proc.importStylesheet( xslDoc );
            proc.setParameter( null, 'showAvailability', false );
            return (new XMLSerializer).serializeToString( proc.transformToFragment( xmlDoc, document ) );
        } else if ( window.ActiveXObject ) {
            var xslt = new ActiveXObject( "Msxml2.XSLTemplate" );
            xslt.stylesheet = xslDoc;
            var xslProc = xslt.createProcessor();
            xslProc.input = xmlDoc;
            xslProc.addParameter( 'showAvailability', false );
            xslProc.transform();
            return xslProc.output;
        } else {
            alert( 'Unable to perform XSLT transformation in this browser' );
        }
    };

    var _pz;

    var Search = {
        Init: function( targets, options ) {
            var initOpts = {};

            $.each( targets, function ( url, info ) {
                initOpts[ 'pz:name[' + url + ']' ] = info.name;
                initOpts[ 'pz:queryencoding[' + url + ']' ] = info.encoding;
                initOpts[ 'pz:xslt[' + url + ']' ] = ( info.syntax == 'USMARC' ? 'marc21' : info.syntax.toLowerCase() ) + '-work-groups.xsl';
                initOpts[ 'pz:requestsyntax[' + url + ']' ] = info.syntax;
                if ( info.authentication ) initOpts[ 'pz:authentication[' + url + ']' ] = info.authentication;
            } );

            _pz = new Pazpar2( $.extend( {
                initopts: initOpts,
                errorhandler: function ( error ) { callback( { error: error } ) },
            }, options ) );
        },
        Start: function( targets, q, limit ) {
            var includedTargets = [];

            $.each( targets, function ( url, info ) {
                if ( !info.disabled ) includedTargets.push( url );
            } );

            _pz.search( q, limit, 'relevance:0', 'pz:id=' + includedTargets.join( '|' ) );
        },
        Fetch: function( offset ) {
            _pz.show( offset );
        },
        GetDetailedRecord: function( recid, callback ) {
            _pz.record( recid, 0, undefined, { callback: function(data) {
                var record = new MARC.Record();
                record.loadMARCXML(data.xmlDoc);

                callback(record);
            } } );
        },
    };

    return Search;
} );
