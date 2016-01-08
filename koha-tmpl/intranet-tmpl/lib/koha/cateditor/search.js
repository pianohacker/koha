/**
 * Copyright 2015 ByWater Solutions
 *
 * This file is part of Koha.
 *
 * Koha is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Koha is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Koha; if not, see <http://www.gnu.org/licenses>.
 */

define( [ 'koha-backend', 'marc-record' ], function( KohaBackend, MARC ) {
    var _options;
    var _records = {};
    var _last;

    var Search = {
        Init: function( options ) {
            _options = options;
        },
        Run: function( servers, terms, options ) {
            options = $.extend( {
                offset: 0,
                page_size: 20,
            }, _options, options );

            Search.includedServers = [];
            _records = {};
            _last = {
                servers: servers,
                terms: terms,
                options: options,
            };

            var newTerms = {};
            $.each( terms, function( index, value ) {
                newTerms[ "term-" + index ] = value;
            } );
            terms = newTerms;

            var itemTag = KohaBackend.GetSubfieldForKohaField('items.itemnumber')[0];

            $.each( servers, function ( id, info ) {
                if ( info.checked ) Search.includedServers.push( id );
            } );

            if ( Search.includedServers.length == 0 ) return false;

            $.get(
                '/cgi-bin/koha/svc/cataloguing/metasearch',
                $.extend( {
                    servers: Search.includedServers.join( ',' ),
                    offset: options.offset,
                    page_size: options.page_size,
                    sort_direction: options.sort_direction,
                    sort_key: options.sort_key,
                    resultset: options.resultset,
                }, terms )
            )
                .done( function( data ) {
                    _last.options.resultset = data.resultset;
                    $.each( data.hits, function( undef, hit ) {
                        var record = new MARC.Record();
                        record.loadMARCXML( hit.record );
                        hit.record = record;

                        if ( hit.server == 'koha:biblioserver' ) {
                            // Remove item tags
                            while ( record.removeField(itemTag) );
                        }
                    } );

                    _options.onresults( data );
                } )
                .fail( function( error ) {
                    _options.onerror( error );
                } );

            return true;
        },
        Fetch: function( options ) {
            if ( !_last ) return;
            $.extend( _last.options, options );
            return Search.Run( _last.servers, _last.terms, _last.options );
        }
    };

    return Search;
} );
