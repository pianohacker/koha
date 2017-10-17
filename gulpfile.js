/* eslint-env node */
/* eslint no-console:"off" */

let gulp;

try {
    gulp = require( "gulp" );
} catch(e) {
    console.error("You are missing required Node modules; run `npm install`.");
    process.exit(1);
}

const browserify = require( "browserify" );
const gutil = require( "gulp-util" );
const source = require( "vinyl-source-stream" );
const tap = require( "gulp-tap" );

const BASE = "koha-tmpl/intranet-tmpl/prog/js";
const BUILT_FILES = BASE + "/src/**/entry.js";
const WATCHED_FILES = BASE + "/src/**/*.js";

// These node modules will be shoved into vendor.js instead of each built file.
const VENDOR_DEPENDENCIES = [
    "lodash",
    "promise-polyfill",
    "react",
    "react-dom",
    "whatwg-fetch",
];

gulp.task( "watch", () => {
    // TODO: Remove deprecated gulp.start
    gulp.start( "build" );
    gulp.watch( WATCHED_FILES, [ "build" ] );
} );

let vendorBuilt = false;

gulp.task( "build", () => {
    let bundler = browserify( {
        debug: true
    } )
        .transform( "babelify", { presets: [ "es2015", "react" ], plugins: [ "transform-class-properties" ] } );

    if ( !vendorBuilt ) {
        browserify( {
            require: VENDOR_DEPENDENCIES,
            debug: true,
        } )
            .bundle()
            .on( "error", gutil.log )
            .pipe( source( "vendor.js" ) )
            .pipe( gulp.dest( BASE + "/built/" ) );
    }


    return gulp.src( BUILT_FILES )
        .pipe( tap( file => {
            let base_start = file.path.indexOf( BASE );
            gutil.log( `bundling ${file.path.substr( base_start + BASE.length + 1 )}` );

            bundler.external( VENDOR_DEPENDENCIES );
            file.contents = bundler.add( file.path ).bundle();
        } ) )
        .pipe( gulp.dest( BASE + "/built" ) );
} );

gulp.task( "default", [ "build" ] );
