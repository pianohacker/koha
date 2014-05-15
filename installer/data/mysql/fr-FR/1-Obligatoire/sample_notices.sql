INSERT IGNORE INTO `letter`
(module, code, name, title, content, message_transport_type)
VALUES)
('circulation','ODUE','Avis de retard','Document en retard','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\n\nSelon nos informations actuelles, vous avez des documents signalés en retard dans votre compte.La Bibliothèque n\'applique pas les pénalités, mais nous vous invitons à retourner ou renouveler ces documents au plus vite dans la Bibliothèque suivante.\n\n<<branches.branchname>>\n<<branches.branchaddress1>>\n<<branches.branchaddress2>> <<branches.branchaddress3>>\nTéléphone: <<branches.branchphone>>\nFax: <<branches.branchfax>>\nCourriel: <<branches.branchemail>>\n\nSi vous possédez un identifiant et un mot de passe pour vous connecter à notre catalogue en ligne,vous pouvez depuis celui-ci prolonger la durée de prêt des documents. Si les documents ont plus de 3à jours de retard, vous ne pourrez plus utiliser votre carte d\'adhérent tant que les documents ne seront pas rendus.\n\nLe(s) document(s) actuellement en retard:\n\n<item>"<<biblio.title>>" de <<biblio.author>>, <<items.itemcallnumber>>, Code barres: <<items.barcode>> Pénalité: <<items.fine>></item>\n\nAvec nos remerciements.\n\n<<branches.branchname>> La banque de prêt\n', 'email'),
('claimacquisition','ACQCLAIM','Réclamation Acquisitions','Document non reçu','<<aqbooksellers.name>>\r\n<<aqbooksellers.address1>>\r\n<<aqbooksellers.address2>>\r\n<<aqbooksellers.address3>>\r\n<<aqbooksellers.address4>>\r\n<<aqbooksellers.phone>>\r\n\r\n<order>Commande <<aqorders.ordernumber>> (<<biblio.title>>) (<<aqorders.quantity>> ordered) ($<<aqorders.listprice>> each) pas encore reçue.</order>', 'email'),
('serial','RLIST','Liste de routage','Fascicule de périodique disponible','<<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nLe numéro suivant est disponible:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)\r\n\r\nVous pouvez venir le retirer quand vous voulez.', 'email'),
('members','ACCTDETAILS','Nouveau compte adhérent','Votre nouveau compte adhérent.','Bonjour <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>.\r\n\r\nLes informations de votre nouveau compte sont:\r\n\r\nIdentifiant:  <<borrowers.userid>>\r\nMot de passe: <<borrowers.password>>\r\n\r\nSi vous avez des questions au sujet de votre nouveau compte, merci de prendre contact à l\'acceuil de la Bibliothèque.\r\n\r\nMerci,\r\nLa Bibliothèque\r\nkohaadmin@yoursite.org', 'email'),
('circulation','DUE','Document à rendre ','Document à rendre','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nLe document suivant doit être rendu aujourd\'hui:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','DUEDGST','Document à rendre (résumé)','Document à rendre','Vous avez <<count>> document(s) à rendre', 'email'),
('circulation','PREDUE','Document à rendre bientôt','Document à rendre bientôt','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nLa date de retour du doucment suivant est proche:\r\n\r\n<<biblio.title>>, <<biblio.author>> (<<items.barcode>>)', 'email'),
('circulation','PREDUEDGST','Document à rendre bientôt (résumé)','Document à rendre bientôt','Vous avez <<count>> document(s) dont la date de retour est proche', 'email'),
('reserves', 'HOLD', 'Réservation disponible pour retrait', 'Réservation disponible à la banque de retrait du site <<branches.branchname>>', 'Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nVous avez une réservation disponible pour retrait depuis le <<reserves.waitingdate>>:\r\n\r\nTitre: <<biblio.title>>\r\nAuteur: <<biblio.author>>\r\nNuméro de fascicule: <<items.copynumber>>\r\nSite: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>', 'email'),
('reserves', 'HOLD', 'Réservation disponible pour retrait', 'Réservation disponible à la banque de retrait du site <<branches.branchname>>', '<<branches.branchname>>\n<<branches.branchaddress1>>\n<<branches.branchaddress2>>\n\n\nLe service des réservations\n\n\n\n\n\n\n\n<<borrowers.firstname>> <<borrowers.surname>>\n<<borrowers.address>>\n<<borrowers.city>> <<borrowers.zipcode>>\n\n\n\n\n\n\n\n\n\n\n<<borrowers.firstname>> <<borrowers.surname>> <<borrowers.cardnumber>>\n\nVotre réservation est disponible pour retrait depuis le <<reserves.waitingdate>>:\r\n\r\nTitre: <<biblio.title>>\r\nAuteur: <<biblio.author>>\r\nNuméro de fascicule: <<items.copynumber>>\r\n', 'print'),
('circulation','CHECKIN','Document rendu (résumé)','Retours','Les documents suivants ont été rendus:\r\n----\r\n<<biblio.title>>\r\n----\r\nMerci.', 'email'),
('circulation','CHECKOUT','Document prêté (résumé)','Prêts','Les documents suivants ont été prêtés:\r\n----\r\n<<biblio.title>>\r\n----\r\nMerci de votre visite <<branches.branchname>>.', 'email'),
('reserves', 'HOLDPLACED', 'Demande de réservation', 'Demande de réservation','Une demande de réservation a été placée sur le document : <<biblio.title>> (<<biblio.biblionumber>>) par l\'adhérent <<borrowers.firstname>> <<borrowers.surname>> (<<borrowers.cardnumber>>).', 'email'),
('suggestions','ACCEPTED','Suggestion accceptée', 'Suggestion acceptée','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\n\nVous avez crée une suggestion d\'achat au sujet du document <<suggestions.title>> de <<suggestions.author>>.\n\nLa Bibliothèque a reçu votre demande ce jour. Nous donnerons suite à votre demande aussi vite que possible. Vous serez averti par courriel dès que la commande sera envoyée,et quand les documents seront arrivés à la Bibliothèque.\n\nSi vous avez des questions, merci de nous contacter à l\'adresse suivante <<branches.branchemail>>.\n\nMerci,\n\n<<branches.branchname>>', 'email'),
('suggestions','AVAILABLE','Suggestion disponible', 'Suggestion d\'achat disponible','cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\n\nVous avez effectué une suggestion d\'achat pour le docuement  <<suggestions.title>> de <<suggestions.author>>.\n\nNous sommes heureux de vous informer que le document que vous aviez demandé est maintenant disponible dans nos collections.\n\nSi vous avez des questions, merci de nous contacter par courriel à l\'adresse <<branches.branchemail>>.\n\nMerci,\n\n<<branches.branchname>>', 'email'),
('suggestions','ORDERED','Suggestion commandée', 'Suggestion commandée','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\n\nVous avez effectué une demande de suggestion d\'achat sur le docuement <<suggestions.title>> de <<suggestions.author>>.\n\nNous sommes heureux de vous informer que le document que vous avez demandé est maintenant en commande. Le document devrait arriver rapidement dans nos collections.\n\nVous serez averti quand le docuement sera disponible.\n\nSi vous avez des questions, merci de nous contacter à l\'adresse <<branches.branchemail>>\n\nMerci,\n\n<<branches.branchname>>', 'email'),
('suggestions','REJECTED','Suggestion rejetée', 'Suggestion d\'achat rejeté','Cher(e) <<borrowers.firstname>> <<borrowers.surname>>,\n\nVous avez fait la demande du document <<suggestions.title>> de <<suggestions.author>>.\n\nla Bibliothèque a examiné votre demande ce jour, et a décidé de ne pas retenir la suggestion pour l\'instant.\n\nLa raison est la suivante: <<suggestions.reason>>\n\nSi vous avez des questions, merci de nous contacter à l\'adresse <<branches.branchemail>>.\n\nMerci,\n\n<<branches.branchname>>', 'email');
INSERT INTO `letter` (module, code, name, title, content) VALUES ('circulation','RENEWAL','Item Renewal','Renewals','Les documents suivants ont été renouvelés\r\n----\r\n<<biblio.title>>\r\n----\r\nMerci, <<branches.branchname>>.');

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
