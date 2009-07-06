if ( KOHA === undefined ) var KOHA = {};

KOHA.Preferences = {
};

$( document ).ready( function () {
    $( '#prefs-tab input.preference, #prefs-tab select.preference' ).change( function () {
        var name_cell = $( this ).parent().parent()
            .find( 'input[type="submit"]' ).css( { visibility: 'visible' } ).end()
			.find( 'td:eq(0)' );

		if ( !name_cell.find( '.modified-warning' ).length ) name_cell.append( '<em class="modified-warning">(modified)</em>' );
    } );

    if ( document.location.search.indexOf( 'jumpfield' ) != -1 ) {
        document.location.hash = "highlighted";
    }

    $( '#prefs-tab .expand-textarea' ).show().click( function () {
        $( this ).hide().nextAll( 'textarea, input[type=submit]' )
            .animate( { height: 'show', queue: false } )
            .animate( { opacity: 1 } );

        return false;
    } ).nextAll( 'textarea, input[type=submit]' ).hide().css( { opacity: 0 } );

    $( '#prefs-tab .save-cell input' ).click( function () {
        KOHA.Preferences.Save( $( this ).
} );

