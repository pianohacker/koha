package C4::Auth_with_ExtAuthSrc;

# Modified by Mark Tompsett, Copyright 2013.
# based on code from BibLibre, Copyright 2011.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use base qw( Exporter );
our $VERSION = 1;    # set the version for version checking
our @EXPORT_OK = qw(logout_extauthsrc login_extauthsrc_url);

use C4::Debug;
use C4::Context;
use Carp;
use CGI;
use Modern::Perl;

use Readonly;
Readonly my $RIGHTMOST_CHAR => -1;
Readonly my $NOT_IN_STRING  => -1;
Readonly my $SLASH          => q{/};
Readonly my $QUESTION_MARK  => q{?};
Readonly our $debug         => $ENV{DEBUG};

# Logout from External Authentication Source
sub logout_extauthsrc {
    my ( $query, $type ) = @_;

    my $ExtAuthSrc = C4::Context->config('ExtAuthSrc')
         or croak 'No "ExtAuthSrc" in server hash from KOHA_CONF: ' . $ENV{KOHA_CONF};
    my $uri = $ExtAuthSrc->{'LogoutURL'};
    my $return_key = $ExtAuthSrc->{'ReturnKey'};
    my $return_to = C4::Context->preference('OPACBaseURL');

    my $logout_url;
    if ( index( $uri, $QUESTION_MARK ) == $NOT_IN_STRING ) {
        $logout_url = $uri . "?$return_key=$return_to";
    }
    else {
        $logout_url = $uri . "&$return_key=$return_to";
    }

    my $redirect = $query->redirect($logout_url);
    print $redirect;
    return;
}

# Returns External Authentication Source login URL
# with callback to the requesting URL
sub login_extauthsrc_url {
    my ( $query, $type ) = @_;

    my $ExtAuthSrc = C4::Context->config('ExtAuthSrc')
         or croak 'No "ExtAuthSrc" in server hash from KOHA_CONF: ' . $ENV{KOHA_CONF};
    my $uri = $ExtAuthSrc->{'LoginURL'};
    my $return_key = $ExtAuthSrc->{'ReturnKey'};
    my $return_to = C4::Context->preference('OPACBaseURL');

    if ( substr( $return_to, $RIGHTMOST_CHAR, 1 ) ne $SLASH ) {
        $return_to = $return_to . $SLASH;
    }
    $return_to = $return_to . 'cgi-bin/koha/svc/hack.pl';

    my $login_url;
    if ( index( $uri, $QUESTION_MARK ) == $NOT_IN_STRING ) {
        $login_url = $uri . "?$return_key=$return_to";
    }
    else {
        $login_url = $uri . "&$return_key=$return_to";
    }

    return $login_url;
}

1;
