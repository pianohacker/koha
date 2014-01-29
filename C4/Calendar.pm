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

use Koha::Database;

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
            CONCAT(LPAD(year, 4, '0'), '-', LPAD(month, 2, '0'), '-', LPAD(day, 2, '0')) as event_date,
            0 as open_hour, 0 as open_minute, IF(isexception, 24, 0) as close_hour,
            0 as close_minute, title, description, IF(isexception, 0, 1) as closed
        FROM special_holidays
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
            weekday, 0 as open_hour, 0 as open_minute, 0 as close_hour,
            0 as close_minute, title, description, 1 as closed
        FROM repeatable_holidays
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
            month, day, 0 as open_hour, 0 as open_minute, 0 as close_hour,
            0 as close_minute, title, description, 1 as closed
        FROM repeatable_holidays
        WHERE branchcode = ? AND weekday IS NULL
    }, { Slice => {} }, $branchcode );
}

=head2 ModSingleEvent

  ModSingleEvent( $branchcode, \%info )

Creates or updates an event for a single date. $info->{date} should be an
ISO-formatted date string, and \%info should also contain the following keys:
open_hour, open_minute, close_hour, close_minute, title and description.

=cut

sub ModSingleEvent {
    my ( $branchcode, $info ) = @_;

    my ( $year, $month, $day ) = ( $info->{date} =~ /(\d+)-(\d+)-(\d+)/ );
    return unless ( $year && $month && $day );

    my $dbh = C4::Context->dbh;
    my @args = ( ( map { $info->{$_} } qw(title description) ), $info->{close_hour} != 0, $branchcode, $year, $month, $day );

    # The code below relies on $dbh->do returning 0 when the update affects no rows
    my $affected = $dbh->do( q{
        UPDATE special_holidays
        SET
            title = ?, description = ?, isexception = ?
        WHERE branchcode = ? AND year = ? AND month = ? AND day = ?
    }, {}, @args );

    $dbh->do( q{
        INSERT
        INTO special_holidays(title, description, isexception, branchcode, year, month, day)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    }, {}, @args ) unless ( $affected > 0 );
}

=head2 ModRepeatingEvent

  ModRepeatingEvent( $branchcode, \%info )

Creates or updates a weekly- or yearly-repeating event. Either $info->{weekday},
or $info->{month} and $info->{day} should be set, for a weekly or yearly event,
respectively.

=cut

sub _get_compare {
    my ( $colname, $value ) = @_;

    return ' AND ' . $colname . ' ' . ( defined( $value ) ? '=' : 'IS' ) . ' ?';
}

sub ModRepeatingEvent {
    my ( $branchcode, $info ) = @_;

    my $dbh = C4::Context->dbh;
    my $open = ( $info->{close_hour} != 0 );

    if ($open) {
        $dbh->do( q{
            DELETE FROM repeatable_holidays
            WHERE branchcode = ?
        } . _get_compare( 'weekday', $info->{weekday} ) . _get_compare( 'month', $info->{month} ) . _get_compare( 'day', $info->{day} ), {}, $branchcode, $info->{weekday}, $info->{month}, $info->{day} );
    } else {
        my @args = ( ( map { $info->{$_} } qw(title description) ), $branchcode, $info->{weekday}, $info->{month}, $info->{day} );

        # The code below relies on $dbh->do returning 0 when the update affects no rows
        my $affected = $dbh->do( q{
            UPDATE repeatable_holidays
            SET
                title = ?, description = ?
            WHERE branchcode = ?
        } . _get_compare( 'weekday', $info->{weekday} ) . _get_compare( 'month', $info->{month} ) . _get_compare( 'day', $info->{day} ), {}, @args );

        $dbh->do( q{
            INSERT
            INTO repeatable_holidays(title, description, branchcode, weekday, month, day)
            VALUES (?, ?, ?, ?, ?, ?)
        }, {}, @args ) unless ( $affected > 0 );
    }
}

=head2 DelSingleEvent

  DelSingleEvent( $branchcode, \%info )

Deletes an event for a single date. $info->{date} should be an ISO-formatted date string.

=cut

sub DelSingleEvent {
    my ( $branchcode, $info ) = @_;

    my ( $year, $month, $day ) = ( $info->{date} =~ /(\d+)-(\d+)-(\d+)/ );
    return unless ( $year && $month && $day );

    C4::Context->dbh->do( q{
        DELETE FROM special_holidays
        WHERE branchcode = ? AND year = ? AND month = ? AND day = ?
    }, {}, $branchcode, $year, $month, $day );
}

=head2 DelRepeatingEvent

  DelRepeatingEvent( $branchcode, \%info )

Deletes a weekly- or yearly-repeating event. Either $info->{weekday}, or
$info->{month} and $info->{day} should be set, for a weekly or yearly event,
respectively.

=cut

sub DelRepeatingEvent {
    my ( $branchcode, $info ) = @_;

    C4::Context->dbh->do( q{
        DELETE FROM repeatable_holidays
        WHERE branchcode = ?
    } . _get_compare( 'weekday', $info->{weekday} ) . _get_compare( 'month', $info->{month} ) . _get_compare( 'day', $info->{day} ), {}, $branchcode, $info->{weekday}, $info->{month}, $info->{day} );
}

=head2 CopyAllEvents

  CopyAllEvents( $from_branchcode, $to_branchcode )

Copies all events from one branch to another.

=cut

sub CopyAllEvents {
    my ( $from_branchcode, $to_branchcode ) = @_;

    C4::Context->dbh->do( q{
        INSERT IGNORE INTO special_holidays(branchcode, year, month, day, isexception, title, description)
        SELECT ?, year, month, day, isexception, title, description
        FROM special_holidays
        WHERE branchcode = ?
    }, {}, $to_branchcode, $from_branchcode );

    C4::Context->dbh->do( q{
        INSERT IGNORE INTO repeatable_holidays(branchcode, weekday, month, day, title, description)
        SELECT ?, weekday, month, day, title, description
        FROM repeatable_holidays
        WHERE branchcode = ?
    }, {}, $to_branchcode, $from_branchcode );
}


1;

__END__

=head1 AUTHOR

Koha Physics Library UNLP <matias_veleda@hotmail.com>
Jesse Weaver <jweaver@bywatersolutions.com>

=cut
