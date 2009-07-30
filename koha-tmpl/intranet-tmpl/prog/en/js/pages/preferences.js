// We can assume 'KOHA' exists, as we depend on KOHA.AJAX

KOHA.Preferences = {
    Save: function ( form ) {
        data = $( form ).find( '.modified' ).serialize();
        if ( !data ) {
            humanMsg.displayAlert( 'Nothing to save' );
            return;
        }
        KOHA.AJAX.MarkRunning( $( form ).find( '.save-all' ), _( 'Saving...' ) );
        KOHA.AJAX.Submit( {
            data: data,
            url: '/cgi-bin/koha/svc/config/systempreferences/',
            success: function ( data ) { KOHA.Preferences.Success( form ) },
            complete: function () { KOHA.AJAX.MarkDone( $( form ).find( '.save-all' ) ) }
        } );
    },
    Success: function ( form ) {
        humanMsg.displayAlert( 'Saved' );

        $( form )
            .find( '.modified-warning' ).remove().end()
            .find( '.modified' ).removeClass('modified');
    }
};

$( document ).ready( function () {
    $( '.prefs-tab .preference' ).change( function () {
        $( this.form ).find( '.save-all' ).removeAttr( 'disabled' );
        $( this ).addClass( 'modified' );
        var name_cell = $( this ).parent().parent().find( '.name-cell' );

		if ( !name_cell.find( '.modified-warning' ).length ) name_cell.append( '<em class="modified-warning">(modified)</em>' );
    } );

    if ( document.location.search.indexOf( 'jumpfield' ) != -1 ) {
        document.location.hash = "highlighted";
    }

    $( '.prefs-tab .expand-textarea' ).show().click( function () {
        $( this ).hide().nextAll( 'textarea, input[type=submit]' )
            .animate( { height: 'show', queue: false } )
            .animate( { opacity: 1 } );

        return false;
    } ).nextAll( 'textarea, input[type=submit]' ).hide().css( { opacity: 0 } );

    $( '.prefs-tab .save-all' ).attr( 'disabled', true ).click( function () {
        KOHA.Preferences.Save( this.form );
        return false;
    } ); 
} );

