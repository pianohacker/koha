<!DOCTYPE html>
[% IF ( bidi ) %]
[% IF ( angular_app ) %]
<html lang="[% lang %]" dir="[% bidi %]" ng-app="[% angular_app %]>
[% ELSE %]
<html lang="[% lang %]" dir="[% bidi %]">
[% END %]
[% ELSE %]
[% IF ( angular_app ) %]
<html lang="[% lang %]" ng-app="[% angular_app %]">
[% ELSE %]
<html lang="[% lang %]">
[% END %]
[% END %]
<head>
