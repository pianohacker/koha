package C4::Calendar;

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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use Modern::Perl;
use vars qw($VERSION @EXPORT);

use Carp;

use C4::Context;

our ( @ISA, @EXPORT );

BEGIN {
    @ISA = qw( Exporter );
    @EXPORT = qw(
        GetSingleEvents
        GetWeeklyEvents
        GetYearlyEvents
        AddSingleEvent
        AddRepeatingEvent
        ModSingleEvent
        ModRepeatingEvent
        DelSingleEvent
        DelRepeatingEvent
    );
}

use constant ISO_DATE_FORMAT => "%04d-%02d-%02d";
=head1 NAME

C4::Calendar::Calendar - Koha module dealing with holidays.

=head1 SYNOPSIS

    use C4::Calendar::Calendar;

=head1 DESCRIPTION

This package is used to deal with holidays. Through this package, you can set 
all kind of holidays for the library.

=head1 FUNCTIONS

=head2 new

  $calendar = C4::Calendar->new(branchcode => $branchcode);

Each library branch has its own Calendar.  
C<$branchcode> specifies which Calendar you want.

=cut

sub GetSingleEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            event_date, open_hour, open_minute, close_hour, close_minute,
            (open_hour = open_minute = close_hour = close_minute = 0) AS closed
        FROM calendar_events
        WHERE branchcode = ?
    }, { Slice => {} }, $branchcode );
}

sub GetWeeklyEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            weekday, open_hour, open_minute, close_hour, close_minute,
            (open_hour = open_minute = close_hour = close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NOT NULL
    }, { Slice => {} }, $branchcode ); 
}

sub GetYearlyEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            month, day, open_hour, open_minute, close_hour, close_minute,
            (open_hour = open_minute = close_hour = close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NULL
    }, { Slice => {} }, $branchcode );
}

sub AddSingleEvent {
}

sub AddRepeatingEvent {
}

sub ModSingleEvent {
}

sub ModRepeatingEvent {
}

sub DelSingleEvent {
}

sub DelRepeatingEvent {
}

1;

__END__

=head1 AUTHOR

Koha Physics Library UNLP <matias_veleda@hotmail.com>

=cut
