use Modern::Perl;

use Test::More tests => 14;

use C4::Calendar;
use C4::Context;

my $dbh = C4::Context->dbh;

# Start transaction
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

my %new_holiday = ( open_hour    => 0,
                    open_minute  => 0,
                    close_hour   => 0,
                    close_minute => 0,
                    title        => 'example week_day_holiday',
                    description  => 'This is an example week_day_holiday used for testing' );

# Weekly events
ModRepeatingEvent( 'UPL', { weekday => 1, %new_holiday } );

my $weekly_events = GetWeeklyEvents( 'UPL' );
is( $weekly_events->[0]->{'title'}, $new_holiday{'title'}, 'weekly title' );
is( $weekly_events->[0]->{'description'}, $new_holiday{'description'}, 'weekly description' );

$new_holiday{close_hour} = 24;

ModRepeatingEvent( 'UPL', { weekday => 1, %new_holiday } );
$weekly_events = GetWeeklyEvents( 'UPL' );
is( scalar @$weekly_events, 0, 'weekly modification, not insertion' );

$new_holiday{close_hour} = 0;
ModRepeatingEvent( 'UPL', { weekday => 1, %new_holiday } );

# Yearly events

ModRepeatingEvent( 'UPL', { month => 6, day => 26, %new_holiday } );

my $yearly_events = GetYearlyEvents( 'UPL' );
is( $yearly_events->[0]->{'title'}, $new_holiday{'title'}, 'yearly title' );
is( $yearly_events->[0]->{'description'}, $new_holiday{'description'}, 'yearly description' );

$new_holiday{close_hour} = 24;

ModRepeatingEvent( 'UPL', { month => 6, day => 26, %new_holiday } );
$yearly_events = GetYearlyEvents( 'UPL' );
is( scalar @$yearly_events, 0, 'yearly modification, not insertion' );

$new_holiday{close_hour} = 0;
ModRepeatingEvent( 'UPL', { month => 6, day => 26, %new_holiday } );

# Single events

ModSingleEvent( 'UPL', { date => '2013-03-17', %new_holiday } );

my $single_events = GetSingleEvents( 'UPL' );
is( $single_events->[0]->{'title'}, $new_holiday{'title'}, 'single title' );
is( $single_events->[0]->{'description'}, $new_holiday{'description'}, 'single description' );
is( $single_events->[0]->{'closed'}, 1, 'single closed' );

$new_holiday{close_hour} = 24;

ModSingleEvent( 'UPL', { date => '2013-03-17', %new_holiday } );
$single_events = GetSingleEvents( 'UPL' );
is( scalar @$single_events, 1, 'single modification, not insertion' );
is( $single_events->[0]->{'closed'}, 0, 'single closed' );


# delete

DelRepeatingEvent( 'UPL', { weekday => 1 } );
$weekly_events = GetWeeklyEvents( 'UPL' );
is( scalar @$weekly_events, 0, 'weekly deleted' );

DelRepeatingEvent( 'UPL', { month => 6, day => 26 } );
$yearly_events = GetYearlyEvents( 'UPL' );
is( scalar @$yearly_events, 0, 'yearly deleted' );

DelSingleEvent( 'UPL', { date => '2013-03-17' } );

$single_events = GetSingleEvents( 'UPL' );
is( scalar @$single_events, 0, 'single deleted' );

$dbh->rollback;
