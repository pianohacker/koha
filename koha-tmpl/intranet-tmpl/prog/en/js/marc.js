/* From MARC::Record::JSON: http://code.google.com/p/marc-json/downloads/list */
/* Modified by Jesse Weaver */

/*===========================================
  MARC.Field(fdata) 
  
A MARC Field, as pulled from the json data. 
  
You can usually get what you want using MARCRecord.subfield(tag, sub)
but may need this for more advanced usage
  
  f = new MARC.Field(data);
  isbn = f.subfield('a'); // if it's an 020, of course
  isbn = f.as_string('a'); // same thing
  
  alltitlestuff = f.as_string(); // if it's a 245
  propertitle = f.as_string('anp'); // just the a, n, and p subfields
  
  subfield('a', sep=' ') -- returns:
    '' iff there is no subfield a
    'value' iff there is exactly one subfield a
    'value1|value2' iff there are more than on subfield a's
  
  as_string(spec, sep, includesftags) -- where spec is either empty or a string of concat'd subfields.
    spec is either null (all subfields) or a string listing the subfields (e.g., 'a' or 'abh')
    sep is the string used to separate the values; a single space is the default
    includesftags is a boolean that determines if the subfield tags will be included (e.g, $$a data $$h moredata)

    It returns the found data joined by the string in 'sep', or an empty string if nothing is found.
    
    
===============================================*/

marc = {}

marc.field = function ( tag, ind1, ind2, subfields ) {
	this.tag = tag;

	if (tag < 10) {
		this.is_control_field = true;
		this.data = ind1;
		return;
	}

	this._subfields = subfields;

	this._subfield_map = {};

	if ( ind1 == '' ) ind1 = ' ';
	if ( ind2 == '' ) ind2 = ' ';

	this._indicators = [ ind1, ind2 ];

	var field = this;

	$.each( subfields, function( i, subfield ) {
		var code = subfield[0];

		if (!(code in field._subfield_map)) field._subfield_map[code] = [];

		field._subfield_map[code].push(subfield[1]);
	} );
}

$.extend( marc.field.prototype, {
	indicator: function(ind) {
		if (this.is_control_field) throw TypeError('indicator() called on control field');
		if (ind != 1 && ind != 2) return null;

		return this._indicators[ind - 1];
	},

	subfield: function(code) {
		if (this.is_control_field) throw TypeError('subfield() called on control field');
		if (!(code in this._subfield_map)) return null;

		return this._subfield_map[code][0];
	},

	subfields: function(code) {
		if (this.is_control_field) throw TypeError('subfields() called on control field');
		if (code === undefined) {
			return self._subfields;
		} else {
			if (!(code in this._subfield_map)) return null;

			return this._subfield_map[code];
		}
	},

	as_string: function() {
		var buffer = [ this.tag, ' ' ];

		if ( this.is_control_field ) {
			buffer.push( this.data );
		} else {
			buffer.push( this._indicators[0], this._indicators[1], ' ' );

			$.each( this.subfields, function( i, subfield ) {
				buffer.push( '$', subfield[0], ' ', subfield[1] );
			} );
		}
	},
});


/*===========================================
MARCRecord -- a MARC::Record-like object

  r.cfield('008') -- the contents of the 008 control field
  r.cfield('LDR') -- ditto with the leader

  array = r.controlFieldTags(); -- a list of the control field tags, for feeding into cfield
  
  array = r.dfield('022') -- all the ISSN fields
  r.dfield('022')[0].as_string -- the first 022 as a string
  r.dfield('245')[0].as_string(); -- the title as a string
  r.dfield('FAK') -- returns an empty array

  r.dfields() -- return an array of all dfields

  r.field('245')[0] -- 'field' is an alias for 'dfield'

  r.subfield('245', 'a') -- the first 245/a
  r.subfield('100', 'a') -- the author?
  
  // Convenience functions
  
  str = r.title();
  str = r.author(); // Looks in 100, 110, and 111 in that order; returns '' on fail
  edition = r.edition(); // from the 250/a
  

===========================================*/

marc.record = function(structure) {
	this.leader = new Array(25).join(' '); // Poor man's ' ' x 24
	this._fields = [];
	this._field_map = {};

	if (structure) {
		this.leader = structure.leader;
		var record = this;

		$.each( structure.fields, function( i, field ) {
			var tag = field.tag;

			if ( !( tag in record._field_map ) ) record._field_map[tag] = [];

			var f = field.contents ? new marc.field( tag, field.contents ) : new marc.field( tag, field.indicator1, field.indicator2, field.subfields );

			record._fields.push( f );
			record._field_map[tag].push( f );
		} );
	}
}

$.extend( marc.record.prototype, {
	subfield: function(tag, subfield) {
		if ( !( tag in this._field_map ) ) return false;

		if ( subfield === undefined ) return true;

		var found = null;

		$.each( this._field_map[tag], function( i, field ) {
			found = field.subfield( subfield );
			
			if ( found ) return false;
		} );

		return found;
	},

	has: function( tag, subfield ) {
		return Boolean( this.subfield( tag, subfield ) );
	},

	field: function(tag) {
		if (!(tag in this._field_map)) return null;

		return this._field_map[tag][0];
	},

	fields: function(tag) {
		if (tag === undefined) {
			return self._fields;
		} else {
			if (!(tag in this._field_map)) return null;

			return this._field_map[tag];
		}
	},
} );

