define( [ 'module' ], function( module ) {
    var _allResources = [];

    var Resources = {
        GetAll: function() {
            return $.when.call( null, _allResources );
        }
    };

    function _res( name, deferred ) {
        Resources[name] = deferred;
        _allResources.push(deferred);
    }

    _res( 'marc21/xml/006', $.get( module.config().themelang + '/data/marc21_field_006.xml' ) );
    _res( 'marc21/xml/008', $.get( module.config().themelang + '/data/marc21_field_008.xml' ) );

    return Resources;
} );
