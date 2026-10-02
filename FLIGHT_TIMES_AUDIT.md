# Audit des temps de vol — 2 octobre 2026

La couverture exhaustive et la conformité des durées pour WoW Forever ne sont
pas établies. La table embarquée est une base Classic incomplète ; elle ne
constitue pas un catalogue vérifié du réseau Forever.

## Vérifications locales

Client installé : `WowB.exe`, version `1.60.1.70170`, également confirmée par
le fichier `.build.info` de l'installation.

| Mesure | Alliance | Horde |
| --- | ---: | ---: |
| Clés de points de vol dans la table | 32 | 31 |
| Durées directionnelles | 364 | 444 |
| Durée minimale | 54 s | 52 s |
| Durée maximale | 856 s | 903 s |
| Durées nulles, négatives ou non entières ; trajets vers soi-même | 0 | 0 |
| Entrées dont le sens inverse manque | 54 | 24 |
| Groupes de points reliés dans la table | 2 | 2 |
| Couples ordonnés possibles à l'intérieur de ces groupes | 480 | 474 |
| Couples sans durée dans ces groupes | 116 | 30 |
| Couverture de ces couples | 75,8 % | 93,7 % |

Total : **808 durées**, **61 clés de coordonnées distinctes** entre factions.
Ces clés sont calculées avec `floor(x * 100000000)` et ne sont pas des identifiants
officiels de points de vol. Une clé commune entre factions ne garantit pas le
même maître de vol. Le fichier ne stocke ni les noms, ni les IDs, ni le build des
mesures, ni la succession des escales.

Les 146 couples manquants concernent uniquement les groupes présents dans cette
table. Ce n'est pas un décompte des vols réellement proposés par Forever : il
faut vérifier les conditions de faction, classe, découverte et accessibilité.
Les trajets intercontinentaux sont exclus de ce calcul. L'absence de mesure
inverse ou une différence aller/retour ne prouve pas qu'une durée est fausse.

Audit reproductible, depuis le dossier de l'addon :

```text
lua tests/audit_flight_data.lua
```

## Origine des temps

Comparaison automatique de toutes les entrées locales avec les 940 lignes du
[fichier Data.lua de FlightTimerClassic](https://raw.githubusercontent.com/timohausmann/FlightTimerClassic/master/Data.lua)
consulté le 2 octobre 2026 : 808 entrées dans chaque table, aucune différence de
clé ou de durée. Aucun temps spécifique Forever n'a été ajouté à FlightData.lua.
Cette égalité confirme la provenance, pas l'exactitude des temps dans Forever.

## Points Forever absents de la base Classic

L'[extraction Taxi.lua de ShortestPathForever](https://raw.githubusercontent.com/cjber/shortest-path-forever/main/Data/Taxi.lua)
pour le build **1.60.1.69913** identifie notamment les ajouts suivants :

| ID client dans cette extraction | Point | Zone | Faction indiquée |
| ---: | --- | --- | --- |
| 559 | Summit of Eternity | Mount Hyjal | Commun |
| 3242 | Tainted Foothills | Mount Hyjal | Commun |
| 3203 | Rog'mar | Riverglades | Horde |
| 3275 | Powderfuse Port | Riverglades | Alliance |
| 3276 | Farholde Keep | Riverglades | Alliance |

Leur ajout n'est pas représenté dans la base Classic copiée. Ils peuvent être
capturés puis appris dynamiquement si les API de l'addon identifient correctement
le départ et la destination. Cela ne fournit pas un temps préchargé pour le
premier vol. L'extraction citée distingue les temps Classic mesurés des temps
estimés ; elle n'est pas une validation en jeu de tous les temps Forever.

Cette liste ne certifie pas tous les points du build installé, plus récent.
Le [générateur de cette extraction](https://raw.githubusercontent.com/cjber/shortest-path-forever/main/tools/gen_transit.py)
exclut volontairement les vols réservés aux druides, les tours PvP et les trajets
de quête/test/transport. Il ne suffit donc pas pour contrôler « tous » les vols.
Les exports directs TaxiNodes/TaxiPath de Wago n'ont pas été accessibles pendant
cet audit ; aucune table exhaustive du build 70170 n'a pu être comparée.

## Limites du suivi actuel

1. La sauvegarde existante contient une mesure ancienne de **110,276 s**, avec
   départ vide, destination `Destination`, un échantillon et aucun identifiant
   de point. Elle ne valide aucun trajet identifiable. Le garde-fou ajouté en
   2.0.1 empêche d'enregistrer de nouveaux trajets sans les deux hashes ; cette
   donnée historique reste présente et n'a pas été effacée pendant l'audit.
2. La capture utilise exclusivement `NumTaxiNodes`, `TaxiNodeName`,
   `TaxiNodePosition` et le hook global `TakeTaxiNode`. L'[API Blizzard de la
   branche classic_beta](https://raw.githubusercontent.com/Gethe/wow-ui-source/classic_beta/Interface/AddOns/Blizzard_APIDocumentationGenerated/TaxiMapDocumentation.lua)
   expose aussi `C_TaxiMap.GetAllTaxiNodes` et `GetTaxiNodesForMap`. Il manque
   une vérification en jeu de la capture actuelle et de la correspondance des
   coordonnées avec la table Classic ; la présence d'un chronomètre seule ne
   garantit pas l'identification correcte des points.
3. Une modification de la projection de la carte peut faire perdre la
   correspondance des hashes. Le code ne contrôle ni carte ni coordonnée Y dans
   son identifiant Classic.
4. L'apprentissage Forever regroupe les mesures par noms de départ et d'arrivée,
   sans distinguer faction, langue, build ou escales. Une même paire peut
   emprunter un itinéraire différent selon les points connus et les changements
   du client ; sa moyenne n'est donc pas une preuve de conformité du vol choisi.
5. Une durée Classic existante n'est jamais remesurée par la logique actuelle.
   Si Forever modifie un ancien trajet, une vitesse ou son itinéraire, cette
   différence ne sera pas détectée ni corrigée automatiquement.

## Conditions pour certifier la conformité

- Extraire TaxiNodes, TaxiPath et TaxiPathNode du build installé, en conservant
  IDs, cartes, factions et conditions d'accès ; isoler vols ordinaires et spéciaux.
- Faire correspondre ces IDs avec les points réellement exposés par la carte
  de vol du client et vérifier chaque hash Classic avant de réutiliser sa durée.
- Établir un inventaire des routes et escales réellement sélectionnées.
- Mesurer les vols Forever avec départ et arrivée confirmés ; garder les temps
  mesurés, les références Classic et les estimations dans des champs distincts.
- Rapporter les écarts par build et itinéraire sans écraser FlightData.lua.

Aucune durée embarquée, sauvegarde du joueur ou archive de release n'a été
modifiée par cet audit. Seuls ce rapport et le script d'audit ont été ajoutés.
