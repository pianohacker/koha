( function ($) {
    category_types = [
        'A',
        'I',
        'C',
        'X',
        'S',
        'P',
    ];

    function hsv_to_rgb(h, s, v) {
        var r, g, b;
        var f, p, q, t;

        var h = Math.max(0, Math.min(h, 359));
        var s = Math.max(0, Math.min(s, 1));
        var v = Math.max(0, Math.min(v, 1));

        if(s == 0) {
            var color = [v, v, v];
        } else {
            h /= 60; // sector 0 to 5
            f = h % 1; // fractional part of h
            p = v * (1 - s);
            q = v * (1 - s * f);
            t = v * (1 - s * (1 - f));

            var color = [
                [v, t, p],
                [q, v, p],
                [p, v, t],
                [p, q, v],
                [t, p, v],
                [v, p, q],
            ][Math.floor(h)];
        }

        function c(i) { return Math.floor(color[i] * 255) }

        return 'rgb(' + [c(0), c(1), c(2)].join(', ') + ')';
    }

    var brightness_steps = 6;

    $( document ).ready( function() {
        $( '.colorized-category' ).each( function() {
            var split_category = $(this).attr( 'data-cathashinfo' ).split( '|' );

            if ( !split_category ) return;

            var category = split_category[0] + '|' + split_category.slice(1).join( '|' );

            // FNV-1a 32-bit hash
            // Mostly chosen through trial and error
            var hash = 2166136261;

            for (var i = 0; i < split_category[1].length; i++) {
                hash ^= split_category[1].charCodeAt(i);
                hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
            }
            hash &= 0x00000000ffffffff;
            if (hash < 0) hash += Math.pow(2, 32);

            var brightness = hash % brightness_steps;
            var h = 30 + category_types.indexOf(category[0]) * 63;
            var s = 0.4 + (brightness_steps - 1 - brightness) * 0.125; // 100% - 40%
            var v = 0.5 + brightness * 0.1; // 50% - 100%

            $(this).css( 'background-color', hsv_to_rgb(h, s, v) );
            if ( v < 0.85 ) {
                $(this).css( 'color', 'white' );
                $(this).find( 'a' ).css( 'color', 'white' );
            }
        } );
    } );
} )(jQuery);
