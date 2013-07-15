/**
 * Adapted and cleaned up from biblios.net, which is purportedly under the GPL.
 * Source: http://git.librarypolice.com/?p=biblios.git;a=blob_plain;f=plugins/marc21editor/marcrecord.js;hb=master
 */

define( function() {
    var MARC = {};

    MARC.Record = function (fieldlist) {
        var fields = new Array();
        if(fieldlist) {
            fields = fieldlist;
        }
        var numfields = fields.length;

        this.fields = function() {
            return fields;
        };

        this._field = function(fieldno) {
            for(var i=0; i<fields.length; i++){
                if( fields[i].tagnumber() == fieldno ) {
                    return fields[i];
                }
            }
            return false;
        };

        this._addField = function(field) {
            fields.push(field);
            return true;
        };

        this._removeField = function(fieldno) {
            for(var i=0; i<fields.length; i++){
                if( fields[i].tagnumber() == fieldno ) {
                    fields.splice(i, 1);
                    return true;
                }
            }
            return false;
        };

        this._hasField = function(fieldno) {
            for(var i=0; i<fields.length; i++){
                if( fields[i].tagnumber() == fieldno ) {
                    return true;
                }
            }
            return false;
        }

        this._XML = function() {
            // fixme this isn't working correctly: it's failing on trying to add xml fragment
            // returned from fields[i].XML()
            //var xml = Sarissa.getDomDocument("", "record");
            //for(var i=0; i<fields.length; i++){
            //	xml.appendChild( fields[i].XML() );
            //}
            //return xml;
            return xslTransform.loadString( this._XMLString() );
        };

        this._XMLString = function() {
            var xml = '<record xmlns="http://www.loc.gov/MARC21/slim">';
            for(var i=0; i<fields.length; i++){
                xml += fields[i].XMLString();
            }
            xml += '</record>';
            return xml;
        };
        this._loadMarcXml = function(xmldoc) {
            fields.length = 0;
            var leader = $('leader', xmldoc).text();
            fields.push( new MARC.Field('000', '', '', [{code: '', value: leader}]) );
            $('controlfield', xmldoc).each( function(i) {
                val = $(this).text();
                tagnum = $(this).attr('tag');
                fields.push( new MARC.Field(tagnum, '', '', [{code: '', value: val}]) );
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
                    subfields.push( new MARC.Subfield(sfcode, sfval) );
                });
                fields.push( new MARC.Field(tagnum, ind1, ind2, subfields) );
            });
        }
    }

    MARC.Record.prototype.field = function(fieldno) {
        return this._field(fieldno);
    };

    MARC.Record.prototype.fields = function() {
        return this.fields();
    };

    MARC.Record.prototype.addField = function(field) {
        return this._addField(field);
    };

    MARC.Record.prototype.removeField = function(fieldno) {
        return this._removeField(fieldno);
    };

    MARC.Record.prototype.hasField = function(fieldno) {
        return this._hasField(fieldno);
    }

    MARC.Record.prototype.XML = function() {
        return this._XML();
    };

    MARC.Record.prototype.XMLString = function() {
        return this._XMLString();
    };

    MARC.Record.prototype.loadMarcXml = function(xmldoc) {
        return this._loadMarcXml(xmldoc);
    }
    MARC.Field = function(tagnumber, indicator1, indicator2, subfields) {
        var that = this;
        var tagnumber = tagnumber;
        var indicators = new Array(indicator1, indicator2);
        var subfields = subfields;

        this._tagnumber = function() {
            return tagnumber;
        };

        this._indicator = function(num, val) {
            if( val != null ) {
                indicators[num] = val;
            }
            return indicators[num];
        };

        this._indicators = function() {
            return indicators;
        };

        this._hasSubfield = function(code) {
            for(var i = 0; i<subfields.length; i++) {
                if( subfields[i].code == code ) {
                    return true;
                }
            }
            return false;
        };

        this._removeSubfield = function(code) {
            for(var i = 0; i<subfields.length; i++) {
                if( subfields[i].code == code ) {
                    subfields.splice(i,1);
                    return true;
                }
            }
            return false;
        }

        this._subfields = function() {
            return subfields;
        };

        this._addSubfield = function(sf) {
            subfields.push(sf);
            return true;
        }

        this._subfield = function(code, val) {
            var sf = '';
            for(var i = 0; i<subfields.length; i++) {
                if( subfields[i].code == code ) {
                    sf = subfields[i];
                    if( val != null ) {
                        sf.value = val;
                    }
                    return sf;
                }
            }
            return false;
        };

        this._XML = function() {
            var marcxml = Sarissa.getDomDocument('', '');
            // decide if it's controlfield of datafield
            if( tagnumber == '000') {
                var leader = marcxml.createElement('leader');
                var lv = marcxml.createTextNode( subfields[0].value );
                leader.appendChild(lv);
                marcxml.appendChild(leader);
                return leader;
            }
            else if( tagnumber < '010' ) {
                var cf = marcxml.createElement('controlfield');
                cf.setAttribute('tag', tagnumber);
                var text = marcxml.createTextNode( subfields[0].value );
                cf.appendChild(text);
                return cf;
            }
            // datafield
            else {
                var df = marcxml.createElement('datafield');
                var tagAttr = marcxml.createAttribute('tag');
                tagAttr.nodeValue = tagnumber;
                df.setAttributeNode(tagAttr);
                df.setAttribute('ind1', indicators[0]);
                df.setAttribute('ind2', indicators[1]);
                for( var i = 0; i< subfields.length; i++) {
                    var sf = marcxml.createElement('subfield');
                    sf.setAttribute('code', subfields[i].code);
                    var text = marcxml.createTextNode( subfields[i].value );
                    sf.appendChild(text);
                    df.appendChild(sf);
                }
                return df;
            }
        };

        this._XMLString = function() {
            return xslTransform.serialize( this.XML() );
        };
    }

    MARC.Field.prototype.XML = function() {
        return this._XML();
    };

    MARC.Field.prototype.XMLString = function() {
        return this._XMLString();
    };

    MARC.Field.prototype.subfields = function() {
        return this._subfields();
    };

    MARC.Field.prototype.subfield = function(code, val) {
        return this._subfield(code, val);
    };

    MARC.Field.prototype.hasSubfield = function(code) {
        return this._hasSubfield(code);
    };

    MARC.Field.prototype.removeSubfield = function(code) {
        return this._removeSubfield(code);
    }

    MARC.Field.prototype.addSubfield = function(sf) {
        return this._addSubfield(sf);
    }

    MARC.Field.prototype.tagnumber = function() {
        return this._tagnumber();
    };

    MARC.Field.prototype.indicator = function(num, val) {
        return this._indicator(num, val);
    };

    MARC.Field.prototype.indicators = function() {
        return this._indicators();
    };


    MARC.Subfield = function(code, value) {
        var that = this;
        that.code = code;
        that.value = value;
    }

    MARC.Subfield.prototype.setCode = function(code) {
        this.code = code;
    };

    MARC.Subfield.prototype.getCode = function(code) {
        return this.code;
    };

    MARC.Subfield.prototype.setValue = function(value) {
        this.value = value;
    };

    MARC.Subfield.prototype.getValue = function(value) {
        return this.value;
    };

    return MARC;
} );
