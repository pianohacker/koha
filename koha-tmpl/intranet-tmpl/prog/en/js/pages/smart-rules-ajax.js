var smart_rules = {
	check_int: function ( val ) { return !isNaN( parseInt( val ) ) },
	check_float: function ( val ) { return !isNaN( parseFloat( val ) ) },

    field_order: [ 'fine', 'firstremind', 'chargeperiod', 'maxissueqty', 'issuelength' ],
    fields_start_after: 1,

    edit: function () {
        var branch, categorycode, itemtype;

        var vals = this.parentNode.id.split( '-' );

        var field = this.getAttribute( 'class' ).split( '-' )[0];
        var cell = this;

        branch = vals[1]; categorycode = vals[2]; itemtype = vals[3];

        function save() {
            var input = this;

			if ( !input.value.replace( ' ', '' ) && !smart_rules.fields[field].empty_valid ) {
				humanMsg.displayAlert( 'Nothing was entered ' );
				smart_rules.mark_done();
				return;
			}

			if ( !smart_rules.fields[field].checker( input.value ) ) {
				humanMsg.displayAlert( 'Invalid input, ' + smart_rules.fields[field].checker.message );
				smart_rules.mark_done();
				return;
			}

			smart_rules.mark_running( this.nextSibling );
            $.ajax( {
                url: '/cgi-bin/koha/svc/admin/issuingrules/' + [branch, categorycode, itemtype].join( ';' ),
                dataType: 'json',
                data: { key: field, value: input.value },
                type: 'POST',
                success: function ( data, status_ ) {
                    $( cell ).addClass( 'editable' ).removeClass( 'editing' )
						.html(
							( smart_rules.fields[field].before || '' ) +
							input.value +
							( smart_rules.fields[field].after || '' )
						).click( smart_rules.edit ).attr( 'title', input.value );
                },
				completed: smart_rules.mark_done
            } );
        }

        $( this ).text('').removeClass( 'editable' ).addClass( 'editing' ).unbind( 'click', smart_rules.edit );

        $( '<input value="' + this.getAttribute( 'title' ) + '" size="' + smart_rules.fields[field].size + '" /><button>Save</button>' )
            .filter( 'button' ).click( function () { save.call( this.previousSibling );	return false; } ).end()
            .filter( 'input' ).keydown( function (e) {
				if ( e.keycode == 13 ) {
					save.call( this );
					return false
				}
			} ).end()
            .appendTo( this );

		if ( !smart_rules.cancel_bound) {
			smart_rules.cancel_bound = true;
			$( document.body ).one( 'click', smart_rules.cancel );
		}

		return false;
    },

	cancel: function ( e ) {
		if ( ['INPUT', 'BUTTON'].indexOf( e.target.localName ) != -1 ) return;

		$( 'td.editing' ).addClass( 'editable' ).removeClass( 'editing' ).each( function () {
			var field = this.getAttribute( 'class' ).split( '-' )[0];

			$( this ).html( ( smart_rules.fields[field].before || '' ) + this.getAttribute( 'title' ) + ( smart_rules.fields[field].after || '' ) );
		} ).click( smart_rules.edit );

		smart_rules.cancel_bound = false;
	},

    mark_running: function ( button ) {
        $( button )
            .text( 'Saving' )
            .prepend( '<img src="http://staff-jpw.dev.kohalibrary.com/intranet-tmpl/prog/img/spinner-small.gif" alt="" class="spinner" />' )
            .attr( 'disabled', 'disabled' )
            .addClass( 'running' );
    },
    
    mark_done: function ( ) {
        $( 'button.running' )
            .removeClass( 'running' )
            .removeAttr( 'disabled' )
            .find( 'img' ).remove().end()
            .text( 'Save' );
    },
};

smart_rules.fields = {
	fine: {
		size: 4,
		before: '$',
		checker: smart_rules.check_float,
	},
	firstremind: {
		size: 2,
		after: ' day(s)',
		checker: smart_rules.check_int,
	},
	chargeperiod: {
		size: 2,
		after: ' day(s)',
		checker: smart_rules.check_int,
	},
	maxissueqty: {
		size: 3,
		checker: smart_rules.check_int,
		empty_valid: true,
	},
	issuelength: {
		size: 3,
		after: ' day(s)',
		checker: smart_rules.check_int,
	},
};

smart_rules.check_int.message = _( 'an integer is required' );
smart_rules.check_float.message = _( 'a decimal number is required' );

$( function () {
    $( 'form tr.existing' ).each( function () {
        $( this ).find( 'td:gt(' + smart_rules.fields_start_after + '):lt(' + smart_rules.field_order.length + ')' ).addClass( 'editable' ).click( smart_rules.edit );
    } );
	$( '#noajax-instructions' ).hide();
	$( '#ajax-instructions' ).show();
} );




