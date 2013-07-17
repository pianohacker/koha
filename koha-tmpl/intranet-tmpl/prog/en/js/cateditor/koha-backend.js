define( [ 'marc-record' ], function( MARC ) {
    var _frameworks = {};
    var _framework_mappings = {};

    function _importFramework( frameworkcode, frameworkinfo ) {
        _frameworks[frameworkcode] = frameworkinfo;
        _framework_mappings[frameworkcode] = {};

        $.each( frameworkinfo, function( i, tag ) {
            var tagnum = tag[0], taginfo = tag[1];

            var subfields = {};

            $.each( taginfo.subfields, function( i, subfield ) {
                subfields[ subfield[0] ] = subfield[1];
            } );

            _framework_mappings[frameworkcode][tagnum] = $.extend( {}, taginfo, { subfields: subfields } );
        } );
    }

    return {
        SetDefaultFramework: function( frameworkinfo ) {
            _importFramework( '', frameworkinfo );
        },
        FillRecord: function( frameworkcode, record ) {
            $.each( _frameworks[frameworkcode], function( _, tag ) {
                var tagnum = tag[0], taginfo = tag[1];

                if ( !taginfo.mandatory ) return;

                var fields = record.fields(tagnum);

                if ( fields.length == 0 ) {
                    var newField = new MARC.Field( tagnum, ' ', ' ', [] );
                    fields.push( newField );
                    record.addFieldGrouped( newField );

                    if ( tagnum < '010' ) {
                        newField.addSubfield( [ '@', '' ] );
                        return;
                    }
                }

                $.each( taginfo.subfields, function( _, subfield ) {
                    var subfieldcode = subfield[0], subfieldinfo = subfield[1];

                    if ( !subfieldinfo.mandatory ) return;

                    $.each( fields, function( _, field ) {
                        if ( !field.hasSubfield(subfieldcode) ) field.addSubfieldGrouped( [ subfieldcode, '' ] );
                    } );
                } );
            } );
        },
    };
} );
