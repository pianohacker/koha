#!/usr/bin/perl

use strict;
use warnings;

use C4::Context;
use C4::Members;
use C4::Auth;
use Carp;
use CGI;
use Crypt::CBC;
use Data::Dumper;
use Digest::SHA;
use JSON;
use MIME::Base64;
use Readonly;
use Try::Tiny;

Readonly my $HASH_LENGTH  => 32;
Readonly my $PERIOD       => 20;
Readonly my $UID_TOO_LONG => 75;

my (
    $context,        $ExtAuthSrc,      %mapping,    $attribute_hashref,
    %attribute_hash, $variable,        $default,    $value,
    %borrower,       $username_attrib, $username,   $dbh,
    $sql,            $sth,             $rv,         $hashref,
    $cardnumber,     $borrowernumber,  $password,
);
my %emptyhash = ();

# Get a CGI object.
my $cgi_obj = CGI->new;

# Get a hash reference to all the parameters.
# Expecting DATA={hexified, encrypted, JSON object of user attributes}
my $param_hashref = $cgi_obj->Vars;

# Log the parameters for debugging.
logit( '*&*&*&*&*&', 1 );
logit( Data::Dumper->Dump( [$param_hashref], ['param_hashref'] ) );
logit('*&*&*&*&*&');

$context    = C4::Context->new();
$ExtAuthSrc = C4::Context->config('ExtAuthSrc')
  or croak 'No "ExtAuthSrc" in server hash from KOHA_CONF: ' . $ENV{KOHA_CONF};
%mapping = %{ $ExtAuthSrc->{mapping} };
logit( Data::Dumper->Dump( [ \%mapping ], ['xmlconfig'] ) );

$attribute_hashref = DecryptData( $ExtAuthSrc, $param_hashref );
%attribute_hash = %{$attribute_hashref};

logit('Hashed JSON data:');
logit( Data::Dumper->Dump( [ \%attribute_hash ], ['attribute_hash'] ) );

logit('XML file mapping:');
foreach my $key ( keys %mapping ) {
    $variable = $mapping{$key}->{'is'};
    $default = $mapping{$key}->{'content'} || q{};
    logit("koha->$key is attribute_->$variable or \"$default\"");
    $value = $attribute_hash{$variable} || $default;
    if ( defined $value ) {
        logit(" = $value\n");
        $borrower{$key} = $value;
    }
}

logit( Data::Dumper->Dump( [ \%borrower ], ['borrower'] ) );

$username_attrib = $mapping{'userid'}->{'is'};
logit("\$username_attrib=$username_attrib");

$username = $attribute_hash{$username_attrib} || q{};
if ( length($username) > $UID_TOO_LONG ) {
    $username = sha512_base64($username);
}

logit("ATTEMPT TO LOOK UP \"$username\"");

if ( !$username ) {
    logit('FAILED! NO USER NAME PASSED!');
    bad_exit($cgi_obj);
}

$dbh = C4::Context->dbh;
if ( !$dbh ) {
    logit('Failed to connect.');
    bad_exit($cgi_obj);
}
logit("Connected! (\$dbh=$dbh)");

$sql =
'SELECT borrowernumber,userid,cardnumber,firstname, surname,branchcode,flags,email FROM borrowers WHERE userid=?';
$sth = $dbh->prepare($sql);
$rv  = $sth->execute($username);
if ( !$rv ) {
    logit('Failed to execute SQL to find username.');
    bad_exit($cgi_obj);
}

$hashref = $sth->fetchrow_hashref();
if ( !$hashref ) {
    logit('UNDEFINED HASH REF!');

    $cardnumber = fixup_cardnumber();
    $borrower{'cardnumber'} = $cardnumber;
    logit("Cardnumber generated: $cardnumber");
    ( $borrowernumber, $password ) = AddMember_Opac(%borrower)
      or croak "AddMember_Opac failed.\n";
    logit("\$borrowernumber=$borrowernumber");
    logit("\$password=$password");

    $sql =
'SELECT borrowernumber,userid,cardnumber,firstname, surname,branchcode,flags,email FROM borrowers WHERE userid=?';
    $sth = $dbh->prepare($sql);
    $rv  = $sth->execute($username);
    if ( !$rv ) {
        logit('Failed to execute SQL to find email.');
        bad_exit($cgi_obj);
    }
    $hashref = $sth->fetchrow_hashref();
}

logit('FOUND USER NAME!');

my ( $userid, $cookie, $sessionID, $flags ) =
      checkauth( $cgi_obj, 1,  { borrow => 1 }, 'opac', q{}, $username );

logit($cookie);
logit('Script done.');
logit('----****');

$rv = print $cgi_obj->redirect(
    -uri    => C4::Context->preference('OPACBaseURL'),
    -cookie => $cookie
);
exit 0;

sub logit {
    my ( $string, $mode ) = @_;
    my $ignore_close;

    if ($mode) {
        open my ${fh}, '>', '/tmp/hack_output'
          or croak "unable to open /tmp/hack_output\n";
        printf ${fh} '%s', "$string\n";
        $ignore_close = close ${fh};
    }
    else {
        open my ${fh}, '>>', '/tmp/hack_output'
          or croak "unable to open /tmp/hack_output\n";
        printf ${fh} '%s', "$string\n";
        $ignore_close = close ${fh};
    }
    return;
}

#
# Create a set of three hashes, current, previous and next
#
# @param string $key
# @param string $algorithm
# @param int $period
# @return string[] $hashes
#
sub makeHashes {
    my ( $key, $algorithm, $period ) = @_;

    my $time = time;

    my $keyPrevious = timeMod( $time - $period, $period ) . $key;
    my $keyCurrent  = timeMod( $time,           $period ) . $key;
    my $keyNext     = timeMod( $time + $period, $period ) . $key;
    logit("$time\n$period\n$key\n$keyPrevious\n$keyCurrent\n$keyNext\n");

    my %hashes;

    $hashes{'previous'} = makeHash( $algorithm, $keyPrevious );
    $hashes{'current'}  = makeHash( $algorithm, $keyCurrent );
    $hashes{'next'}     = makeHash( $algorithm, $keyNext );

    return \%hashes;
}

#
# Create a hash based on the provided algorithm and plain text, or truncating
# as necessary to create the proper length string
#
# @param string $algorithm
# @param string $plaintext
# @return string $hash
#
sub makeHash {
    my ( $algorithm, $plaintext ) = @_;
    my $sha = Digest::SHA->new($algorithm);
    $sha->add($plaintext);
    my $hash = $sha->digest;
    return $hash;
}

#
# Return a unix time code that will be consistent within $period, using modulo operator
# eg, if period is 180 seconds, then anything from :00:00 to :03:00 will evaluate to the
# same number
#
# @param int $time
# @param int $period
# @return int $timeMod
#
sub timeMod {
    my ( $time, $period ) = @_;

    logit( 'TIME: ' . ( $time - ( $time % $period ) ) );
    return $time - ( $time % $period );
}

sub isJSON {
    my ($text) = @_;
    return try {
        decode_json($text);
    }
    catch {
        q{};
    };
}

sub DecryptData {
    my ( $EAS, $HD ) = @_;

    my $key = $EAS->{PreSharedKey};
    logit("Pre-shared key: $key\n");
    my $algorithm = '256';
    my $period    = $PERIOD;

    my $hashes_ref = makeHashes( $key, $algorithm, $period );

    my $JSON_text = $HD->{'DATA'} || q{};
    logit("Hexed JSON: $JSON_text\n");
    my $unhexed_JSON_text = pack 'H*', $JSON_text;
    logit("Unhexed JSON: $unhexed_JSON_text\n");
    my $keyed = $EAS->{IV};
    logit("IV: $keyed\n");
    my $cipher1 = Crypt::CBC->new(
        -key         => $hashes_ref->{'current'},
        -cipher      => 'Crypt::Rijndael',
        -iv          => $keyed,
        -literal_key => 1,
        -header      => 'none',
        -keysize     => $HASH_LENGTH,
    );
    my $cipher2 = Crypt::CBC->new(
        -key         => $hashes_ref->{'previous'},
        -cipher      => 'Crypt::Rijndael',
        -iv          => $keyed,
        -literal_key => 1,
        -header      => 'none',
        -keysize     => $HASH_LENGTH,
    );
    my $cipher3 = Crypt::CBC->new(
        -key         => $hashes_ref->{'next'},
        -cipher      => 'Crypt::Rijndael',
        -iv          => $keyed,
        -literal_key => 1,
        -header      => 'none',
        -keysize     => $HASH_LENGTH,
    );

    my $decrypted1 = $cipher1->decrypt($unhexed_JSON_text);
    my $decrypted2 = $cipher2->decrypt($unhexed_JSON_text);
    my $decrypted3 = $cipher3->decrypt($unhexed_JSON_text);
    logit("d1: $decrypted1\n");
    logit("d2: $decrypted2\n");
    logit("d3: $decrypted3\n");

    my $decoded_attributes_ref = \%emptyhash;
    if ( isJSON($decrypted1) ) {
        logit("DECRYPTED1 SUCCESS!\n");
        $decoded_attributes_ref = decode_json $decrypted1;
    }
    if ( isJSON($decrypted2) ) {
        logit("DECRYPTED2 SUCCESS!\n");
        $decoded_attributes_ref = decode_json $decrypted2;
    }
    if ( isJSON($decrypted3) ) {
        logit("DECRYPTED3 SUCCESS!\n");
        $decoded_attributes_ref = decode_json $decrypted3;
    }

    my %decoded_attribute_hash = %{$decoded_attributes_ref};
    foreach my $key ( keys %decoded_attribute_hash ) {
        if ( ref( $decoded_attribute_hash{$key} ) eq 'ARRAY' ) {
            my @attribute_values = @{ $decoded_attribute_hash{$key} };
            logit("$key -- \$#attribute_values: $#attribute_values\n");
            if ( $#attribute_values == 0 ) {
                $decoded_attribute_hash{$key} =
                  $decoded_attribute_hash{$key}[0];
            }
        }
    }

    return \%decoded_attribute_hash;
}

sub bad_exit {
    my ($query) = @_;
    my $ignore_redirect;

    $ignore_redirect =
      print $query->redirect( -uri => C4::Context->preference('OPACBaseURL') );
    exit 1;
}
