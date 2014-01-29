use strict;
use warnings;
use 5.010;
use DateTime;
use DateTime::TimeZone;

use C4::Context;
use Test::More tests => 6;

BEGIN { use_ok('Koha::Calendar'); }

my $branchcode = 'MPL';

my $koha_calendar = Koha::Calendar->new( branchcode => $branchcode );

isa_ok( $koha_calendar, 'Koha::Calendar', 'Koha::Calendar class returned' );

my $sunday = DateTime->new(
    year  => 2011,
    month => 6,
    day   => 26,
);
my $monday = DateTime->new(
    year  => 2011,
    month => 6,
    day   => 27,
);
my $christmas = DateTime->new(
    year  => 2032,
    month => 12,
    day   => 25,
);
my $newyear = DateTime->new(
    year  => 2035,
    month => 1,
    day   => 1,
);

is( $koha_calendar->is_holiday($sunday),    1, 'Sunday is a closed day' );
is( $koha_calendar->is_holiday($monday),    0, 'Monday is not a closed day' );
is( $koha_calendar->is_holiday($christmas), 1, 'Christmas is a closed day' );
is( $koha_calendar->is_holiday($newyear), 1, 'New Years day is a closed day' );
