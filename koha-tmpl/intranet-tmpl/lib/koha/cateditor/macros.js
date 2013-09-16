define( [ 'widget-utils' ], function( Widget ) {
    var _commandGenerators = {
        [ /^copy field data/i, function() {
            return function( editor, state ) {
                var info = Widget.GetLineInfo( editor );
                if (!info.tagNumber)

                state.clipboard =
            };
        } ],
        [ /^copy subfield data/i, function() {
        } ],
        [ /^delete field/i, function() {
        } ],
        [ /^goto field end/i, function() {
        } ],
        [ /^goto field/i, function() {
        } ],
        [ /^goto subfield/i, function() {
        } ],
        [ /^insert (new )?field/i, function() {
        } ],
        [ /^insert (new )?subfield/i, function() {
        } ],
        [ /^paste/i, function() {
        } ],
        [ /^set indicator([12])=([ _0-9])/i, function() {
        } ],
        [ /^set indicators=([ _0-9])([ _0-9])/i, function() {
        } ],
    };

    var Macros = {
        Compile: function( macro ) {
            var result = { commands: [], errors: [] };

            return result;
        },
        Run: function( editor, macro ) {
            var result = Macros.Compile(macro);
            if ( result.errors ) return false;
            var state = {};

            editor.operation( function() {
                $.each( result.commands, function( undef, command ) {
                    command( editor, state );
                } );
            } );
        },
    };
} );
