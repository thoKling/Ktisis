# Génération des sprites

Les bâtiments, arbres, rochers et marcheurs sont des scènes Blender construites en Python (`buildings.py`, avec les briques de `kit.py` : murs, colonnes doriques, toits de tuiles, frises, amphores, cyprès...), rendues par Cycles avec une caméra orthographique isométrique 2:1 et un soleil en haut à gauche. Les sols et routes sont peints en 2D (`terrain.py`).

## Installation (une fois)

Le module `bpy` (Blender sans interface) demande Python 3.13 :

```bash
python3.13 -m venv ~/bvenv
~/bvenv/bin/pip install bpy==5.2.3 pillow
```

## Utilisation

```bash
~/bvenv/bin/python tools/art/render.py              # tous les sprites (environ 3 minutes)
~/bvenv/bin/python tools/art/render.py agora house_4 # seulement ceux-là
~/bvenv/bin/python tools/art/terrain.py             # sols, rivages et routes
```

Pour ajouter un bâtiment : une fonction décorée `@building("<id>", taille)` dans `buildings.py`. Repère : 1 unité = 1 tuile, `tbox`/`cyl`/... prennent des coordonnées de tuiles (x vers le bas-droite de l'écran, y vers le bas-gauche) ; les faces visibles sont en x max et y max.
