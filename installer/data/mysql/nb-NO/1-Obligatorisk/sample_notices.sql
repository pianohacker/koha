-- 
-- Default classification sources and filing rules
-- for Koha.
--
-- Copyright (C) 2011 Magnus Enger Libriotech
--
-- This file is part of Koha.
--
-- Koha is free software; you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 2 of the License, or (at your option) any later
-- version.
-- 
-- Koha is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
-- A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License along
-- with Koha; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

INSERT INTO letter (module, code, name, title, content, message_transport_type)
VALUES ('circulation','ODUE','Purring','Purring på dokument','<<borrowers.firstname>> <<borrowers.surname>>,\n\nDu har lån som skulle vært levert. Biblioteket krever ikke inn gebyrer, men vennligst lever eller forny lånet/lånene ved biblioteket.\n\n<<branches.branchname>>\n<<branches.branchaddress1>>\n<<branches.branchaddress2>> <<branches.branchaddress3>>\nTelefon: <<branches.branchphone>>\nFax: <<branches.branchfax>>\nE-post: <<branches.branchemail>>\n\nDersom du har et passord og lånet/lånene kan fornyes kan du gjøre dette på nettet. Dersom du overskrider lånetiden med mer enn 30 dager vil lånekortet bli sperret.\n\nFølgende lån har gått over tiden:\n\n<item>"<<biblio.title>>" av <<biblio.author>>, <<items.itemcallnumber>>, Strekkode: <<items.barcode>> Gebyr: <<items.fine>></item>\n\nPå forhånd takk.\n\n<<branches.branchname>>\n', 'email'),
('claimacquisition','ACQCLAIM','Periodikapurring','Eksemplar ikke mottatt','<<aqbooksellers.name>>\r\n<<aqbooksellers.address1>>\r\n<<aqbooksellers.address2>>\r\n<<aqbooksellers.address3>>\r\n<<aqbooksellers.address4>>\r\n<<aqbooksellers.phone>>\r\n\r\n<order>Bestillingsnummer <<aqorders.ordernumber>> (<<aqorders.title>>) (<<aqorders.quantity>> ordered) ($<<aqorders.listprice>> each) har ikke blitt mottatt.</order>', 'email'),
('serial','RLIST','Sirkulasjon','Et dokument er nå tilgjengelig','<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nDette dokumentet er tilgjengelig:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)\r\n\r\nVennligst kom og hent det når det passer.', 'email'),
('members','ACCTDETAILS','Mal for kontodetaljer - STANDARD','Dine nye kontodetaljer i Koha.','Hei <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>.\r\n\r\nDine nye detaljer er:\r\n\r\nBruker:  <<borrowers.userid>>\r\nPassord: <<borrowers.password>>\r\n\r\nDersom det oppstår problemer, vennligst kontakt biblioteket.\r\n\r\nVennlig hilsen,\r\nBiblioteket\r\nkohaadmin@yoursite.org', 'email'),
('circulation','DUE','Innleveringspåminnelse','Innleveringspåminnelse','<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nDette dokumentet må nå leveres:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','DUEDGST','Innleveringspåminnelse (sammendrag)','Innleveringspåminnelse','Du har <<count>> dokumenter som skulle vært levert.', 'email'),
('circulation','PREDUE','Forhåndspåminnelse','Forhåndspåminnelse','<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nDette dokumentet må snart leveres:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','PREDUEDGST','Forhåndspåminnelse (sammendrag)','Forhåndspåminnelse','Du har lånt <<count>> dokumenter som snart må leveres.', 'email'),
('circulation','RENEWAL','Fornying','Fornyinger','Følgende lån har blitt fornyet:\r\n----\r\n<<biblio.title>>\r\n----\r\n', 'email'),
('reserves', 'HOLD', 'Hentemelding', 'Hentemelding fra <<branches.branchname>>', '<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nEt reservert dokument er klart til henting fra <<reserves.waitingdate>>:\r\n\r\nTittel: <<biblio.title>>\r\nForfatter: <<biblio.author>>\r\nEksemplar: <<items.copynumber>>\r\nHentested: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>\r\n<<branches.branchcity>> <<branches.branchzip>>', 'email'),
('reserves', 'HOLD', 'Hentemelding', 'Hentemelding', '<<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n<<borrowers.firstname>> <<borrowers.surname>>\r\n<<borrowers.address>>\r\n<<borrowers.city>> <<borrowers.zipcode>>\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n<<borrowers.firstname>> <<borrowers.surname>> <<borrowers.cardnumber>>\r\n\r\nDu har et reservert dokument som kan hentes fra  <<reserves.waitingdate>>:\r\n\r\nTittel: <<biblio.title>>\r\nForfatter: <<biblio.author>>\r\nEksemplar: <<items.copynumber>>\r\n', 'print'),
('circulation','CHECKIN','Innlevering','Melding om innlevering','Følgende dokument har blitt innlevert:\r\n----\r\n<<biblio.title>>\r\n----\r\nVennlig hilsen\r\nBiblioteket', 'email'),
('circulation','CHECKOUT','Utlån','Melding om utlån','Følgende dokument har blitt lånt ut:\r\n----\r\n<<biblio.title>>\r\n----\r\nVennlig hilsen\r\nBiblioteket', 'email'),
('reserves', 'HOLDPLACED', 'Melding om reservasjon', 'Melding om reservasjon','Følgende dokument har blitt reservert : <<biblio.title>> (<<biblio.biblionumber>>) av <<borrowers.firstname>> <<borrowers.surname>> (<<borrowers.cardnumber>>).', 'email'),
('suggestions','ACCEPTED','Forslag godtatt', 'Innkjøpsforslag godtatt','<<borrowers.firstname>> <<borrowers.surname>>,\n\nDu har foreslått at biblioteket kjøper inn <<suggestions.title>> av <<suggestions.author>>.\n\nBiblioteket har vurdert forslaget i dag. Dokumentet vil bli bestilt så fort det lar seg gjøre. Du vil få en ny melding når bestillingen er gjort, og når dokumentet ankommer biblioteket.\n\nEr det noe du lurer på, vennligst kontakt oss på <<branches.branchemail>>.\n\nVennlig hilsen,\n\n<<branches.branchname>>', 'email'),
('suggestions','AVAILABLE','Foreslått dokument tilgjengelig', 'Foreslått dokument tilgjengelig','<<borrowers.firstname>> <<borrowers.surname>>,\n\nDu har foreslått at biblioteket kjøper inn <<suggestions.title>> av <<suggestions.author>>.\n\nVi har gleden av å informere deg om at dokumentet nå er innlemmet i samlingen.\n\nEr det noe du lurer på, vennligst kontakt oss på <<branches.branchemail>>.\n\nVennlig hilsen,\n\n<<branches.branchname>>', 'email'),
('suggestions','ORDERED','Innkjøpsforslag i bestilling', 'Innkjøpsforslag i bestilling','Dear <<borrowers.firstname>> <<borrowers.surname>>,\n\nDu har foreslått at biblioteket kjøper inn <<suggestions.title>> av <<suggestions.author>>.\n\nVi har gleden av å informere deg om at dokumentet du foreslo nå er i bestilling.\n\nDu vil få en ny melding når dokumentet er tilgjengelig.\n\nEr det noe du lurer på, vennligst kontakt oss på <<branches.branchemail>>.\n\nVennlig hilsen,\n\n<<branches.branchname>>', 'email'),
('suggestions','REJECTED','Innkjøpsforslag avslått', 'Innkjøpsforslag avslått','<<borrowers.firstname>> <<borrowers.surname>>,\n\nDu har foreslått at biblioteket kjøper inn <<suggestions.title>> av <<suggestions.author>>.\n\nBiblioteket har vurdert innkjøpsforslaget ditt i dag, og bestemt seg for å ikke ta det til følge.\n\nBegrunnelse: <<suggestions.reason>>\n\nEr det noe du lurer på, vennligst kontakt oss på <<branches.branchemail>>.\n\nVennlig hilsen,\n\n<<branches.branchname>>', 'email');
INSERT INTO `letter` (module, code, name, title, content, is_html)
VALUES ('circulation','ISSUESLIP','Utlån','Utlån', '<h3><<branches.branchname>></h3>
Utlånt til <<borrowers.title>> <<borrowers.firstname>> <<borrowers.initials>> <<borrowers.surname>> <br />
(<<borrowers.cardnumber>>) <br />

<<today>><br />

<h4>Utlånt</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Strekkode: <<items.barcode>><br />
Innleveringsfrist: <<issues.date_due>><br />
</p>
</checkedout>

<h4>Forfalte lån</h4>
<overdue>
<p>
<<biblio.title>> <br />
Strekkode: <<items.barcode>><br />
Innleveringsfrist: <<issues.date_due>><br />
</p>
</overdue>

<hr>

<h4 style="text-align: center; font-style:italic;">Nyheter</h4>
<news>
<div class="newsitem">
<h5 style="margin-bottom: 1px; margin-top: 1px"><b><<opac_news.title>></b></h5>
<p style="margin-bottom: 1px; margin-top: 1px"><<opac_news.new>></p>
<p class="newsfooter" style="font-size: 8pt; font-style:italic; margin-bottom: 1px; margin-top: 1px">Publisert <<opac_news.timestamp>></p>
<hr />
</div>
</news>', 1),
('circulation','ISSUEQSLIP','Utlån (enkel)','Utlån (enkel)', '<h3><<branches.branchname>></h3>
Utlånt til <<borrowers.title>> <<borrowers.firstname>> <<borrowers.initials>> <<borrowers.surname>> <br />
(<<borrowers.cardnumber>>) <br />

<<today>><br />

<h4>Utlånt i dag</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Strekkode: <<items.barcode>><br />
Innleveringsfrist: <<issues.date_due>><br />
</p>
</checkedout>', 1),
('circulation','RESERVESLIP','Reservasjon','Reservasjon', '<h5>Dato: <<today>></h5>

<h3> Overfør til/Reservasjon hos <<branches.branchname>></h3>

<h3><<borrowers.surname>>, <<borrowers.firstname>></h3>

<ul>
    <li><<borrowers.cardnumber>></li>
    <li><<borrowers.phone>></li>
    <li> <<borrowers.address>><br />
         <<borrowers.address2>><br />
         <<borrowers.city >>  <<borrowers.zipcode>>
    </li>
    <li><<borrowers.email>></li>
</ul>
<br />
<h3>RESERVERT</h3>
<h4><<biblio.title>></h4>
<h5><<biblio.author>></h5>
<ul>
   <li><<items.barcode>></li>
   <li><<items.itemcallnumber>></li>
   <li><<reserves.waitingdate>></li>
</ul>
<p>Kommentarer:
<pre><<reserves.reservenotes>></pre>
</p>
', 1),
('circulation','TRANSFERSLIP','Overføringslapp','Overføringslapp', '<h5>Dato: <<today>></h5>

<h3>Overføres til <<branches.branchname>></h3>

<h3>EKSEMPLAR</h3>
<h4><<biblio.title>></h4>
<h5><<biblio.author>></h5>
<ul>
   <li><<items.barcode>></li>
   <li><<items.itemcallnumber>></li>
</ul>', 1);

INSERT INTO `letter` (`module`,`code`,`branchcode`,`name`,`is_html`,`title`,`content`)
VALUES (
'members',  'OPAC_REG_VERIFY',  '',  'Verifikasjon av egenregistrering i publikumskatalogen',  '1',  'Verifiser registreringen din',  'Hei!

D har blitt registrert som bruker av biblioteket. Verifiser epostadressen din ved å klikke på lenka nedenfor:

http://<<OPACBaseURL>>/cgi-bin/koha/opac-registration-verify.pl?token=<<borrower_modifications.verification_token>>

Dersom du ikke har bedt om å bli registret som bruker av biblioteket kan du se bort fra denne engangsmeldingen. Forespørselen vil snart gå ut på dato.'
);

INSERT INTO  letter (module, code, branchcode, name, is_html, title, content)
VALUES ('members', 'SHARE_INVITE', '', 'Invitation for sharing a list', '0', 'Share list <<listname>>', 'Dear patron,

One of our patrons, <<borrowers.firstname>> <<borrowers.surname>>, invites you to share a list <<listname>> in our library catalog.

To access this shared list, please click on the following URL or copy-and-paste it into your browser address bar.

<<shareurl>>

In case you are not a patron in our library or do not want to accept this invitation, please ignore this mail. Note also that this invitation expires within two weeks.

Thank you.

Your library.'
);
INSERT INTO  letter (module, code, branchcode, name, is_html, title, content)
VALUES ( 'members', 'SHARE_ACCEPT', '', 'Notification about an accepted share', '0', 'Share on list <<listname>> accepted', 'Dear patron,

We want to inform you that <<borrowers.firstname>> <<borrowers.surname>> accepted your invitation to share your list <<listname>> in our library catalog.

Thank you.

Your library.'
);
