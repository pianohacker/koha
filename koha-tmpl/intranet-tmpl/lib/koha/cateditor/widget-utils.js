define( function() {
    var Widget = {};

    Widget.Base = {
        // Marker utils
        clearToText: function() {
            var range = this.mark.find();
            this.mark.doc.replaceRange( this.text, range.from, range.to, 'marcAware' );
        },

        // Fixed field utils
        bindFixed: function( sel, start, end ) {
            var $node = $( this.node ).find( sel );
            $node.val( this.getFixed( start, end ) );

            $node.change( $.proxy( function() {
                this.setFixed( start, end, $node.val() );
            }, this ) );
        },

        getFixed: function( start, end ) {
            return this.text.substring( start, end );
        },

        setFixed: function( start, end, value ) {
            this.text = this.text.substring( 0, start ) + this.padString( value.toString().substr( 0, end - start ), end - start ) + this.text.substring( end );
        },

        setText: function( text ) {
            this.text = text;
        },

        // Template utils
        insertTemplate: function( sel ) {
            var wsOnly = /^\s*$/;
            $( sel ).contents().clone().each( function() {
                if ( this.nodeType == Node.TEXT_NODE ) {
                    this.data = this.data.replace( /^\s+|\s+$/g, '' );
                }
            } ).appendTo( this.node );
        },

        padNum: function( number, length ) {
            var result = number.toString();

            while ( result.length < length ) result = '0' + result;

            return result;
        },

        padString: function( result, length ) {
            while ( result.length < length ) result = ' ' + result;

            return result;
        }
    };

    Widget.GetLineInfo = function( editor, pos ) {
        var contents = editor.getLine( pos.line );
        var tagNumber = contents.match( /^([A-Za-z0-9]{3}) / );

        if ( !tagNumber ) return {}; // No tag at all on this line
        tagNumber = tagNumber[1];

        if ( tagNumber < '010' ) return { tagNumber: tagNumber }; // No current subfield

        var matcher = /[$|ǂ‡]([a-z0-9%]) /g;
        var match;

        var subfields = [];
        var currentSubfield;

        while ( ( match = matcher.exec(contents) ) ) {
            subfields.push( { code: match[1], ch: match.index } );
            if ( match.index < pos.ch ) currentSubfield = match[1];
        }

        return { tagNumber: tagNumber, subfields: subfields, currentSubfield: currentSubfield };
    };

    Widget.UpdateLine = function( editor, line ) {
        var info = Widget.GetLineInfo( editor, { line: line, ch: 0 } );

        if ( !info.tagNumber ) {
            var lineh = editor.getLineHandle( line );

            if ( lineh.markedSpans ) {
                $.each( lineh.markedSpans, function ( _, span ) {
                    var mark = span.marker;
                    if ( !mark.widget ) return;

                    mark.widget.clearToText();
                } );
            }
            return;
        }

        var subfields = [];

        var end = editor.getLine( line ).length;
        if ( info.tagNumber < '010' ) {
            if ( end >= 4 ) subfields.push( { code: '@', from: 4, to: end } );
        } else {
            for ( var i = 0; i < info.subfields.length; i++ ) {
                var next = ( i < info.subfields.length - 1 ) ? info.subfields[i + 1].ch : end;
                subfields.push( { code: info.subfields[i].code, from: info.subfields[i].ch + 3, to: next } );
            }
        }

        $.each( subfields, function ( _, subfield ) {
            var id = info.tagNumber + subfield.code;
            var marks = editor.findMarksAt( { line: line, ch: subfield.from } );

            if ( marks.length ) {
                if ( marks[0].id == id ) {
                    return;
                } else {
                    marks[0].widget.clearToText();
                }
            }

            if ( !editorWidgets[id] ) return;
            var fullBase = $.extend( Object.create( Widget.Base ), editorWidgets[id] );
            var widget = Object.create( fullBase );

            if ( subfield.from == subfield.to ) {
                editor.replaceRange( widget.makeTemplate ? widget.makeTemplate() : '<empty>', { line: line, ch: subfield.from } );
                return; // We'll do the actual work when the change event is triggered again
            }

            var text = editor.getRange( { line: line, ch: subfield.from }, { line: line, ch: subfield.to } );

            widget.text = text;
            var node = widget.init();

            var mark = editor.markText( { line: line, ch: subfield.from }, { line: line, ch: subfield.to }, {
                inclusiveLeft: false,
                inclusiveRight: false,
                replacedWith: node,
            } );

            mark.id = id;
            mark.widget = widget;

            widget.node = node;
            widget.mark = mark;

            if ( widget.postCreate ) widget.postCreate();
        } );
    };

    return Widget;
} );
