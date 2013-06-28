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
            event_date, open_hour, open_minute, close_hour, close_minute, title, description,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_events
        WHERE branchcode = ?
    }, { Slice => {} }, $branchcode );
}

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

sub ModSingleEvent {
    my ( $branchcode, $date, $info ) = @_;

    use Data::Dumper; warn Dumper([@_]);

    C4::Context->dbh->do( q{
        INSERT INTO calendar_events(branchcode, event_date, open_hour, open_minute, close_hour, close_minute, title, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE open_hour = ?, open_minute = ?, close_hour = ?, close_minute = ?, title = ?, description = ?
    }, {}, $branchcode, $date, ( map { $info->{$_} } qw(open_hour open_minute close_hour close_minute title description) ) x 2 );
}

sub ModRepeatingEvent {
    my ( $branchcode, $weekday, $month, $day, $info ) = @_;

    C4::Context->dbh->do( q{
        INSERT INTO calendar_repeats(branchcode, weekday, month, day, open_hour, open_minute, close_hour, close_minute, title, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE open_hour = ?, open_minute = ?, close_hour = ?, close_minute = ?, title = ?, description = ?
    }, {}, $branchcode, $weekday, $month, $day, ( map { $info->{$_} } qw(open_hour open_minute close_hour close_minute title description) ) x 2 );
}

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

sub DelRepeatingEvent {
    my ( $branchcode, $weekday, $month, $day ) = @_;

    C4::Context->dbh->do( q{
        DELETE FROM calendar_repeats
        WHERE branchcode = ?
    } . _get_compare( 'weekday', $weekday ) . _get_compare( 'month', $month ) . _get_compare( 'day', $day ), {}, $branchcode, $weekday, $month, $day );
}

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
