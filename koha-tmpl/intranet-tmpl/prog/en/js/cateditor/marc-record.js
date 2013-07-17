/**
 * Adapted and cleaned up from biblios.net, which is purportedly under the GPL.
 * Source: http://git.librarypolice.com/?p=biblios.git;a=blob_plain;f=plugins/marc21editor/marcrecord.js;hb=master
 */

define( function() {
    var MARC = {};

    MARC.Record = function (fieldlist) {
        this._fieldlist = fieldlist || [];
    }

    $.extend( MARC.Record.prototype, {
        fields: function(fieldno) {
            if (!fieldno) return this._fieldlist;

            var results = [];
            for(var i=0; i<this._fieldlist.length; i++){
                if( this._fieldlist[i].tagnumber() == fieldno ) {
                    results.push(this._fieldlist[i]);
                }
            }

            return results;
        },

        field: function(fieldno) {
            for(var i=0; i<this._fieldlist.length; i++){
                if( this._fieldlist[i].tagnumber() == fieldno ) {
                    return this._fieldlist[i];
                }
            }
            return false;
        },

        addField: function(field) {
            this._fieldlist.push(field);
            return true;
        },

        addFieldGrouped: function(field) {
            for ( var i = this._fieldlist.length - 1; i >= 0; i-- ) {
                if ( this._fieldlist[i].tagnumber()[0] <= field.tagnumber()[0] ) {
                    this._fieldlist.splice(i+1, 0, field);
                    return true;
                }
            }
            this._fieldlist.push(field);
            return true;
        },

        removeField: function(fieldno) {
            for(var i=0; i<this._fieldlist.length; i++){
                if( this._fieldlist[i].tagnumber() == fieldno ) {
                    this._fieldlist.splice(i, 1);
                    return true;
                }
            }
            return false;
        },

        hasField: function(fieldno) {
            for(var i=0; i<this._fieldlist.length; i++){
                if( this._fieldlist[i].tagnumber() == fieldno ) {
                    return true;
                }
            }
            return false;
        },

        XML: function() {
            // fixme this isn't working correctly: it's failing on trying to add xml fragment
            // returned from fields[i].XML()
            //var xml = Sarissa.getDomDocument("", "record");
            //for(var i=0; i<fields.length; i++){
            //	xml.appendChild( fields[i].XML() );
            //}
            //return xml;
            return xslTransform.loadString( this._XMLString() );
        },

        XMLString: function() {
            var xml = '<record xmlns="http://www.loc.gov/MARC21/slim">';
            for(var i=0; i<this._fieldlist.length; i++){
                xml += this._fieldlist[i].XMLString();
            }
            xml += '</record>';
            return xml;
        },

        loadMarcXml: function(xmldoc) {
            this._fieldlist.length = 0;
            var leader = $('leader', xmldoc).text();
            this._fieldlist.push( new MARC.Field('000', '', '', [ '@', leader ]) );
            $('controlfield', xmldoc).each( function(i) {
                val = $(this).text();
                tagnum = $(this).attr('tag');
                this._fieldlist.push( new MARC.Field(tagnum, '', '', [ '@', val ]) );
            });
            $('datafield', xmldoc).each(function(i) {
                var value = $(this).text();
                var tagnum = $(this).attr('tag');
                var ind1 = $(this).attr('ind1') || ' ';
                var ind2 = $(this).attr('ind2') || ' ';
                var subfields = new Array();
                $('subfield', this).each(function(j) {
                    var sfval = $(this).text();
                    var sfcode = $(this).attr('code');
                    subfields.push( [ sfcode, sfval ] );
                });
                this._fieldlist.push( new MARC.Field(tagnum, ind1, ind2, subfields) );
            });
        }
    } );

    MARC.Field = function(tagnumber, indicator1, indicator2, subfields) {
        this._tagnumber = tagnumber;
        this._indicators = [ indicator1, indicator2 ];
        this._subfields = subfields;
    };

    $.extend( MARC.Field.prototype, {
        tagnumber: function() {
            return this._tagnumber;
        },

        isControlField: function() {
            return this._tagnumber < '010';
        },

        indicator: function(num, val) {
            if( val != null ) {
                this._indicators[num] = val;
            }
            return this._indicators[num];
        },

        indicators: function() {
            return this._indicators;
        },

        hasSubfield: function(code) {
            for(var i = 0; i<this._subfields.length; i++) {
                if( this._subfields[i][0] == code ) {
                    return true;
                }
            }
            return false;
        },

        removeSubfield: function(code) {
            for(var i = 0; i<this._subfields.length; i++) {
                if( this._subfields[i][0] == code ) {
                    this._subfields.splice(i,1);
                    return true;
                }
            }
            return false;
        },

        subfields: function() {
            return this._subfields;
        },

        addSubfield: function(sf) {
            this._subfields.push(sf);
            return true;
        },

        addSubfieldGrouped: function(sf) {
            function _kind( sc ) {
                if ( /[a-z]/.test( sc ) ) {
                    return 0;
                } else if ( /[0-9]/.test( sc ) ) {
                    return 1;
                } else {
                    return 2;
                }
            }

            for ( var i = this._subfields.length - 1; i >= 0; i-- ) {
                if ( i == 0 && _kind( sf[0] ) < _kind( this._subfields[i][0] ) ) {
                    this._subfields.splice( 0, 0, sf );
                    return true;
                } else if ( _kind( this._subfields[i][0] ) <= _kind( sf[0] )  ) {
                    this._subfields.splice( i + 1, 0, sf );
                    return true;
                }
            }

            this._subfields.push(sf);
            return true;
        },

        subfield: function(code, val) {
            var sf = '';
            for(var i = 0; i<this._subfields.length; i++) {
                if( this._subfields[i][0] == code ) {
                    sf = this._subfields[i];
                    if( val != null ) {
                        sf[1] = val;
                    }
                    return sf[1];
                }
            }
            return false;
        },

        XML: function() {
            var marcxml = Sarissa.getDomDocument('', '');
            // decide if it's controlfield of datafield
            if( this._tagnumber == '000') {
                var leader = marcxml.createElement('leader');
                var lv = marcxml.createTextNode( this._subfields[0][1] );
                leader.appendChild(lv);
                marcxml.appendChild(leader);
                return leader;
            }
            else if( this._tagnumber < '010' ) {
                var cf = marcxml.createElement('controlfield');
                cf.setAttribute('tag', this._tagnumber);
                var text = marcxml.createTextNode( this._subfields[0][1] );
                cf.appendChild(text);
                return cf;
            }
            // datafield
            else {
                var df = marcxml.createElement('datafield');
                var tagAttr = marcxml.createAttribute('tag');
                tagAttr.nodeValue = this._tagnumber;
                df.setAttributeNode(tagAttr);
                df.setAttribute('ind1', this._indicators[0]);
                df.setAttribute('ind2', this._indicators[1]);
                for( var i = 0; i< this._subfields.length; i++) {
                    var sf = marcxml.createElement('subfield');
                    sf.setAttribute('code', this._subfields[i][0] );
                    var text = marcxml.createTextNode( this._subfields[i][1] );
                    sf.appendChild(text);
                    df.appendChild(sf);
                }
                return df;
            }
        },

        XMLString: function() {
            return xslTransform.serialize( this.XML() );
        }
    } );

    return MARC;
} );
