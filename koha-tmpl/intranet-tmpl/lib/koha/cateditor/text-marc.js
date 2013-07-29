define( [ 'marc-record' ], function( MARC ) {
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
        },

        TextToRecord: function( text ) {
            var record = new MARC.Record();

            $.each( text.split('\n'), function( _, line ) {
                var tagNumber = line.match( /^([A-Za-z0-9]{3}) / );

                if ( !tagNumber ) {
                    record = null;
                    return false;
                }
                tagNumber = tagNumber[1];

                if ( tagNumber < '010' ) {
                    var field = new MARC.Field( tagNumber, ' ', ' ', [ [ '@', line.substring( 4 ) ] ] );
                    record.addField( field );
                } else {
                    var indicators = line.match( /^... ([0-9A-Za-z_]) ([0-9A-Za-z_])/ );
                    if ( !indicators ) {
                        record = null;
                        return false;
                    }

                    var field = new MARC.Field( tagNumber, ( indicators[1] == '_' ? ' ' : indicators[1] ), ( indicators[2] == '_' ? ' ' : indicators[2] ), [] );

                    var matcher = /[$|ǂ‡]([a-z0-9%]) /g;
                    var match;

                    var subfields = [];

                    while ( ( match = matcher.exec(line) ) ) {
                        subfields.push( { code: match[1], ch: match.index } );
                    }

                    $.each( subfields, function( i, subfields ) {
                        var next = subfields[ i + 1 ];

                        field.addSubfield( [ subfields.code, line.substring( subfields.ch + 3, next ? next.ch : line.length ) ] );
                    } );

                    record.addField( field );
                }
            } );

            return record;
        }
    };
} );
