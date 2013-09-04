define( function() {
    var Preferences = {
        Load: function( borrowernumber ) {
            var saved_prefs;
            try {
                saved_prefs = JSON.parse( $.cookie( 'cateditor_preferences_' + borrowernumber ) );
            } catch (e) {}

            Preferences.user = $.extend( {
                // Preference defaults
                field_widgets: true,
            }, saved_prefs );
        },

        Save: function( borrowernumber ) {
            if ( !Preferences.user ) Preferences.Load(borrowenumber);

            $.cookie( 'cateditor_preferences_' + borrowernumber, JSON.stringify(Preferences.user), { expires: 3650, path: '/' } );
        },
    };

    return Preferences;
} );
