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

        GetLineInfo: function( editor, pos ) {
            var contents = editor.getLine( pos.line );
            if ( contents == null ) return {};

            var tagNumber = contents.match( /^([A-Za-z0-9]{3}) / );

            if ( !tagNumber ) return {}; // No tag at all on this line
            tagNumber = tagNumber[1];

            if ( tagNumber < '010' ) return { tagNumber: tagNumber, contents: contents }; // No current subfield

            var matcher = /[$|ǂ‡]([a-z0-9%]) /g;
            var match;

            var subfields = [];
            var currentSubfield;

            while ( ( match = matcher.exec(contents) ) ) {
                subfields.push( { code: match[1], ch: match.index } );
                if ( match.index < pos.ch ) currentSubfield = match[1];
            }

            return { tagNumber: tagNumber, subfields: subfields, currentSubfield: currentSubfield, contents: contents };
        },

        UpdateLine: function( editor, line ) {
            var info = Widget.GetLineInfo( editor, { line: line, ch: 0 } );
            var lineh = editor.getLineHandle( line );
            if ( !lineh ) return;

            if ( !info.tagNumber ) {
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

            var end = editor.getLine( line ).length;
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
                    editor.replaceRange( widget.makeTemplate ? widget.makeTemplate() : '<empty>', { line: line, ch: subfield.from }, null, 'marcWidgetPrefill' );
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

                if ( widget.postCreate ) {
                    widget.postCreate();
                    mark.changed();
                }

                var $lastInput = $(widget.node).find('input, select').eq(-1);
                if ( $lastInput.length ) {
                    $lastInput.bind( 'keypress', 'tab', function() {
                        var cur = editor.getCursor();
                        editor.setCursor( { line: cur.line } );
                        // FIXME: ugly hack
                        editor.options.extraKeys.Tab( editor );
                        editor.focus();
                        return false;
                    } );
                }
            } );
        },

        AddError: function( editor, line, error ) {
            var found = false;
            var options = {};

            if ( line == null ) {
                line = 0;
                options.above = true;
            }

            $.each( editor.getLineHandle(line).widgets || [], function( undef, widget ) {
                if ( !widget.isErrorMarker ) return;

                found = true;

                $( widget.node ).append( '; ' + error );
                widget.changed();

                return false;
            } );

            if ( found ) return;

            var node = $( '<div class="structure-error"><i class="icon-remove"></i> ' + error + '</div>' )[0];
            var widget = editor.addLineWidget( line, node, options );

            widget.node = node;
            widget.isErrorMarker = true;
        },

        RemoveErrors: function( editor ) {
            for ( var line = 0; line < editor.lineCount(); line++ ) {
                $.each( editor.getLineHandle( line ).widgets || [], function( undef, lineWidget ) {
                    if ( lineWidget.isErrorMarker ) lineWidget.clear();
                } );
            }
        },
    };

    return Widget;
} );
