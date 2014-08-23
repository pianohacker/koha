package Koha::Service::Authentication;

# This file is part of Koha.
#
# Copyright 2007 LibLime
# Copyright (C) 2014 ByWater Solutions
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

# Handles authentication and output manually, so no reason to inherit from Koha::Service::XML
use base 'Koha::Service';

use C4::Auth qw/check_api_auth/;
use CGI;
use XML::Simple;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { editcatalogue => 'edit_catalogue'},
    } );
}

sub handle_auth_failure {
    # Stub, to allow run() to output XML itself.
}

sub run {
    my ( $self ) = @_;
    # The authentication strategy for the biblios web 
    # services is as follows.
    # 
    # 1. biblios POSTs to the authenticate API with URL-encoded
    # form parameters 'userid' and 'password'.  If the credentials
    # belong to a valid user with the 'editcatalogue' privilege,
    # a session cookie is returned and a Koha session created.  Otherwise, an 
    # appropriate error is returned.
    # 2. For subsequent calls to the biblios APIs, the user agent
    # should submit the same session cookie.  If the cookie is
    # not supplied or does not correspond to a valid session, the API
    # will redirect to this authentication API.
    # 3. The session cookie should not be (directly) sent back to the user's
    # web browser, but instead should be stored and submitted by biblios.

    $self->authenticate;

    # Can't reuse Koha::Service::XML, as result node has different name.
    $self->output( XMLout({ status => $self->auth_status }, NoAttr => 1, RootName => 'response', XMLDecl => 1), { type => 'xml' } );
}

1;
