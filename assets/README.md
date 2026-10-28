# Assets

Le jeu dessine des formes simples tant qu'aucun sprite n'existe. Pour remplacer une forme, il suffit de déposer un PNG au bon chemin : `scripts/view/art.gd` le charge automatiquement.

## Conventions

- Vue isométrique 2:1, une tuile = 64 x 32 px.
- Soleil en haut à gauche, ombres vers le bas à droite.
- Palette : marbre `#efe9dc`, terre cuite `#c2673f`, ocre `#d4a24c`, vert olivier `#7d8a3e`, bleu égéen `#2f6f9f`.
- Pas de texte dans les images.
- Garder le prompt de génération dans un fichier `.txt` du même nom, à côté du PNG.

## Chemins

| Élément | Fichier | Ancrage |
|---|---|---|
| Sol | `terrain/<n>.png` (0 herbe, 1 eau, 2 forêt, 3 rocher, 4 prairie), 64 x 32 | coin haut-gauche du losange |
| Route | `roads/road_<masque>.png`, masque = 1 est + 2 ouest + 4 sud + 8 nord | centré sur la tuile |
| Bâtiment | `buildings/<id>.png` (id de `data/buildings.json`) | bas du sprite = coin bas de l'emprise, centré |
| Maison | `buildings/house_<niveau>.png`, niveau 0 à 4 | idem |
| Marcheur | `walkers/<service>.png` (water, market, priest, sanctuary, tax, guard, cart, immigrant) | pieds au centre |

Un bâtiment de taille n fait 64·n px de large ; sa hauteur est libre.
