define( function() {
    var Widget = {
        Base: {
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
                    this.setFixed( start, end, $node.val(), '+input' );
                }, this ) );
            },

            getFixed: function( start, end ) {
                return this.text.substring( start, end );
            },

            setFixed: function( start, end, value, source ) {
                this.setText( this.text.substring( 0, start ) + this.padString( value.toString().substr( 0, end - start ), end - start ) + this.text.substring( end ), source );
            },

            setText: function( text, source ) {
                if ( source == '+input' ) this.mark.doc.cm.addLineClass( this.mark.find().from.line, 'wrapper', 'modified-line' );
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
        },

        ActivateAt: function( editor, cur, idx ) {
            var marks = editor.findMarksAt( cur );
            if ( !marks.length ) return false;

            var $input = $(marks[0].widget.node).find('input, select').eq(idx || 0);
            if ( !$input.length ) return false;

            $input.focus();
            return true;
        },

	Notify: function() {},

        UpdateLine: function( editor, line ) {
            var info = editor.getLineInfo( { line: line, ch: 0 } );
            var lineh = editor.cm.getLineHandle( line );
            if ( !lineh ) return;

            if ( !info ) {
                if ( lineh.markedSpans ) {
                    $.each( lineh.markedSpans, function ( undef, span ) {
                        var mark = span.marker;
                        if ( !mark.widget ) return;

                        mark.widget.clearToText();
                    } );
                }
                return;
            }

            var subfields = [];

            var end = editor.cm.getLine( line ).length;
            if ( info.tagNumber < '010' ) {
                if ( end >= 4 ) subfields.push( { code: '@', from: 4, to: end } );
            } else {
                for ( var i = 0; i < info.subfields.length; i++ ) {
                    var next = ( i < info.subfields.length - 1 ) ? info.subfields[i + 1].ch : end;
                    subfields.push( { code: info.subfields[i].code, from: info.subfields[i].ch + 3, to: next } );
                }
            }

            $.each( subfields, function ( undef, subfield ) {
                var id = info.tagNumber + subfield.code;
                var marks = editor.cm.findMarksAt( { line: line, ch: subfield.from } );

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
                    editor.cm.replaceRange( widget.makeTemplate ? widget.makeTemplate() : '<empty>', { line: line, ch: subfield.from }, null, 'marcWidgetPrefill' );
                    return; // We'll do the actual work when the change event is triggered again
                }

                var text = editor.cm.getRange( { line: line, ch: subfield.from }, { line: line, ch: subfield.to } );

                widget.text = text;
                var node = widget.init();

                var mark = editor.cm.markText( { line: line, ch: subfield.from }, { line: line, ch: subfield.to }, {
                    inclusiveLeft: false,
                    inclusiveRight: false,
                    replacedWith: node,
                } );

                mark.id = id;
                mark.widget = widget;

                widget.node = node;
                widget.mark = mark;

                if ( widget.postCreate ) {
                    widget.postCreate();
                    mark.changed();
                }

                var $lastInput = $(widget.node).find('input, select').eq(-1);
                if ( $lastInput.length ) {
                    $lastInput.bind( 'keypress', 'tab', function() {
                        var cur = editor.cm.getCursor();
                        editor.cm.setCursor( { line: cur.line } );
                        // FIXME: ugly hack
                        editor.cm.options.extraKeys.Tab( editor.cm );
                        editor.focus();
                        return false;
                    } );
                }
            } );
        },
    };

    return Widget;
} );
