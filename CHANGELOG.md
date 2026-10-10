# FlightTimer 2.0.3-Forever

- Ajout de la traduction allemande (`deDE`). Merci à ExNex pour le code de localisation allemand fourni sur CurseForge.

- Les nouvelles mesures distinguent build, faction, langue, coordonnées X/Y
  et succession des escales ; celles-ci sont conservées avec chaque mesure.
- Le suivi utilise uniquement les mesures personnelles de ce contexte précis.
  Les données anciennes restent sauvegardées mais doivent être réapprises.
- Un itinéraire dont le nombre ou les coordonnées des escales manquent n'est
  pas appris. Le suivi chronométrique reste disponible.
- Le suivi après rechargement conserve le contexte des nouveaux vols ; les
  anciennes sauvegardes sans contexte ne produisent pas de nouvelle mesure.
- Le libellé Base Classic reste affiché pendant le compte à rebours, y compris
  lorsque l'arrivée est imminente.
- Un retour explicite `false` de l'API d'arrêt anticipé est traité comme un
  refus. Un retour sans valeur reste accepté pour compatibilité ; il ne
  constitue pas une confirmation de l'atterrissage réel.
- Les 808 temps Classic et leur format historique sont conservés. L'identité
  officielle des points, la projection des cartes et les durées réelles sur
  Forever nécessitent encore une validation en jeu.

Validation : tests/regression.lua et tests/audit_flight_data.lua avec Fengari.
