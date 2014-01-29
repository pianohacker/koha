#!/usr/bin/perl

# This file is part of Koha.
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

#####Sets holiday periods for each branch. Datedues will be extended if branch is closed -TG

use Modern::Perl;

use CGI;

use C4::Auth;
use C4::Output;

use C4::Branch; # GetBranches
use C4::Calendar;

my $input = new CGI;

my $dbh = C4::Context->dbh();
# Get the template to use
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "tools/calendar.tmpl",
                             type => "intranet",
                             query => $input,
                             authnotrequired => 0,
                             flagsrequired => {tools => 'edit_calendar'},
                             debug => 1,
                           });

# keydate - date passed to calendar.js.  calendar.js does not process dashes within a date.
my $keydate;
# calendardate - date passed in url for human readability (syspref)
my $calendardate;
my $today = C4::Dates->new();
my $calendarinput = C4::Dates->new($input->param('calendardate')) || $today;
# if the url has an invalid date default to 'now.'
unless($calendardate = $calendarinput->output('syspref')) {
  $calendardate = $today->output('syspref');
}
unless($keydate = $calendarinput->output('iso')) {
  $keydate = $today->output('iso');
}
$keydate =~ s/-/\//g;

my $branch= $input->param('branchName') || $input->param('branch') || C4::Context->userenv->{'branch'};
# Set all the branches.
my $onlymine=(C4::Context->preference('IndependentBranches') &&
              C4::Context->userenv &&
              C4::Context->userenv->{flags} % 2 !=1  &&
              C4::Context->userenv->{branch}?1:0);
if ( $onlymine ) {
    $branch = C4::Context->userenv->{'branch'};
}
my $branchname = GetBranchName($branch);
my $branches   = GetBranches($onlymine);
my @branchloop;
for my $thisbranch (
    sort { $branches->{$a}->{branchname} cmp $branches->{$b}->{branchname} }
    keys %{$branches} ) {
    push @branchloop,
      { value      => $thisbranch,
        selected   => $thisbranch eq $branch,
        branchname => $branches->{$thisbranch}->{'branchname'},
      };
}

# branches calculated - put branch codes in a single string so they can be passed in a form
my $branchcodes = join '|', keys %{$branches};

my $op = $input->param( 'op' ) // '';

my @ranged_dates;

if ( my $dateofrange = $input->param( 'dateofrange' ) ) {
    my $date = $input->param( 'year' ) . '-' . $input->param( 'month' ) . '-' . $input->param( 'day' );

    my ( $start_year, $start_month, $start_day ) = split( /-/, $date );
    my ( $end_year, $end_month, $end_day ) = split( /-/, C4::Dates->new( $dateofrange )->output( 'iso' ) );

    if ( $end_year && $end_month && $end_day ){
        my $first_dt = DateTime->new(year => $start_year, month => $start_month, day => $start_day);
        my $end_dt   = DateTime->new(year => $end_year, month => $end_month, day => $end_day);

        for ( my $dt = $first_dt->clone(); $dt <= $end_dt; $dt->add(days => 1) ) {
            push @ranged_dates, $dt->clone();
        }
    }
}

my @branches;
if ( $input->param( 'allBranches' ) || !$input->param( 'branchName' ) ) {
    @branches = split /\|/, $input->param( 'branchcodes' );
} else {
    @branches = ( $input->param( 'branchName' ) );
}

if ( $op eq 'save' ) {
    my $date = $input->param( 'year' ) . '-' . $input->param( 'month' ) . '-' . $input->param( 'day' );

    local our ( $open_hour, $open_minute, $close_hour, $close_minute );

    if ( $input->param( 'hoursType' ) eq 'open' ) {
        ( $open_hour, $open_minute ) = ( 0, 0 );
        ( $close_hour, $close_minute ) = ( 24, 0 );
    } elsif ( $input->param( 'hoursType' ) eq 'closed' ) {
        ( $open_hour, $open_minute ) = ( 0, 0 );
        ( $close_hour, $close_minute ) = ( 0, 0 );
    } else {
        ( $open_hour, $open_minute ) = ( $input->param( 'openTime' ) =~ /(0?[0-9]|1[0-9]|2[0-3]):([0-5][0-9])/ );
        ( $close_hour, $close_minute ) = ( $input->param( 'closeTime' ) =~ /(0?[0-9]|1[0-9]|2[0-3]):([0-5][0-9])/ );
    }

    foreach my $branchcode ( @branches ) {
        my %event_types = (
            'single' => sub {
                ModSingleEvent( $branchcode, {
                    date => $date,
                    title => $input->param( 'title' ),
                    description => $input->param( 'description' ),
                    open_hour => $open_hour,
                    open_minute => $open_minute,
                    close_hour => $close_hour,
                    close_minute => $close_minute
                } );
            },

            'weekly' => sub {
                ModRepeatingEvent( $branchcode, {
                    weekday => $input->param( 'weekday' ),
                    title => $input->param( 'title' ),
                    description => $input->param( 'description' ),
                    open_hour => $open_hour,
                    open_minute => $open_minute,
                    close_hour => $close_hour,
                    close_minute => $close_minute
                } );
            },

            'yearly' => sub {
                ModRepeatingEvent( $branchcode, {
                    month => $input->param( 'month' ),
                    day => $input->param( 'day' ),
                    title => $input->param( 'title' ),
                    description => $input->param( 'description' ),
                    open_hour => $open_hour,
                    open_minute => $open_minute,
                    close_hour => $close_hour,
                    close_minute => $close_minute
                } );
            },

            'singlerange' => sub {
                foreach my $dt ( @ranged_dates ) {
                    ModSingleEvent( $branchcode, {
                        date => $dt->ymd,
                        title => $input->param( 'title' ),
                        description => $input->param( 'description' ),
                        open_hour => $open_hour,
                        open_minute => $open_minute,
                        close_hour => $close_hour,
                        close_minute => $close_minute
                    } );
                }
            },

            'yearlyrange' => sub {
                foreach my $dt ( @ranged_dates ) {
                    ModRepeatingEvent( $branchcode, {
                        month => $dt->month,
                        day => $dt->day,
                        title => $input->param( 'title' ),
                        description => $input->param( 'description' ),
                        open_hour => $open_hour,
                        open_minute => $open_minute,
                        close_hour => $close_hour,
                        close_minute => $close_minute
                    } );
                }
            },
        );

        # Choose from the above options
        $event_types{ $input->param( 'eventType' ) }->();
    }
} elsif ( $op eq 'delete' ) {
    my $date = $input->param( 'year' ) . '-' . $input->param( 'month' ) . '-' . $input->param( 'day' );

    foreach my $branchcode ( @branches ) {
        my %event_types = (
            'single' => sub {
                DelSingleEvent( $branchcode, { date => $date } );
            },

            'weekly' => sub {
                DelRepeatingEvent( $branchcode, { weekday => $input->param( 'weekday' ) } );
            },

            'yearly' => sub {
                DelRepeatingEvent( $branchcode, { month => $input->param( 'month' ), day => $input->param( 'day' ) } );
            },
        );

        # Choose from the above options
        $event_types{ $input->param( 'eventType' ) }->();
    }
} elsif ( $op eq 'deleterange' ) {
    foreach my $branchcode ( @branches ) {
        foreach my $dt ( @ranged_dates ) {
            DelSingleEvent( $branchcode, { date => $dt->ymd } );
        }
    }
} elsif ( $op eq 'deleterangerepeat' ) {
    foreach my $branchcode ( @branches ) {
        foreach my $dt ( @ranged_dates ) {
            DelRepeatingEvent( $branchcode, { month => $dt->month, day => $dt->day } );
        }
    }
} elsif ( $op eq 'copyall' ) {
    CopyAllEvents( $input->param( 'from_branchcode' ), $input->param( 'branchcode' ) );
}

my $yearly_events = GetYearlyEvents($branch);
foreach my $event ( @$yearly_events ) {
    # Determine date format on month and day.
    my $day_monthdate;
    my $day_monthdate_sort;
    if (C4::Context->preference("dateformat") eq "metric") {
      $day_monthdate_sort = "$event->{month}-$event->{day}";
      $day_monthdate = "$event->{day}/$event->{month}";
    } elsif (C4::Context->preference("dateformat") eq "us") {
      $day_monthdate = "$event->{month}/$event->{day}";
      $day_monthdate_sort = $day_monthdate;
    } else {
      $day_monthdate = "$event->{month}-$event->{day}";
      $day_monthdate_sort = $day_monthdate;
    }

    $event->{month_day_display} = $day_monthdate;
    $event->{month_day_sort} = $day_monthdate_sort;
}

$template->param(
    weekly_events            => GetWeeklyEvents($branch),
    yearly_events            => $yearly_events,
    single_events            => GetSingleEvents($branch),
    branchloop               => \@branchloop,
    calendardate             => $calendardate,
    keydate                  => $keydate,
    branchcodes              => $branchcodes,
    branch                   => $branch,
    branchname               => $branchname,
);

# Shows the template with the real values replaced
output_html_with_http_headers $input, $cookie, $template->output;
