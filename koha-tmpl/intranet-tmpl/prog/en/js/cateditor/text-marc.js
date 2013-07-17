define( function() {
    return {
        RecordToText: function( record ) {
            var lines = [];
            var fields = record.fields();

            for ( var i = 0; i < fields.length; i++ ) {
                var field = fields[i];

                if ( field.isControlField() ) {
                    lines.push( field.tagnumber() + ' ' + field.subfield( '@' ) );
                } else {
                    var result = [ field.tagnumber() + ' ' ];

                    result.push( field.indicator(0) == ' ' ? '_' : field.indicator(0), ' ' );
                    result.push( field.indicator(1) == ' ' ? '_' : field.indicator(1), ' ' );

                    $.each( field.subfields(), function( i, subfield ) {
                        result.push( '$' + subfield[0] + ' ' + subfield[1] );
                    } );

                    lines.push( result.join('') );
                }
            }

            return lines.join('\n');
        }
    };
} );
