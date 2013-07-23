<script>

var editorWidgets = {
    '000': {
        init: function() {
            var $result = $( '<span class="subfield-widget">Leader</span>' );

            return $result[0];
        },
        postCreate: function( widget, mark ) {
        }
    },
    '008': {
        init: function() {
            var $result = $( '<span class="subfield-widget">Fixed data</span>' );

            return $result[0];
        },
        postCreate: function( widget, mark ) {
        }
    }
};

</script>
