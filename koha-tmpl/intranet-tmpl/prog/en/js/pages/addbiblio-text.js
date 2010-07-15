addbiblio = {};

$.extend( addbiblio, {
	submit: function() {
		$.ajax( {
			url: '/cgi-bin/koha/cataloguing/addbiblio-text.pl',
			type: 'POST',
			dataType: 'json',
			data: $( '#f input[name^="tag"]' ).serialize() + '&op=try_parse&record=' + escape(addbiblio.editor.getCode()),
			success: addbiblio.submit.finished,
		} );
	},
	insert_itemtype: function( event ) {
		var iter = addbiblio.editor.cursorPosition();
		addbiblio.editor.insertIntoLine( iter.line, iter.character, $( '#itemtypes' ).val() );

		return false;
	},
	z3950_search: function() {
		window.open( "/cgi-bin/koha/cataloguing/z3950_search.pl?biblionumber=" + addbiblio.biblionumber,"z3950search",'width=740,height=450,location=yes,toolbar=no,scrollbars=yes,resize=yes' );
	},
	not_duplicate: function() {
		$( "#confirm_not_duplicate" ).attr( "value", "1" );
		$( "#f" ).get( 0 ).submit();
	},
} );

$.extend( addbiblio.submit, {
	finished: function( data, status_ ) {
		if ( data.error ) {
			humanMsg.displayMsg( '<strong>Watch your language:</strong> ' + data.message );
			return false;
		}

		var record = new marc.record(data.record);

		var missing_tags = [], missing_subfields = [];

		$.each( addbiblio.mandatory.tags, function( i, tag ) {
			if ( tag == '000' ) {
				if ( !record.leader) missing_tags.push( 'leader' );
			} else if ( !record.has( tag ) ) {
				missing_tags.push( tag );
			}
		} );

		$.each( addbiblio.mandatory.subfields, function( i, sf ) {
			if ( sf[0].substring( 0, 2 ) != '00' && !record.has( sf[0], sf[1] ) ) {
				missing_subfields.push( sf.join( '$' ) );
			}
		} );

		if ( missing_tags.length || missing_subfields.length ) {
			message = [];

			if ( missing_tags.length ) {
				message.push( missing_tags.join( ', ' ) + ' tags' );
			}

			if ( missing_subfields.length ) {
				message.push( missing_subfields.join( ', ' ) + ' subfields' );
			}

			humanMsg.displayMsg( '<strong>Record is missing pieces:</strong> ' + message.join( ' and ' ) + ' are mandatory' );
			return;
		}

		$( '#f' ).get( 0 ).submit();
	}
} );

$( function () {
	$( '#insert-itemtype' ).click( addbiblio.insert_itemtype );

	addbiblio.editor = CodeMirror.fromTextArea('record', {
		height: "350px",
		parserfile: "parsemarc.js",
		stylesheet: koha.themelang + "/lib/codemirror/css/marccolors.css",
		path: koha.themelang + "/lib/codemirror/js/",
		autoMatchParens: true
	});
} );
