FlightTimer Forever 2.0.0

OBJECTIF
- Conserver la base de trajets Classic existante.
- NE JAMAIS recalculer un trajet déjà présent dans FlightData.lua.
- Chronométrer uniquement un couple départ/destination absent de la base Classic.
- Les maîtres de vol et destinations sont ceux fournis par le jeu : l'addon ne recrée pas les points de vol.

FONCTIONNEMENT
1. Ouvre un maître de vol normalement.
2. Prends une destination normalement.
3. Si départ -> destination existe dans FlightData.lua : aucun apprentissage.
4. Si la liaison est absente : le vol est chronométré et enregistré comme nouveau trajet Forever.
5. Les mesures suivantes de ce nouveau trajet améliorent uniquement sa moyenne.

COMMANDES
/ft forever     Affiche les nouveaux trajets Forever appris.
/ft newroutes   Identique.
/ft foreverreset Efface uniquement les trajets Forever appris.

DONNEES
SavedVariables: FlightTimerDB.forever.newRoutes
