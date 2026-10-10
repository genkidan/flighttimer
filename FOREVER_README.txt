FlightTimer Forever 2.0.3

2.0.3 : Sépare les mesures par build, faction, langue, coordonnées X/Y et
succession des escales. Conserve le libellé Base Classic pendant le compte à
rebours et gère le refus explicite d'arrêt anticipé. Interface : 16001.

OBJECTIF
- Conserver les temps Classic de FlightData.lua : ils sont prioritaires sur
  les anciennes mesures personnelles et ne sont jamais recalculés.
- Apprendre uniquement les nouveaux couples départ/destination identifiés.
- Utiliser les points de vol fournis par le jeu.

APPRENTISSAGE
Un vol complet absent de la base Classic est enregistré dans
FlightTimerDB.forever.newRoutes puis mis en cache dans FlightTimerDB.routes.
Les vols complets suivants améliorent sa moyenne.
Les démonstrations et vols sans points identifiés ne sont pas appris.
Le nombre d'escales et leurs coordonnées doivent être intégralement identifiés.
Chaque itinéraire et contexte client possède sa propre moyenne. Les anciennes
mesures restent conservées mais ne servent plus d'estimation pendant les vols.

ARRET ANTICIPE
L'escale affichée est une estimation basée sur les temps connus.
Une chronologie partielle ne propose plus une escale déjà dépassée : lorsque
la suivante est inconnue, l'interface indique simplement « prochain fly ».
Les vols écourtés ne sont pas enregistrés : le point d'arrivée réel n'est pas
confirmé par le suivi actuel. Cela évite d'apprendre une mauvaise destination.

RECHARGEMENT
/reload pendant un vol restaure le suivi et le temps écoulé, à environ une
seconde près. Un vol terminé pendant l'absence de suivi n'est pas enregistré.
Le réglage /ft show est également restauré.

COMMANDES
/ft forever ou /ft newroutes : liste des trajets Forever appris.
/ft foreverreset : efface ces trajets et leurs copies dans le cache.
/ft historyreset : efface toutes les mesures personnelles et Forever.
Ces commandes ne modifient jamais la base Classic.
/ft test : démonstration de 78 secondes sans apprentissage, hors vol uniquement.
/ft lock, unlock, reset, show, hide : réglages de la fenêtre.
/flytimer accepte les mêmes commandes que /ft.

SON
Clic gauche sur Son : activer/désactiver.
Clic droit : choisir et pré-écouter l'une des cinq alertes.

TESTS
Depuis le dossier de l'addon : lua tests/regression.lua
Les événements et atterrissages réels restent à valider dans le jeu.
Les clés Classic restent fondées sur X uniquement pour conserver la base
historique. Leur correspondance et les durées Forever ne sont pas certifiées.
