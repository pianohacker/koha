define( function() {
    var XSLT = {
        TransformToFragment: function( xmlDoc, xslDoc ) {
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
                return null;
            }
        },

        Get: ( function() {
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

                        XSLT.Get( path ).done( function( subDoc ) {
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
        } )(),
    };

    return XSLT;
} );
