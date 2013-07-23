<script>

/**
 * Each widget should provide one to three methods:
 *   init( text ): Returns the DOM node for this widget. Return null to hide the
 *                 subfield completely.
 *   postCreate( node, mark ): Optional, called once the mark has been created
 *                             and the node shown. Bind event handlers here.
 *   makeTemplate(): Optional, should return some sane default contents for a
 *                   newly created field/subfield. '<empty>' will be used if this
 *                   method is unset.
 *
 * Following the Koha convention, control fields are defined as tags with a
 * single subfield, '@'.
 */

function updateWidgetContents( mark, contents ) {
    var range = mark.find();
    mark.doc.replaceRange( contents, range.from, range.to );
}

function zeroPad( number, length ) {
    var result = number.toString();

    while ( result.length < length ) result = ' ' + result;

    return result;
}

var editorWidgets = {
    '000@': {
        makeTemplate: function() {
            return '     nam a22     7a 4500';
        },
        init: function( text ) {
            var $result = $( '<span class="subfield-widget">Leader</span>' );

            return $result[0];
        },
        postCreate: function( node, mark ) {
        },
    },
    '008@': {
        init: function() {
            var $result = $( '<span class="subfield-widget">Fixed data</span>' );

            return $result[0];
        },
        postCreate: function( node, mark ) {
        }
    },
    '245a': {
        init: function( text ) {
            var $result = $( '<span class="subfield-widget">Title: ' + text + '</span>' );

            return $result[0];
        },
        postCreate: function( node, mark ) {
        }
    }
};

</script>
