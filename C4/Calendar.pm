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
        ModSingleEvent
        ModRepeatingEvent
        DelSingleEvent
        DelRepeatingEvent
        CopyAllEvents
    );
}

use constant ISO_DATE_FORMAT => "%04d-%02d-%02d";
=head1 NAME

C4::Calendar - Koha module dealing with holidays.

=head1 SYNOPSIS

    use C4::Calendar;

=head1 DESCRIPTION

This package is used to deal with hours and holidays;

=head1 FUNCTIONS

=head2 GetSingleEvents

  \@events = GetSingleEvents( $branchcode )

Get the non-repeating events for the given library.

=cut

sub GetSingleEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            event_date, open_hour, open_minute, close_hour, close_minute, title, description,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_events
        WHERE branchcode = ?
    }, { Slice => {} }, $branchcode );
}

=head2 GetWeeklyEvents

  \@events = GetWeeklyEvents( $branchcode )

Get the weekly-repeating events for the given library.

=cut

sub GetWeeklyEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            weekday, open_hour, open_minute, close_hour, close_minute, title, description,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NOT NULL
    }, { Slice => {} }, $branchcode ); 
}

=head2 GetYearlyEvents

  \@events = GetYearlyEvents( $branchcode )

Get the yearly-repeating events for the given library.

=cut

sub GetYearlyEvents {
    my ( $branchcode ) = @_;

    return C4::Context->dbh->selectall_arrayref( q{
        SELECT
            month, day, open_hour, open_minute, close_hour, close_minute, title, description,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NULL
    }, { Slice => {} }, $branchcode );
}

=head2 ModSingleEvent

  ModSingleEvent( $branchcode, $date, \%info )

Creates or updates an event for a single date. $date should be an ISO-formatted
date string, and \%info should contain the following keys: open_hour,
open_minute, close_hour, close_minute, title and description.

=cut

sub ModSingleEvent {
    my ( $branchcode, $date, $info ) = @_;

    C4::Context->dbh->do( q{
        INSERT INTO calendar_events(branchcode, event_date, open_hour, open_minute, close_hour, close_minute, title, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE open_hour = ?, open_minute = ?, close_hour = ?, close_minute = ?, title = ?, description = ?
    }, {}, $branchcode, $date, ( map { $info->{$_} } qw(open_hour open_minute close_hour close_minute title description) ) x 2 );
}

=head2 ModRepeatingEvent

  ModRepeatingEvent( $branchcode, $weekday, $month, $day, \%info )

Creates or updates a weekly- or yearly-repeating event. Either $weekday,
or $month and $day should be set, for a weekly or yearly event, respectively.

=cut

sub ModRepeatingEvent {
    my ( $branchcode, $weekday, $month, $day, $info ) = @_;

    C4::Context->dbh->do( q{
        INSERT INTO calendar_repeats(branchcode, weekday, month, day, open_hour, open_minute, close_hour, close_minute, title, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE open_hour = ?, open_minute = ?, close_hour = ?, close_minute = ?, title = ?, description = ?
    }, {}, $branchcode, $weekday, $month, $day, ( map { $info->{$_} } qw(open_hour open_minute close_hour close_minute title description) ) x 2 );
}

=head2 DelSingleEvent

  DelSingleEvent( $branchcode, $date, \%info )

Deletes an event for a single date. $date should be an ISO-formatted date string.

=cut

sub DelSingleEvent {
    my ( $branchcode, $date ) = @_;

    C4::Context->dbh->do( q{
        DELETE FROM calendar_events
        WHERE branchcode = ? AND event_date = ?
    }, {}, $branchcode, $date );
}

sub _get_compare {
    my ( $colname, $value ) = @_;

    return ' AND ' . $colname . ' ' . ( defined( $value ) ? '=' : 'IS' ) . ' ?';
}

=head2 DelRepeatingEvent

  DelRepeatingEvent( $branchcode, $weekday, $month, $day )

Deletes a weekly- or yearly-repeating event. Either $weekday, or $month and
$day should be set, for a weekly or yearly event, respectively.

=cut

sub DelRepeatingEvent {
    my ( $branchcode, $weekday, $month, $day ) = @_;

    C4::Context->dbh->do( q{
        DELETE FROM calendar_repeats
        WHERE branchcode = ?
    } . _get_compare( 'weekday', $weekday ) . _get_compare( 'month', $month ) . _get_compare( 'day', $day ), {}, $branchcode, $weekday, $month, $day );
}

=head2 CopyAllEvents

  CopyAllEvents( $from_branchcode, $to_branchcode )

Copies all events from one branch to another.

=cut

sub CopyAllEvents {
    my ( $from_branchcode, $to_branchcode ) = @_;

    C4::Context->dbh->do( q{
        INSERT IGNORE INTO calendar_events(branchcode, event_date, open_hour, open_minute, close_hour, close_minute, title, description)
        SELECT ?, event_date, open_hour, open_minute, close_hour, close_minute, title, description
        FROM calendar_events
        WHERE branchcode = ?
    }, {}, $to_branchcode, $from_branchcode );

    C4::Context->dbh->do( q{
        INSERT IGNORE INTO calendar_repeats(branchcode, weekday, month, day, open_hour, open_minute, close_hour, close_minute, title, description)
        SELECT ?, weekday, month, day, open_hour, open_minute, close_hour, close_minute, title, description
        FROM calendar_repeats
        WHERE branchcode = ?
    }, {}, $to_branchcode, $from_branchcode );
}


1;

__END__

=head1 AUTHOR

Koha Physics Library UNLP <matias_veleda@hotmail.com>

=cut
