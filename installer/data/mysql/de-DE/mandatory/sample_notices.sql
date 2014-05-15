INSERT INTO `letter` (module, code, name, title, content, message_transport_type)
VALUES ('circulation','ODUE','Mahnung','Mahnung','Liebe/r <<borrowers.firstname>> <<borrowers.surname>>,\n\nNach unseren Unterlagen haben Sie Medien entliehen, die nun überfällig geworden sind. Unsere Bibliothek erhebt keine Mahngebühren, bitte geben Sie die entliehenen Medien schnellstmöglich zurück.\n\n<<branches.branchname>>\n<<branches.branchaddress1>>\n<<branches.branchaddress2>> <<branches.branchaddress3>>\nTelefon: <<branches.branchphone>>\nFax: <<branches.branchfax>>\nEmail: <<branches.branchemail>>\n\nSie können die überfälligen Medien soweit möglich auch direkt über Ihr Benutzerkonto online verlängern. Wenn ein Medium länger als 30 Tage überfällig ist, wird Ihr Benutzeraccount gesperrt und Sie können keine Medien mehr entleihen.\n\nDie folgenden Medien sind zur Zeit überfällig:\n\n<item>"<<biblio.title>>" by <<biblio.author>>, <<items.itemcallnumber>>, Barcode: <<items.barcode>> Gebühr: <<items.fine>></item>\n\nVielen Dank für die schnelle Erledigung.\n\n< Ihr Bibliotheksteam\n', 'email'),
('claimacquisition','ACQCLAIM','Reklamation (Erwerbung)','Titel nicht eingetroffen','<<aqbooksellers.name>>\r\n<<aqbooksellers.address1>>\r\n<<aqbooksellers.address2>>\r\n<<aqbooksellers.address3>>\r\n<<aqbooksellers.address4>>\r\n<<aqbooksellers.phone>>\r\n\r\n<order>Ordernumber <<aqorders.ordernumber>> (<<aqorders.title>>) (<<aqorders.quantity>> bestellt) (je $<<aqorders.listprice>> €) sind nicht eingetroffen.</order>', 'email'),
('serial','RLIST','Neues Heft zugegangen','Zeitschrift ist jetzt verfügbar','<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nDas folgende Heft ist jetzt verfügbar:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)\r\n\r\nBitte holen Sie es sobald möglich ab.', 'email'),
('members','ACCTDETAILS','Kontoinformationen - Standard','Ihr neues Benutzerkonto','Liebe/r <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>.\r\n\r\nDie Daten Ihres neuen Benutzerkontos sind:\r\n\r\nBenutzer:  <<borrowers.userid>>\r\nPasswort: <<borrowers.password>>\r\n\r\nWenn Sie Probleme in Hinsicht auf Ihr Benutzerkonto haben, wenden Sie sich bitte an die Bibliothek.\r\n\r\nVielen Dank,\r\nIhr Bibliotheksteam', 'email'),
('circulation','DUE','Fälligkeitsbenachrichtigung','Fälligkeitsbenachrichtigung','Liebe/r <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nDie folgenden Medien sind ab heute fällig:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','DUEDGST','Fälligkeitsbenachrichtigung (Zusammenfassung)','Fälligkeitsbenachrichtigung','Sie haben <<count>> überfällige Medien.', 'email'),
('circulation','PREDUE','Erinnerungsbenachrichtigung','Erinnerungsbenachrichtigung','Liebe/r <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nFolgende Ausleihe wird bald fällig:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','PREDUEDGST','Erinnerungsbenachrichtigung (Zusammenfassung)','Erinnerungsbenachrichtigung','Sie haben <<count>> Ausleihen, die bald fällig werden.', 'email'),
('circulation','RENEWAL','Verlängerungsbenachrichtigung','Verlängerungsquittung','Liebe/r <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nFolgede Exemplare wurden verlängert:\r\n----\r\n<<biblio.title>>\r\n----\r\nVielen Dank,\r\n<<branches.branchname>>.', 'email'),
('reserves', 'HOLD', 'Vormerkbenachrichtigung', 'Vormerkung abholbereit in <<branches.branchname>>', 'Liebe/r <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nFür Sie liegt seit <<reserves.waitingdate>> eine Vormerkung zur Abholung bereit:\r\n\r\nTitel: <<biblio.title>>\r\nVerfasser: <<biblio.author>>\r\nExemplar: <<items.copynumber>>\r\nStandort: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>\r\n<<branches.branchcity>> <<branches.branchzip>>', 'email'),
('reserves', 'HOLD', 'Vormerkbenachrichtigung', 'Vormerkbenachrichtigung (Print)', '<<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchzip>> <<branches.branchcity>>\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n<<borrowers.firstname>> <<borrowers.surname>>\r\n<<borrowers.address>>\r\n<<borrowers.address2>>\r\n<<borrowers.zipcode>> <<borrowers.city>>\r\n<<borrowers.country>>\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\nLiebe(r) <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nFür Sie liegt seit dem <<reserves.waitingdate>> eine Vormerkung zur Abholung bereit:\r\n\r\nTitel: <<biblio.title>>\r\nVerfasser: <<biblio.author>>\r\nSignatur: <<items.itemcallnumber>>\r\n', 'print'),
('circulation','CHECKIN','Rückgabequittung (Zusammenfassung)','Rückgabequittung','Die folgenden Medien wurden zurückgegeben:\r\n----\r\n<<biblio.title>>\r\n----\r\nVielen Dank.', 'email'),
('circulation','CHECKOUT','Ausleihquittung (Zusammenfassung)','Ausleihquittung','Die folgenden Medien wurden entliehen:\r\n----\r\n<<biblio.title>>\r\n----\r\nVielen Dank für Ihren Besuch in <<branches.branchname>>.', 'email'),
('reserves', 'HOLDPLACED', 'Neue Vormerkung', 'Neue Vormerkung','Folgender Titel wurde vorgemerkt: <<biblio.title>> (<<biblio.biblionumber>>) durch den Benutzer <<borrowers.firstname>> <<borrowers.surname>> (<<borrowers.cardnumber>>).', 'email'),
('suggestions','ACCEPTED','Anschaffungsvorschlag wurde angenommen', 'Ihr Anschaffungsvorschlag wurde angenommen','Liebe(r) <<borrowers.firstname>> <<borrowers.surname>>,\n\nSie haben der Bibliothek folgendes Medium zur Anschaffung vorgeschlagen: <<suggestions.title>> by <<suggestions.author>>.\n\nDie Bibliothek hat diesen Titel heute recherchiert und wird Ihn sobald wie möglich im Buchhandel bestellen. Sie erhalten Nachricht, sobald die Bestellung abgeschlossen ist und sobald der Titel in der Bibliotek verfügbar ist.\n\nWenn Sie Fragen haben, richten Sie Ihre Mail bitte an: <<branches.branchemail>>.\n\nVielen Dank,\n\n<<branches.branchname>>', 'email'),
('suggestions','AVAILABLE','Vorgeschlagenes Medium verfügbar', 'Das vorgeschlagene Medium ist jetzt verfügbar','Liebe(r) <<borrowers.firstname>> <<borrowers.surname>>,\n\nSie haben der Bibliothek folgendes Medium zur Anschaffung vorgeschlagen: <<suggestions.title>> von <<suggestions.author>>.\n\nWir freuen uns Ihnen mitteilen zu können, dass dieser Titel jetzt im Bestand der Bibliothek verfügbar ist.\n\nWenn Sie Fragen haben, richten Sie Ihre Mail bitte an: <<branches.branchemail>>.\n\nVielen Dank,\n\n<<branches.branchname>>', 'email'),
('suggestions','ORDERED','Vorgeschlagenes Medium bestellt', 'Das vorgeschlagene Medium wurde im Buchhandel bestellt','Liebe(r) <<borrowers.firstname>> <<borrowers.surname>>,\n\nSie haben der Bibliothek folgendes Medium zur Anschaffung vorgeschlaten: <<suggestions.title>> von <<suggestions.author>>.\n\nWir freuen uns Ihnen mitteilen zu können, dass dieser Titel jetzt im Buchhandel bestellt wurde. Nach Eintreffen wird er in unseren Bestand eingearbeitet.\n\nSie erhalten Nachricht, sobald das Medium verfügbar ist.\n\nBei Nachfragen erreichen Sie uns unter der Emailadresse <<branches.branchemail>>.\n\nVielen Dank,\n\n<<branches.branchname>>', 'email'),
('suggestions','REJECTED','Anschaffungsvorschlag nicht angenommen', 'Ihr Anschaffungsvorschlag wurde nicht angenommen','Liebe(r) <<borrowers.firstname>> <<borrowers.surname>>,\n\nSie haven der Bibliothek folgendes Medium zur Anschaffung vorgeschlagen: <<suggestions.title>> von <<suggestions.author>>.\n\nDie Bibliothek hat diesen Titel heute recherchiert und sich gegen eine Anschaffung entschieden.\n\nBegründung: <<suggestions.reason>>\n\nWenn Sie Fragen haben, richten Sie Ihre Mail bitte an: <<branches.branchemail>>.\n\nVielen Dank,\n\n<<branches.branchname>>', 'email');

INSERT INTO `letter` (module, code, name, title, content, is_html)
VALUES ('circulation','ISSUESLIP','Ausleihquittung (Quittungsdruck)','Ausleihquittung (Quittungsdruck)', '<h2>Ausleihquittung</h2>
Bibliothek: <<branches.branchname>> <br/>
Ausleihe an: <<borrowers.firstname>>  <<borrowers.surname>> <br />
Ausweisnummer: <<borrowers.cardnumber>> <br />
<br />
<<today>><br />
<br />
<h4>Ausleihen</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Signatur: <<items.itemcallnumber>><br/>
Barcode: <<items.barcode>><br />
Fällig am: <<issues.date_due>><br />
</p>
</checkedout>
<br />
<h4>Überfällig</h4>
<overdue>
<p>
<<biblio.title>> <br />
Signatur: <<items.itemcallnumber>><br/>
Barcode: <<items.barcode>><br />
Fällig am: <<issues.date_due>><br />
</p>
</overdue>
<news>
<div class="newsitem">
<h5 style="margin-bottom: 1px; margin-top: 1px"><b><<opac_news.title>></b></h5>
<p style="margin-bottom: 1px; margin-top: 1px"><<opac_news.new>></p>
<p class="newsfooter" style="font-size: 8pt; font-style:italic; margin-bottom: 1px; margin-top: 1px"><<opac_news.timestamp>></p>
<hr />
</div>
</news>', 1),
('circulation','ISSUEQSLIP','Kurzquittung','Kurzquittung', '<h2>Ausleihquittung</h2>
Bibliothek: <<branches.branchname>> <br/>
Ausleihe an: <<borrowers.firstname>>  <<borrowers.surname>> <br />
Ausweisnummer: <<borrowers.cardnumber>> <br />
<br />
<<today>><br />
<br />
<h4>Heutige Ausleihen</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Barcode: <<items.barcode>><br />
Signatur: <<items.itemcallnumber>><br/>
Fällig am: <<issues.date_due>><br />
</p>
</checkedout>', 1),
('circulation','RESERVESLIP','Vormerkquittung','Vormerkquittung', '<h2>Ausleihquittung</h2>
Bibliothek: <<branches.branchname>> <br/>
Ausleihe an: <<borrowers.firstname>>  <<borrowers.surname>> <br />
Ausweisnummer: <<borrowers.cardnumber>> <br />
<br />
<<today>><br />
<br />
<h4>Ausleihen</h4>
<checkedout>
<p>
<<biblio.title>> <br />
Signatur: <<items.itemcallnumber>><br/>
Barcode: <<items.barcode>><br />
Fällig am: <<issues.date_due>><br />
</p>
</checkedout>
<br />
<h4>Überfällig</h4>
<overdue>
<p>
<<biblio.title>> <br />
Signatur: <<items.itemcallnumber>><br/>
Barcode: <<items.barcode>><br />
Fällig am: <<issues.date_due>><br />
</p>
</overdue>
', 1),
('circulation','TRANSFERSLIP','Transportquittung','Transportquittung', '<h2>TRANSPORT</h2>
<h3>Transport nach: <<branches.branchname>></h3>
<h3>Datum: <<today>></h3>
<br/>
<br/>
<h3>EXEMPLAR</h3>
<h4><<biblio.author>><<biblio.title>></h4>
Barcode: <<items.barcode>><br/>
Signatur: <<items.itemcallnumber>><br/>', 1);

INSERT INTO `letter` (`module`,`code`,`branchcode`,`name`,`is_html`,`title`,`content`)
VALUES (
'members',  'OPAC_REG_VERIFY',  '',  'Bestätigung der Anmeldung zur Bibliotheksnutzung',  '1',  'Verify Your Account',  'Guten Tag,

Ihr Bibliothekskonto wurde angelegt. Bitte bestätigen Sie Ihre Emailadresse, indem Sie auf folgenden Link klicken:

http://<<OPACBaseURL>>/cgi-bin/koha/opac-registration-verify.pl?token=<<borrower_modifications.verification_token>>

Wenn Sie keine Kontoanmeldung durchgeführt haben, können Sie diese Benachrichtigung ignorieren. Sie wird in Kürze ungültig.

Vielen Dank,
Ihr Bibliotheksteam'
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
