# Assets

Les sprites sont générés par les scripts de `tools/art` (voir son README) : chaque bâtiment est une petite maquette 3D Blender rendue en vue isométrique. `scripts/view/art.gd` charge automatiquement tout PNG présent au bon chemin ; sinon le jeu dessine une forme simple.

## Conventions

- Vue isométrique 2:1, une tuile = 64 x 32 px **à l'écran**. Les fichiers sont en 2x (tuile de 128 x 64) et dessinés à l'échelle 0,5 (`Art.SPRITE_SCALE`), pour rester nets au zoom.
- Soleil en haut à gauche, ombres vers la droite. Style illustré, pas réaliste, mais détaillé.
- Palette : marbre `#efe9dc`, terre cuite `#c2673f`, ocre `#d4a24c`, vert olivier `#7d8a3e`, bleu égéen `#2f6f9f`.
- Pas de texte dans les images.

## Chemins

| Élément | Fichier | Ancrage |
|---|---|---|
| Sol | `terrain/<n>_<v>.png` (n : 0 herbe, 1 eau, 2 forêt, 3 rocher, 4 prairie ; v = x mod 4 + 4·(y mod 4)), 128 x 64 | coin haut du losange |
| Rivage | `terrain/shore_<b>.png`, posé sur l'eau du côté de la terre (b = 1 x+, 2 x-, 4 y+, 8 y-) | idem |
| Route | `roads/road_<masque>.png`, masque = 1 est + 2 ouest + 4 sud + 8 nord | centré sur la tuile |
| Décor | `props/forest_<0-3>.png`, `props/rock_<0-2>.png` (arbres et rochers, triés avec les bâtiments) | comme un bâtiment de taille 1 |
| Bâtiment | `buildings/<id>.png` (id de `data/buildings.json`) | bas du sprite = coin bas de l'emprise, centré |
| Maison | `buildings/house_<niveau>.png` (0 à 4), `buildings/house_empty.png` (parcelle sans habitants) | idem |
| Chantier | `buildings/<id>_s<étape>.png`, sinon `buildings/monument_s<étape>.png` | idem |
| Marcheur | `walkers/<service>.png` (water, market, priest, sanctuary, tax, guard, cart, immigrant) | pieds au centre |

Un bâtiment de taille n fait 128·n px de large dans le fichier ; sa hauteur est libre.
