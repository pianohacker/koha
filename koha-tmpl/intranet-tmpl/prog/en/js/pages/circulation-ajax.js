var checkout_impossible_error_tmpl  = {
	stats: _("Local Use Recorded") ,
	invalid_date: _("The due date is invalid") ,
	unknown_barcode: _("The barcode was not found") ,
	not_for_loan: _("Item not for loan") ,
	wthdrawn: _("Item has been withdrawn") ,
	restricted: _("Item is restricted") ,
	gna: _("Patron's address is in doubt") ,
	card_lost: _("Patron's card is lost") ,
	debarred: _("Patron is restricted") ,
	no_more_renewals: _("No more renewals possible") ,
	expired: _("Patron's card is expired") ,
	notsamebranch: _("This item belongs to $homebranch and cannot be issued from this location.")
};

var need_confirmation_error_tmpl = {
	debt: _("The patron has a debt of $debt") ,
	renew_issue: _("Item is currently checked out to this patron.  Renew?") ,
	reserve_waiting: _("Item is consigned for $reserve_waiting") ,
	reserved: _("Item is on reserve for $reserved") ,
	issued_to_another: _("Item checked out to $issued_to_another.  Check in and check out?") ,
	too_many:  _("Too many checked out (already checked out / max : $too_many)")
};

var checkin_error_tmpl = {
	notissued: _( 'not checked out' ),
	badbarcode: _( 'barcode not found: $badbarcode' ),
	waslost: _( 'was lost, now is found' ),
	wthdrawn: _( 'is withdrawn' ),
	ispermanent: _( 'needs to be returned to $ispermanent' ),
	wastransfered: _( 'was transferred to its home branch' ),
	wrongbranch: _( 'must be returned to its home branch' ),
};

// These are displayed to the user, but still result in the checkin being removed.
var checkin_ignorable_errors = [
	'notissued',
	'badbarcode',
];

var checkin_show_dialog_errors = [
	'wrongtransfer',
	'needstransfer',
	'resfound',
];

var renew_error_tmpl = {
	too_many: _( 'has been renewed too many times already' ),
	on_reserve: _( 'is on hold for someone else' )
};

var renew_status_tmpl = {
	too_many: _( 'Too Many Renewals' ),
	on_reserve: _( 'On Hold' )
};

var circulation = {
	checkout: function () {
		circulation.checkout.mark_running();
		$.ajax( {
			url: '/cgi-bin/koha/svc/checkouts',
			dataType: 'json',
			data: $( '#mainform :input' ).add( '#circ_needsconfirmation:visible :input' ).serialize(),
			type: 'POST',
			success: circulation.checkout.succeeded,
			error: circulation.checkout.failed,
			complete: circulation.checkout.mark_done
		} );

		return false;
	},

	checkin: function ( issueid ) {
		circulation.checkin.running = ( typeof(issueid) == 'object' ? issueid : [issueid] );
		circulation.checkin.mark_running();
		$.ajax( {
			url: '/cgi-bin/koha/svc/checkouts/' + circulation.checkin.running.join( '|' ),
			dataType: 'json',
			data: { 'returned': 1 },
			type: 'POST',
			complete: circulation.checkin.finished
		} );

		return false;
	},
	
	renew: function () {
		var issueids = [];

		if ( this.name == 'renew_checked' ) {
			$( '#renew-form input[name="items[]"]:checked' ).parent().parent().each( function ( i, row ) {
				issueids.push( row.id.split( '-' )[1] ); // Extract issueid
			} );

			if ( issueids.length == 0 ) {
				humanMsg.displayAlert( 'Nothing was selected' );
				return false;
			}
		} else {
			$.each( circulation.issues, function ( issueid ) { issueids.push( issueid.toString() ) } );
		}

		circulation.renew.mark_running();
		$.ajax( {
			url: '/cgi-bin/koha/svc/checkouts/' + issueids.join( '|' ),
			dataType: 'json',
			data: { 'renewed': 1 },
			type: 'POST',
			complete: circulation.renew.finished
		} );

		return false;
	},
}

$.extend(circulation.checkout, {
	succeeded: function( data, status ) {
		circulation.checkout.end();
		$( '#mainform-container:hidden' ).show( 'slow' );

		entry = {date_due: data.date_due};

		$.each(
			['biblionumber', 'itemnumber', 'title', 'author', 'itemcallnumber', 'itemtype', 'itemtype_description', 'itemtype_image', 'itemnotes', 'barcode'],
			function (i, key) {
				entry[key] = data.biblio[key];
			});

		circulation.issues[data.issueid] = entry;
		circulation.issuecount += 1;
		$( '#issuecount' ).text( circulation.issuecount );

		row = ['<tr id="issuerow-', data.issueid, '"><td>', format_date(entry.date_due), '</td><td>',
			'<a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=', entry.biblionumber, '&amp;type=intra">', entry.title, '</a>'];
		
		if ( entry.author ) row.push( ', by ', entry.author );
		if ( entry.itemnotes ) row.push( ' - <span class="circ-hlt">', entry.itemnotes, '</span>' );

		if ( koha.item_type_images && entry.itemtype_image ) {
		   	row.push( '</td><td><img src="', entry.itemtype_image, '" alt="', entry.itemtype_description, '" />' );
		} else {
			row.push( '</td><td>', entry.itemtype_description );
		}

		row.push( '</td><td>', entry.itemcallnumber, '</td><td>', entry.barcode, '</td><td>' );

		if ( data.no_renewals ) {
			row.push( renew_status_tmpl[data.no_renewals] );
		} else {
			row.push( '<input type="checkbox" name="all_items[]" value="', entry.itemnumber, '" checked="checked" style="display: none;" />',
	        	'<input type="checkbox" name="items[]" value="', entry.itemnumber, '" />' );
		}

		row.push( '</td><td><a id="returnlink-', data.issueid, '" href="/cgi-bin/koha/circ/returns.pl?barcode=', entry.barcode, '">Check In</a>',
			'</td></tr>' );

		issues_row = $( row.join( '' ) );
		issues_row.find( '#returnlink-' + data.issueid ).click( function () { circulation.checkin( data.issueid ); return false; } );

		$( '#renew-form:hidden' ).show();
		$( '#noissues' ).hide();

		if ( $( '#issuerow-' + data.issueid ).get(0) ) {
			$( '#issuerow-' + data.issueid ).replaceWith( issues_row );
			issues_row.animate({backgroundColor: '#FF8'}, 750).animate({backgroundColor: 'white'}, 750);
		} else {
			$( '#todaysissues_last' ).before( issues_row );
			issues_row.fadeIn();
		}
	},

	failed: function( xhr, status, e ) {
		if ( xhr.getResponseHeader( 'content-type' ) != 'application/json' ) {
			// Something really failed
			humanMsg.displayAlert( _( 'Internal Server Error' ) );
			setTimeout( window.location.reload, 500 );
			return;
		}

		var error = eval( '(' + xhr.responseText + ')' );

		switch ( error.type ) {
			case 'auth':
				humanMsg.displayMsg( _( 'Session has expired' ) );
				setTimeout( window.location.reload, 500 );
				break;
			case 'need_confirmation':
				circulation.checkout.show_confirmation_dialog(error);
				break;
			case 'impossible':
				circulation.checkout.show_error_dialog(error);
				break;
		}
	},
	
	show_confirmation_dialog: function( error ) {
		$( '#confirm_list' ).children().remove();
		
		var errors = error.message.split( '|' );

		$.each( errors, function (i, error_code) {
			$( '#confirm_list' ).append( '<li>' + format(need_confirmation_error_tmpl[error_code], error) + '</li>' );
		});

		if ( errors.indexOf( 'reserved' ) != -1 || errors.indexOf( 'reserve_waiting') != -1 ) {
			$( '#reserve_cancel' ).show();
		} else {
			$( '#reserve_cancel' ).hide();
		}

		$( '#confirmation_form input[name="debt_confirmed"]' ).get(0).value = ( errors.indexOf( 'debt' ) != -1 ? 1 : 0 );

		$( '#mainform-container' ).hide( 'slow' );
		$( '#circ_needsconfirmation' ).show( 'slow' );
	},

	show_error_dialog: function ( error ) {
		msg = ['<h3>', _( "Can't Check Out:" ), '</h3>'];

		$.each( error.message.split( '|' ), function (i, error_code) {
			msg.push( '<p>', format( checkout_impossible_error_tmpl[error_code], error ), '</p>' );
		});

		humanMsg.displayMsg( msg.join( '' ) );
	},

	confirm_: function () { 
		$( '#circ_needsconfirmation' ).hide( 'slow' );
		if ( $( '#debt_confirmed' ).get(0).value == 1 ) $( '#mainform input[name="debt_confirmed"]' ).get(0).value = 1;
		circulation.checkout(); // checkout() will automatically integrate the necessary inputs from the confirm dialog
		return false;
	},
	
	cancel: function () {
		$( '#circ_needsconfirmation' ).hide( 'slow' );
		circulation.checkout.end();
		$( '#mainform-container' ).show( 'slow' );
		return false;
	},
	
	end: function () {
		$( '#barcode' ).get(0).value = '';
		if ( !$( '#stickyduedate' ).get(0).checked ) $( '#duedatespec' ).get(0).value = '';
	},

	mark_running: function () {
		$( '#checkout-button' )
			.text( 'Checking Out' )
			.prepend( '<img src="http://staff-jpw.dev.kohalibrary.com/intranet-tmpl/prog/img/spinner-small.gif" alt="" class="spinner" />' )
			.attr( 'disabled', 'disabled' )
			.addClass( 'running' );
	},
	
	mark_done: function () {
		$( '#checkout-button' )
			.removeClass( 'running' )
			.removeAttr( 'disabled' )
			.find( 'img' ).remove().end()
			.text( 'Check Out' );
	},
});

disabled = function () { return false; }

$.extend( circulation.checkin, { 
	finished: function( xhr, status ) {
		if ( xhr.getResponseHeader( 'content-type' ) != 'application/json' ) {
			// Something really failed
			humanMsg.displayAlert( _( 'Internal Server Error' ) );
			setTimeout( window.location.reload, 500 );
			return;
		}

		var status_ = xhr.status;
		var data = eval( '(' + xhr.responseText + ')' );

		if ( status_ == 400 && data.type == 'auth' ) {
			humanMsg.displayMsg( _( 'Session has expired' ) );
			setTimeout( window.location.reload, 500 );
			return;
		}

		if ( status_ == 200 ) {
			$.each( circulation.checkin.running, function (i, issueid) {
				circulation.checkin.succeeded( { issueid: issueid } );
			} );
			return;
		} 

		var errors = {}, warnings = {}, dialog_required = {}, remove_issue = {};

		$.each( data.responses, function ( i, response ) {
			if ( response.is_error ) {
				response.type = response.type.split( '|' );

				errors[response.issueid] = response;

				$.each( response.type, function ( i, error ) {
					remove_issue[response.issueid] = ( checkin_ignorable_errors.indexOf( error ) != -1 );
					dialog_required[response.issueid] = dialog_required[response.issueid] || ( checkin_show_dialog_errors.indexOf( error ) != -1 );
				} );
			} else {
				response.type = response.warning.split( '|' );

				warnings[response.issueid] = response;

				$.each( response.type, function ( i, error ) {
					dialog_required[response.issueid] = dialog_required[response.issueid] || ( checkin_show_dialog_errors.indexOf( error ) != -1 );
				} );
			}
		} );

		var show_dialog = function ( heading, responses ) {
			var dialog = ['<h3>', heading, '</h3>'];

			$.each( responses, function ( issueid, response ) {
				if ( dialog_required[issueid] ) {
					window.open( '/cgi-bin/koha/circ/returns.pl?barcode=' + circulation.issues[issueid].barcode, Math.random().toString(), 'width=700,height=500' );
					return;
				}

				dialog.push( '<p><strong>', circulation.issues[issueid].title, '</strong> ' );

				var line = [];

				$.each( response.type, function ( i, error_code ) {
					line.push( format(checkin_error_tmpl[error_code], response) );
				} );

				dialog.push( line.join( ', ' ), '</p>' );
			} );

			if ( dialog.length == 3 ) dialog.push( '<p>See popup</p>' );

			humanMsg.displayMsg( dialog.join( '' ) );
		};

		if ( !is_empty( errors ) ) {
			show_dialog( _( "Can't Check In Some Items" ), errors );
		} else if ( !is_empty( warnings ) ) {
			show_dialog( _( 'Warning' ), warnings );
		}

		$.each( circulation.checkin.running, function (i, issueid) {
			if ( errors[issueid] && !remove_issue[issueid] ) return; // Some errors, like "not checked out", shouldn't prevent the issue row from being removed.

			circulation.checkin.succeeded( { issueid: issueid } );
		} );
	},

	succeeded: function ( data ) {
		$( '#issuerow-' + data.issueid ).fadeOut().remove();
		delete circulation.issues[data.issueid];
		circulation.issuecount -= 1;
		$( '#issuecount' ).text( circulation.issuecount );
		if ( circulation.issuecount == 0 ) {
			$( '#renew-form' ).hide();
			$( '#noissues' ).show();
		}
	},

	mark_running: function () {
		$.each( circulation.checkin.running, function (i, issueid) {
			$( '#returnlink-' + issueid )
				.addClass( 'running' )
				.click( disabled )
				.text( 'Checking In' )
				.before( '<img src="http://staff-jpw.dev.kohalibrary.com/intranet-tmpl/prog/img/spinner-small.gif" alt="" class="spinner" />');
		} );
	},

	mark_done: function ( issueid, text ) {
		$( '#returnlink' + issueid )
			.removeClass( 'running' )
			.unbind( 'click', disabled )
			.text( text || 'Failed' )
			.prev( 'img.spinner' ).remove();
	},
});

$.extend( circulation.renew, { 
	finished: function( xhr, status ) {
		if ( xhr.getResponseHeader( 'content-type' ) != 'application/json' ) {
			// Something really failed
			humanMsg.displayAlert( _( 'Internal Server Error' ) );
			setTimeout( window.location.reload, 500 );
			return;
		}

		var status_ = xhr.status;
		var data = eval( '(' + xhr.responseText + ')' );

		if ( status_ == 400 && data.type == 'auth' ) {
			humanMsg.displayMsg( _( 'Session has expired' ) );
			setTimeout( window.location.reload, 500 );
			return;
		}

		var errors = {}, successful = {};

		$.each( data.responses, function ( i, response ) {
			if ( response.is_error ) {
				errors[response.issueid] = response;
			} else {
				successful[response.issueid] = response;
			}
		} );

		if ( !is_empty( errors ) ) {
			var dialog = ['<h3>', _( "Can't Renew Some Items" ), '</h3>'];

			$.each( errors, function ( issueid, response ) {
				dialog.push( '<p><strong>', circulation.issues[issueid].title, '</strong> ', format( renew_error_tmpl[response.message], response ), '</p>');
			} );

			humanMsg.displayMsg( dialog.join( '' ) );
		} 

		$.each( successful, function (issueid, response) {
			$( '#issuerow-' + issueid + ' td:eq(0)' )
				.text( format_date( response.date_due ) )
				.animate( {backgroundColor: '#FF8'}, 750 ).animate( {backgroundColor: 'white'}, 750 );
		} );

		circulation.renew.mark_done();
	},

	mark_running: function ( ) {
		$( '#renew-form button' )
			.text( 'Renewing' )
			.prepend( '<img src="http://staff-jpw.dev.kohalibrary.com/intranet-tmpl/prog/img/spinner-small.gif" alt="" class="spinner" />' )
			.attr( 'disabled', 'disabled' )
			.addClass( 'running' );
	},
	
	mark_done: function () {
		$( '#renew-form button.running' )
			.removeClass( 'running' )
			.removeAttr( 'disabled' )
			.find( 'img' ).remove().end()
			.each( function ( i ) { $( this ).text(['Renew Checked Items', 'Renew All'][i]) } );
	},
});

$( function () {
	$( '#mainform' ).submit( circulation.checkout );

	$( '#confirm_checkout' ).click( circulation.checkout.confirm_  );

	$( '#cancel_checkout' ).click( circulation.checkout.cancel );

	$.each( circulation.issues, function ( issueid ) {
		$( '#returnlink-' + issueid ).click( function () { circulation.checkin ( issueid ); return false; } );
	});

	$( '#renew_checked, #renew_all' ).click( circulation.renew );
});
