#!/usr/bin/perl

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

#####Sets holiday periods for each branch. Datedues will be extended if branch is closed -TG
use strict;
use warnings;

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

my $branch= $input->param('branch') || C4::Context->userenv->{'branch'};
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

my $yearly_events = GetYearlyEvents();
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
    weekly_events            => GetWeeklyEvents(),
    yearly_events            => $yearly_events,
    single_events            => GetSingleEvents(),
    branchloop               => \@branchloop,
    calendardate             => $calendardate,
    keydate                  => $keydate,
    branchcodes              => $branchcodes,
    branch                   => $branch,
    branchname               => $branchname,
    branch                   => $branch,
);

# Shows the template with the real values replaced
output_html_with_http_headers $input, $cookie, $template->output;
