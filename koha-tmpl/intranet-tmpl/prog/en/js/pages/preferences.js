if ( KOHA === undefined ) var KOHA = {};

KOHA.Preferences = {
};

$( document ).ready( function () {
    $( '#prefs-tab tr' ).hover(
        function () {
            $( this ).find( 'input[type="submit"]' ).css( { visibility: 'visible' } );
        },
        function () {
            $( this ).find( 'input[type="submit"]' ).css( { visibility: 'hidden' } );
        }
    );
    $( '#prefs-tab input.preference, #prefs-tab select.preference' ).change( function () {
        var name_cell = $( this ).parent().parent()
            .mouseover()
            .unbind( 'mouseenter' )
            .unbind( 'mouseleave' )
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
} );

