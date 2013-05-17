if ( typeof KOHA == "undefined" || !KOHA ) {
    var KOHA = {};
}

KOHA.OverDrive = ( function() {
    var proxy_base_url = '/cgi-bin/koha/svc/overdrive_proxy';
    var library_base_url = 'http://api.overdrive.com/v1/libraries/';
    function _get( url, params, callback ) {
        $.ajax({
            type: 'GET',
            url: url.replace(/https?:\/\/api.overdrive.com\/v1/, proxy_base_url),
            dataType: 'json',
            data: params,
            success: callback
        });
    }

    return {
        GetCollectionURL: function( library_id, callback ) {
            _get(
                library_base_url + library_id,
                {},
                function (data) {
                    callback(data.links.products.href);
                }
            );
        },
        Search: function( library_id, q, callback ) {
            KOHA.OverDrive.GetCollectionURL( library_id, function( collection_url ) {
                _get(
                    collection_url,
                    {q: q},
                    callback
                );
            } );
        }
    };
} )();
