define( function() {
    var Preferences = {
        Load: function( borrowernumber ) {
            if ( !borrowernumber ) return;
            var saved_prefs;
            try {
                saved_prefs = JSON.parse( localStorage[ 'cateditor_preferences_' + borrowernumber ] );
            } catch (e) {}

            Preferences.user = $.extend( {
                // Preference defaults
                fieldWidgets: true,
                font: 'monospace',
                fontSize: '1em',
                macros: {},
            }, saved_prefs );
        },

        Save: function( borrowernumber ) {
            if ( !borrowernumber ) return;
            if ( !Preferences.user ) Preferences.Load(borrowernumber);

            localStorage[ 'cateditor_preferences_' + borrowernumber ] = JSON.stringify(Preferences.user);
        },
    };

    return Preferences;
} );
