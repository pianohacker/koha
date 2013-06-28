package Koha::Calendar;
use strict;
use warnings;
use 5.010;

use DateTime;
use DateTime::Set;
use DateTime::Duration;
use C4::Context;
use Carp;
use Readonly;

sub new {
    my ( $classname, %options ) = @_;
    my $self = {};
    bless $self, $classname;
    for my $o_name ( keys %options ) {
        my $o = lc $o_name;
        $self->{$o} = $options{$o_name};
    }
    if ( !defined $self->{branchcode} ) {
        croak 'No branchcode argument passed to Koha::Calendar->new';
    }
    $self->_init();
    return $self;
}

sub _init {
    my $self       = shift;
    my $branch     = $self->{branchcode};
    my $dbh        = C4::Context->dbh();

    $self->{weekday_hours} = $dbh->selectall_hashref( q{
        SELECT
            weekday, open_hour, open_minute, close_hour, close_minute,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NOT NULL
    }, 'weekday', { Slice => {} }, $branch ); 

    my $day_month_hours = $dbh->selectall_arrayref( q{
        SELECT
            month, day, open_hour, open_minute, close_hour, close_minute,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_repeats
        WHERE branchcode = ? AND weekday IS NULL
    }, { Slice => {} }, $branch );

    # DBD::Mock doesn't support multi-key selectall_hashref, so we do it ourselves for now
    foreach my $day_month ( @$day_month_hours ) {
        $self->{day_month_hours}->{ $day_month->{month} }->{ $day_month->{day} } = $day_month;
    }

    $self->{date_hours} = $dbh->selectall_hashref( q{
        SELECT
            event_date, open_hour, open_minute, close_hour, close_minute,
            (open_hour = 0 AND open_minute = 0 AND close_hour = 0 AND close_minute = 0) AS closed
        FROM calendar_events
        WHERE branchcode = ?
    }, 'event_date', { Slice => {} }, $branch );

    $self->{days_mode}       = C4::Context->preference('useDaysMode');
    $self->{test}            = 0;
    return;
}

sub addDate {
    my ( $self, $startdate, $add_duration, $unit ) = @_;

    # Default to days duration (legacy support I guess)
    if ( ref $add_duration ne 'DateTime::Duration' ) {
        $add_duration = DateTime::Duration->new( days => $add_duration );
    }

    $unit ||= 'days'; # default days ?
    my $dt;

    if ( $unit eq 'hours' ) {
        $dt = $self->addHours($startdate, $add_duration);
    } else {
        # days
        $dt = $self->addDays($startdate, $add_duration);
    }

    return $dt;
}

sub addHours {
    my ( $self, $startdate, $hours_duration ) = @_;
    my $base_date = $startdate->clone();

    if ( $self->{days_mode} eq 'Days' ) {
        $base_date->add_duration( $hours_duration );
        return $base_date;
    }
    my $hours = $self->get_hours_full( $base_date );

    if ( $hours_duration->is_negative() ) {
        if ( $base_date <= $hours->{open_time} ) {
            # Library is already closed
            $base_date = $self->prev_open_day( $base_date );
            $hours = $self->get_hours_full( $base_date );
            $base_date = $hours->{close_time}->clone;

            if ( $self->{days_mode} eq 'Calendar' ) {
                return $base_date;
            }
        }

        while ( $hours_duration->is_negative ) {
            my $day_len = $hours->{open_time} - $base_date;

            if ( DateTime::Duration->compare( $day_len, $hours_duration, $base_date ) < 0 ) {
                $hours_duration->subtract( $day_len );
                $base_date = $self->prev_open_day( $base_date );
                $hours = $self->get_hours_full( $base_date );
                $base_date = $hours->{close_time}->clone;
            } else {
                $base_date->add_duration( $hours_duration );
                return $base_date;
            }
        }
    } else {
        if ( $base_date >= $hours->{close_time} ) {
            # Library is already closed
            $base_date = $self->next_open_day( $base_date );
            $hours = $self->get_hours_full( $base_date );
            $base_date = $hours->{open_time}->clone;

            if ( $self->{days_mode} eq 'Calendar' ) {
                return $base_date;
            }
        }

        while ( $hours_duration->is_positive ) {
            my $day_len = $hours->{close_time} - $base_date;

            if ( DateTime::Duration->compare( $day_len, $hours_duration, $base_date ) > 0 ) {
                $hours_duration->subtract( $day_len );
                $base_date = $self->next_open_day( $base_date );
                $hours = $self->get_hours_full( $base_date );
                $base_date = $hours->{open_time}->clone;
            } else {
                $base_date->add_duration( $hours_duration );
                return $base_date;
            }
        }
    }

    return $base_date;
}

sub addDays {
    my ( $self, $startdate, $days_duration ) = @_;
    my $base_date = $startdate->clone();

    if ( $self->{days_mode} eq 'Calendar' ) {
        # use the calendar to skip all days the library is closed
        # when adding
        my $days = abs $days_duration->in_units('days');

        if ( $days_duration->is_negative() ) {
            while ($days) {
                $base_date = $self->prev_open_day($base_date);
                --$days;
            }
        } else {
            while ($days) {
                $base_date = $self->next_open_day($base_date);
                --$days;
            }
        }

    } else { # Days or Datedue
        # use straight days, then use calendar to push
        # the date to the next open day if Datedue
        $base_date->add_duration($days_duration);

        if ( $self->{days_mode} eq 'Datedue' ) {
            # Datedue, then use the calendar to push
            # the date to the next open day if holiday
            if ( $self->is_holiday($base_date) ) {
                if ( $days_duration->is_negative() ) {
                    $base_date = $self->prev_open_day($base_date);
                } else {
                    $base_date = $self->next_open_day($base_date);
                }
            }
        }
    }

    return $base_date;
}

sub is_holiday {
    my ( $self, $dt ) = @_;
    my $day   = $dt->day;
    my $month = $dt->month;

    if ( exists $self->{date_hours}->{ $dt->ymd } && !$self->{date_hours}->{ $dt->ymd }->{closed} ) {
        return 0;
    }

    if ( ( $self->{day_month_hours}->{$month}->{$day} || {} )->{closed} ) {
        return 1;
    }

    # We use 0 for Sunday, not 7
    my $dow = $dt->day_of_week % 7;

    if ( ( $self->{weekday_hours}->{ $dow } || {} )->{closed} ) {
        return 1;
    }

    if ( ( $self->{date_hours}->{ $dt->ymd } || {} )->{closed} ) {
        return 1;
    }

    # damn have to go to work after all
    return 0;
}

sub get_hours {
    my ( $self, $dt ) = @_;
    my $day   = $dt->day;
    my $month = $dt->month;

    if ( exists $self->{date_hours}->{ $dt->ymd } ) {
        return $self->{date_hours}->{ $dt->ymd };
    }

    if ( exists $self->{day_month_hours}->{$month}->{$day} ) {
        return $self->{day_month_hours}->{$month}->{$day};
    }

    # We use 0 for Sunday, not 7
    my $dow = $dt->day_of_week % 7;

    if ( exists $self->{weekday_hours}->{ $dow } ) {
        return $self->{weekday_hours}->{ $dow };
    }

    # Assume open
    return {
        open_hour => 0,
        open_minute => 0,
        close_hour => 24,
        close_minute => 0,
        closed => 0
    };
}

sub get_hours_full {
    my ( $self, $dt ) = @_;

    my $hours = $self->get_hours;

    $hours->{open_time} = $dt
        ->clone->truncate( to => 'day' )
        ->set_hour( $hours->{open_hour} )
        ->set_minute( $hours->{open_minute} );

    if ( $hours->{close_hour} == 24 ) {
        $hours->{close_time} = $dt
            ->clone->truncate( to => 'day' )
            ->add( days => 1 );
    } else {
        $hours->{close_time} = $dt
            ->clone->truncate( to => 'day' )
            ->set_hour( $hours->{close_hour} )
            ->set_minute( $hours->{close_minute} );
    }

    return $hours;
}

sub next_open_day {
    my ( $self, $dt ) = @_;
    my $base_date = $dt->clone();

    $base_date->add(days => 1);

    while ($self->is_holiday($base_date)) {
        $base_date->add(days => 1);
    }

    return $base_date;
}

sub prev_open_day {
    my ( $self, $dt ) = @_;
    my $base_date = $dt->clone();

    $base_date->add(days => -1);

    while ($self->is_holiday($base_date)) {
        $base_date->add(days => -1);
    }

    return $base_date;
}

sub days_between {
    my $self     = shift;
    my $start_dt = shift;
    my $end_dt   = shift;

    if ( $start_dt->compare($end_dt) > 0 ) {
        # swap dates
        my $int_dt = $end_dt;
        $end_dt = $start_dt;
        $start_dt = $int_dt;
    }


    # start and end should not be closed days
    my $days = $start_dt->delta_days($end_dt)->delta_days;
    for (my $dt = $start_dt->clone();
        $dt <= $end_dt;
        $dt->add(days => 1)
    ) {
        if ($self->is_holiday($dt)) {
            $days--;
        }
    }
    return DateTime::Duration->new( days => $days );

}

sub hours_between {
    my ($self, $start_date, $end_date) = @_;
    my $start_dt = $start_date->clone();
    my $end_dt = $end_date->clone();

    if ( $start_dt->compare($end_dt) > 0 ) {
        # swap dates
        my $int_dt = $end_dt;
        $end_dt = $start_dt;
        $start_dt = $int_dt;
    }

    my $start_hours = $self->get_hours_full( $start_dt );
    my $end_hours = $self->get_hours_full( $end_dt );

    $start_dt = $start_hours->{open_time} if ( $start_dt < $start_hours->{open_time} );
    $end_dt = $end_hours->{close_time} if ( $end_dt > $end_hours->{close_time} );

    my $duration = DateTime::Duration->new;
    
    if ( $start_dt < $start_hours->{close_time} ) $duration->add_duration( $start_hours->{close_time} - $start_dt );

    for (my $date = $start_dt->clone->truncate( to => 'day' )->add( days => 1 );
        $date->ymd lt $end_dt->ymd;
        $date->add(days => 1)
    ) {
        my $hours = $self->get_hours_full( $date );
        $duration->add_duration( $hours->{close_time} - $hours->{open_time} );
    }

    if ( $end_dt > $start_hours->{open_time} ) $duration->add_duration( $end_dt - $end_hours->{open_time} );

    return $duration;

}

1;
__END__

=head1 NAME

Koha::Calendar - Object containing a branches calendar

=head1 VERSION

This documentation refers to Koha::Calendar version 0.0.1

=head1 SYNOPSIS

  use Koha::Calendar

  my $c = Koha::Calendar->new( branchcode => 'MAIN' );
  my $dt = DateTime->now();

  # are we open
  $open = $c->is_holiday($dt);
  # when will item be due if loan period = $dur (a DateTime::Duration object)
  $duedate = $c->addDate($dt,$dur,'days');


=head1 DESCRIPTION

  Implements those features of C4::Calendar needed for Staffs Rolling Loans

=head1 METHODS

=head2 new : Create a calendar object

my $calendar = Koha::Calendar->new( branchcode => 'MAIN' );

The option branchcode is required


=head2 addDate

    my $dt = $calendar->addDate($date, $dur, $unit)

C<$date> is a DateTime object representing the starting date of the interval.

C<$offset> is a DateTime::Duration to add to it

C<$unit> is a string value 'days' or 'hours' toflag granularity of duration

Currently unit is only used to invoke Staffs return Monday at 10 am rule this
parameter will be removed when issuingrules properly cope with that


=head2 addHours

    my $dt = $calendar->addHours($date, $dur )

C<$date> is a DateTime object representing the starting date of the interval.

C<$offset> is a DateTime::Duration to add to it


=head2 addDays

    my $dt = $calendar->addDays($date, $dur)

C<$date> is a DateTime object representing the starting date of the interval.

C<$offset> is a DateTime::Duration to add to it

C<$unit> is a string value 'days' or 'hours' toflag granularity of duration

Currently unit is only used to invoke Staffs return Monday at 10 am rule this
parameter will be removed when issuingrules properly cope with that


=head2 is_holiday

$yesno = $calendar->is_holiday($dt);

passed a DateTime object returns 1 if it is a closed day
0 if not according to the calendar

=head2 days_between

$duration = $calendar->days_between($start_dt, $end_dt);

Passed two dates returns a DateTime::Duration object measuring the length between them
ignoring closed days. Always returns a positive number irrespective of the
relative order of the parameters

=head2 next_open_day

$datetime = $calendar->next_open_day($duedate_dt)

Passed a Datetime returns another Datetime representing the next open day. It is
intended for use to calculate the due date when useDaysMode syspref is set to either
'Datedue' or 'Calendar'.

=head2 prev_open_day

$datetime = $calendar->prev_open_day($duedate_dt)

Passed a Datetime returns another Datetime representing the previous open day. It is
intended for use to calculate the due date when useDaysMode syspref is set to either
'Datedue' or 'Calendar'.

=head1 DIAGNOSTICS

Will croak if not passed a branchcode in new

=head1 BUGS AND LIMITATIONS

This only contains a limited subset of the functionality in C4::Calendar
Only enough to support Staffs Rolling loans

=head1 AUTHOR

Colin Campbell colin.campbell@ptfs-europe.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011 PTFS-Europe Ltd All rights reserved

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
