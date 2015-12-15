package Koha::I18N;

# This file is part of Koha.
#
# Copyright 2012-2014 BibLibre
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

use Modern::Perl;

use CGI;
use C4::Languages;
use C4::Context;

use Encode;
use Locale::Util qw(set_locale);
use Locale::Messages qw(:locale_h :libintl_h nl_putenv);

use parent 'Exporter';
our @EXPORT = qw(
    __
    __x
    __n
    __nx
    __xn
    __p
    __px
    __np
    __npx
    N__
    N__n
    N__p
    N__np
);

my $textdomain;

BEGIN {
    $textdomain = 'Koha';

    my $langtag = C4::Languages::getlanguage;
    my @subtags = split /-/, $langtag;
    my ($language, $region) = @subtags;
    if ($region && length $region == 4) {
        $region = $subtags[2];
    }
    my $locale = set_locale(LC_ALL, $language, $region, 'utf-8');
    unless ($locale) {
        set_locale(LC_MESSAGES, 'C');
        Locale::Messages->select_package('gettext_pp');
        $locale = $language;
        if ($region) {
            $locale .= '_' . $region;
        }
        nl_putenv("LANGUAGE=$locale");
        nl_putenv("LANG=$locale");
        nl_putenv('OUTPUT_CHARSET=utf-8');
    }

    my $directory = C4::Context->config('intranetdir') . '/misc/translator/po';
    textdomain($textdomain);
    bindtextdomain($textdomain, $directory);
}

sub __ {
    my ($msgid) = @_;
    my $text = dgettext($textdomain, $msgid);
    return __decode($text);
}

sub __x {
    my ($msgid, %vars) = @_;
    return __expand(__($msgid), %vars);
}

sub __n {
    my ($msgid, $msgid_plural, $count) = @_;
    my $text = dngettext($textdomain, $msgid, $msgid_plural, $count);
    return __decode($text);
}

sub __nx {
    my ($msgid, $msgid_plural, $count, %vars) = @_;
    return __expand(__n($msgid, $msgid_plural, $count), %vars);
}

sub __xn {
    return __nx(@_);
}

sub __p {
    my ($msgctxt, $msgid) = @_;
    my $text = dpgettext($textdomain, $msgctxt, $msgid);
    return __decode($text);
}

sub __px {
    my ($msgctxt, $msgid, %vars) = @_;
    return __expand(__p($msgctxt, $msgid), %vars);
}

sub __np {
    my ($msgctxt, $msgid, $msgid_plural, $count) = @_;
    my $text = dnpgettext($textdomain, $msgctxt, $msgid, $msgid_plural, $count);
    return __decode($text);
}

sub __npx {
    my ($msgctxt, $msgid, $msgid_plural, $count, %vars) = @_;
    return __expand(__np($msgctxt, $msgid, $msgid_plural, $count), %vars);
}

sub N__ {
    return @_;
}

sub N__n {
    return @_;
}

sub N__p {
    return @_;
}

sub N__np {
    return @_;
}

sub __expand {
    my ($text, %vars) = @_;

    my $re = join '|', map { quotemeta $_ } keys %vars;
    $text =~ s/\{($re)\}/defined $vars{$1} ? $vars{$1} : "{$1}"/ge;

    return $text;
}

sub __decode {
    return Encode::decode_utf8(shift);
}

1;
