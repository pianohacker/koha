if ( typeof KOHA == "undefined" || !KOHA ) {
    var KOHA = {};
}

KOHA.OverDrive = ( function() {
    var library_base_url = 'https://api.overdrive.com/v1/libraries/';
    function _oauth_get( url, params, callback ) {
        $.ajax({
            type: 'GET',
            url: url,
            dataType: 'json',
            params: params,
            beforeSend: function(xhr) {
                xhr.setRequestHeader('Authorization', KOHA.OverDrive.token);
            },
            success: callback
        });
    }

    return {
        GetCollectionURL: function( library_id, callback ) {
            _oauth_get(
                library_base_url + library_id,
                {},
                function (data) {
                    callback(data.links.products.href);
                }
            );
        },
        Search: function( library_id, q, callback ) {
            KOHA.OverDrive.GetCollectionURL( library_id, function( collection_url ) {
                _oauth_get(
                    collection_url,
                    {q: q},
                    callback
                );
            } );
        }
    };
} )();
