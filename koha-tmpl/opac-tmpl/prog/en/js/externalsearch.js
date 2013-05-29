if ( typeof KOHA == "undefined" || !KOHA ) {
    var KOHA = {};
}

KOHA.XSLTGet = ( function() {
    // Horrible browser hack, but required due to the following hard-to-detect and long-unfixed bug:
    // https://bugs.webkit.org/show_bug.cgi?id=60276
    var isChrome = /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor);
    var isSafari = /Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor);

    if ( !isChrome && !isSafari ) return $.get;

    return function( url ) {
        var result = new jQuery.Deferred();
        var basepath = url.match( /(.*\/)*/ )[0];

        $.get( url ).done( function( xslDoc ) {
            var xslImports = xslDoc.getElementsByTagNameNS( 'http://www.w3.org/1999/XSL/Transform', 'import' );
            var importsRemaining = xslImports.length;

            if ( importsRemaining == 0 ) {
                result.resolve( xslDoc );
                return;
            }

            $.each( xslImports, function( i, importElem ) {
                var path = $( importElem ).attr( 'href' );
                if ( !/^(\/|https?:)/.test( path ) ) path = basepath + path;

                KOHA.XSLTGet( path ).done( function( subDoc ) {
                    importsRemaining--;
                    $( importElem ).replaceWith( subDoc.documentElement.childNodes );

                    if ( importsRemaining == 0 ) result.resolve( xslDoc );
                } ).fail( function() {
                    importsRemaining = -1;

                    result.reject();
                } );
            } );
        } ).fail( function() {
            result.reject();
        } );

        return result;
    };
} )();

KOHA.TransformToFragment = function( xmlDoc, xslDoc ) {
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
    }
};

KOHA.ExternalSearch = ( function() {
    return {
        targets: {},
        Search: function( q, limit, callback ) {
            var targetIDs = [];
            var includedTargets = [];

            $.each( KOHA.ExternalSearch.targets, function ( url, info ) {
                if ( !info.disabled ) {
                    includedTargets.push( url );
                    targetIDs.push( info.id );
                }
            } );

            if ( KOHA.ExternalSearch._pz !== undefined ) {
                afterinit( KOHA.ExternalSearch._pz );
            } else {
                $.get( '/cgi-bin/koha/svc/pazpar2_init', { targets: targetIDs.join(',') }, function( data ) {
                    KOHA.ExternalSearch._pz = new pz2({
                        sessionId: data.sessionID,
                        onshow: callback,
                        errorhandler: function ( error ) { callback( { error: error } ) },
                    } );
                    afterinit( KOHA.ExternalSearch._pz );
                } );
            }

            function afterinit( pz ) {
                pz.search( q, limit, 'relevance:0', 'pz:id=' + includedTargets.join( '|' ) );
            }
        },
        Fetch: function( offset, callback ) {
            var pz = KOHA.ExternalSearch._pz;
            pz.showCallback = callback;
            pz.show( offset );
        },
        GetDetailedRecord: function( recid, callback ) {
            KOHA.ExternalSearch._pz.record( recid, 0, undefined, { callback: callback } );
        },
    };
} )();
