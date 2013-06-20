use Modern::Perl;

use Test::More tests => 18;

use C4::Calendar;

my $new_holiday = { open_hour    => 0,
                    open_minute  => 0,
                    close_hour   => 0,
                    close_minute => 0,
                    title        => 'example week_day_holiday',
                    description  => 'This is an example week_day_holiday used for testing' };

# Weekly events
ModRepeatingEvent( 'MPL', 1, undef, undef, $new_holiday );

my $weekly_events = GetWeeklyEvents( 'MPL' );
is( $weekly_events->[0]->{'title'}, $new_holiday->{'title'}, 'weekly title' );
is( $weekly_events->[0]->{'description'}, $new_holiday->{'description'}, 'weekly description' );
is( $weekly_events->[0]->{'open_hour'}, 0, 'weekly open_hour' );

$new_holiday->{open_hour} = 7;

ModRepeatingEvent( 'MPL', 1, undef, undef, $new_holiday );
$weekly_events = GetWeeklyEvents( 'MPL' );
is( scalar @$weekly_events, 1, 'weekly modification, not insertion' );
is( $weekly_events->[0]->{'open_hour'}, 7, 'weekly open_hour modified' );


# Yearly events

$new_holiday->{open_hour} = 0;
ModRepeatingEvent( 'MPL', undef, 6, 26, $new_holiday );

my $yearly_events = GetYearlyEvents( 'MPL' );
is( $yearly_events->[0]->{'title'}, $new_holiday->{'title'}, 'yearly title' );
is( $yearly_events->[0]->{'description'}, $new_holiday->{'description'}, 'yearly description' );
is( $yearly_events->[0]->{'open_hour'}, 0, 'yearly open_hour' );

$new_holiday->{open_hour} = 8;

ModRepeatingEvent( 'MPL', undef, 6, 26, $new_holiday );
$yearly_events = GetYearlyEvents( 'MPL' );
is( scalar @$yearly_events, 1, 'yearly modification, not insertion' );
is( $yearly_events->[0]->{'open_hour'}, 8, 'yearly open_hour' );

# Single events

$new_holiday->{open_hour} = 0;
ModSingleEvent( 'MPL', '2013-03-17', $new_holiday );

my $single_events = GetSingleEvents( 'MPL' );
is( $single_events->[0]->{'title'}, $new_holiday->{'title'}, 'single title' );
is( $single_events->[0]->{'description'}, $new_holiday->{'description'}, 'single description' );
is( $single_events->[0]->{'open_hour'}, 0, 'single open_hour' );

$new_holiday->{open_hour} = 11;

ModSingleEvent( 'MPL', '2013-03-17', $new_holiday );
$single_events = GetSingleEvents( 'MPL' );
is( scalar @$single_events, 1, 'single modification, not insertion' );
is( $single_events->[0]->{'open_hour'}, 11, 'single open_hour' );


# delete

DelRepeatingEvent( 'MPL', 1, undef, undef );
$weekly_events = GetWeeklyEvents( 'MPL' );
is( scalar @$weekly_events, 0, 'weekly deleted' );

DelRepeatingEvent( 'MPL', undef, 6, 26 );
$yearly_events = GetYearlyEvents( 'MPL' );
is( scalar @$yearly_events, 0, 'yearly deleted' );

DelSingleEvent( 'MPL', '2013-03-17' );

$single_events = GetSingleEvents( 'MPL' );
is( scalar @$single_events, 0, 'single deleted' );
