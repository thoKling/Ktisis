# Ktisis

City builder sur la Grèce mythologique, dans l'esprit du *Maître de l'Olympe*, avec un contenu 100 % original.
Moteur : Godot 4.3 (GDScript), 2D isométrique, PC.

La note de conception vit dans le coffre SecondBrain (`Projects/Ktisis.md`).

## Lancer le jeu

Ouvrir le dossier avec Godot 4.3 et lancer la scène principale (F5), ou :

```
godot --path .
```

## Commandes

| Action | Commande |
|---|---|
| Déplacer la caméra | ZQSD/WASD, flèches, clic molette maintenu |
| Zoom | molette |
| Construire | menu de gauche, puis clic (routes, maisons et jardins : glisser) |
| Annuler l'outil | clic droit ou Échap |
| Démolir | Suppr, puis glisser une zone |
| Vitesse | Espace (pause), 1, 2, 3 |
| Calque de beauté | B |
| Sauvegarder | F5 (puis « Reprendre » dans le menu) |

## Tests

```
godot --headless --path . -s res://tests/run_tests.gd   # simulation
godot --headless --path . -s res://tests/smoke.gd       # scène principale et clics simulés
xvfb-run godot --path . -s res://tests/screenshot.gd -- capture.png 12   # capture d'écran
```

Les tests tournent aussi dans GitHub Actions. Dans les sessions cloud de Claude Code, Godot est installé par `.claude/hooks/session-start.sh`.

## Organisation

- `data/` : bâtiments, ressources, dieux et missions en JSON. On équilibre ici, sans toucher au code.
- `scripts/sim/` : simulation, sans affichage (`city.gd` fait avancer la cité par pas fixes).
- `scripts/view/` : rendu isométrique et interface.
- `assets/` : sprites optionnels, voir `assets/README.md`.
