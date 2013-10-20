package C4::Auth_with_Shibboleth;

# Copyright 2011 BibLibre
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

use C4::Debug;
use C4::Context;
use C4::Members qw( AddMember_Auto );
use Carp;
use CGI;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $debug);

BEGIN {
    require Exporter;
    $VERSION = 3.03;                                                                    # set the version for version checking
    $debug   = $ENV{DEBUG} || 1;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(logout_shib login_shib_url checkpw_shib get_login_shib);
}
my $context = C4::Context->new() or die 'C4::Context->new failed';

# Logout from Shibboleth
sub logout_shib {
    my ($query) = @_;
    my $uri = ($query->https() ? "https://" : "http://") . $ENV{'SERVER_NAME'};
    print $query->redirect( $uri . "/Shibboleth.sso/Logout?return=$uri" );
}

# Returns Shibboleth login URL with callback to the requesting URL
sub login_shib_url {

    my ($query) = @_;
    my $base = ($query->https() ? "https://" : "http://") . $ENV{'SERVER_NAME'};
    my $param = $base . $query->script_name();
    my $uri = $base . "/Shibboleth.sso/Login?target=$param";
    return $uri;
}

# Returns shibboleth user login
sub get_login_shib {

    # In case of a Shibboleth authentication, we expect a shibboleth user attribute (defined in the shibbolethLoginAttribute)
    # to contain the login of the shibboleth-authenticated user

    # Shibboleth attributes are mapped into http environmement variables,
    # so we're getting the login of the user this way

    my $shib = C4::Context->config('shibboleth') or croak 'No <shibboleth> in koha-conf.xml';

    my $shibbolethLoginAttribute = $shib->{'userid'};
    $debug and warn "shibboleth->userid value: $shibbolethLoginAttribute";
    $debug and warn "$shibbolethLoginAttribute value: " . $ENV{$shibbolethLoginAttribute};

    return $ENV{$shibbolethLoginAttribute} || '';
}

sub _autocreate {
    my ( $dbh, $shib, $userid ) = @_;

    my %borrower = ( userid => $userid );

    while ( my ( $key, $entry ) = each %{$shib->{'mapping'}} ) {
        $borrower{$key} = ( $entry->{'is'} && $ENV{ $entry->{'is'} } ) || $entry->{'content'} || '';
    }

    %borrower = AddMember_Auto( %borrower );

    return ( 1, $borrower{'cardnumber'}, $borrower{'userid'} );
}

# Checks for password correctness
# In our case : does the given username matches one of our users ?
sub checkpw_shib {
    $debug and warn "checkpw_shib";

    my ( $dbh, $userid ) = @_;
    my $retnumber;
    $debug and warn "User Shibboleth-authenticated as: $userid";

    my $shib = C4::Context->config('shibboleth') or croak 'No <shibboleth> in koha-conf.xml';

    # Does it match one of our users ?
    my $sth = $dbh->prepare("select cardnumber from borrowers where userid=?");
    $sth->execute($userid);
    if ( $sth->rows ) {
        $retnumber = $sth->fetchrow;
        return ( 1, $retnumber, $userid );
    }
    $sth = $dbh->prepare("select userid from borrowers where cardnumber=?");
    $sth->execute($userid);
    if ( $sth->rows ) {
        $retnumber = $sth->fetchrow;
        return ( 1, $retnumber, $userid );
    }

    if ( $shib->{'autocreate'} ) {
        return _autocreate( $dbh, $shib, $userid );
    } else {
        # If we reach this point, the user is not a valid koha user
        $debug and warn "User $userid is not a valid Koha user";
        return 0;
    }
}

1;
