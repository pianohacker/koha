define( [ 'marc-record' ], function( MARC ) {
    var _frameworks = {};
    var _framework_mappings = {};

    function _fromXMLStruct( data ) {
        result = {};

        $(data).children().eq(0).children().each( function() {
            var $contents = $(this).contents();
            if ( $contents.length == 1 && $contents[0].nodeType == Node.TEXT_NODE ) {
                result[ this.localName ] = $contents[0].data;
            } else {
                result[ this.localName ] = $contents.toArray();
            }
        } );

        return result;
    }

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

        GetAllTagsInfo: function( frameworkcode, tagnumber ) {
            return _framework_mappings[frameworkcode];
        },

        GetTagInfo: function( frameworkcode, tagnumber ) {
            if ( !_framework_mappings[frameworkcode] ) return undefined;
            return _framework_mappings[frameworkcode][tagnumber];
        },

        GetRecord: function( id, callback ) {
            $.get(
                '/cgi-bin/koha/svc/bib/' + id
            ).done( function( data ) {
                var record = new MARC.Record();
                record.loadMARCXML(data);
                callback(record);
            } ).fail( function( data ) {
                alert('Record load failed.');
            } );
        },

        CreateRecord: function( record, callback ) {
            console.log( record );
            $.ajax( {
                type: 'POST',
                url: '/cgi-bin/koha/svc/new_bib',
                data: record.toXML(),
                contentType: 'text/xml'
            } ).done( function( data ) {
                callback( _fromXMLStruct( data ) );
            } ).fail( function( data ) {
                alert('Record save failed.');
            } );
        },

        SaveRecord: function( id, record, callback ) {
            console.log( record );
            $.ajax( {
                type: 'POST',
                url: '/cgi-bin/koha/svc/bib/' + id,
                data: record.toXML(),
                contentType: 'text/xml'
            } ).done( function( data ) {
                callback( _fromXMLStruct( data ) );
            } ).fail( function( data ) {
                alert('Record save failed.');
            } );
        },

        FillRecord: function( frameworkcode, record, allTags ) {
            $.each( _frameworks[frameworkcode], function( _, tag ) {
                var tagnum = tag[0], taginfo = tag[1];

                if ( taginfo.mandatory != "1" && !allTags ) return;

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

                    if ( subfieldinfo.mandatory != "1" && !allTags ) return;

                    $.each( fields, function( _, field ) {
                        if ( !field.hasSubfield(subfieldcode) ) field.addSubfieldGrouped( [ subfieldcode, '' ] );
                    } );
                } );
            } );
        },
    };
} );
