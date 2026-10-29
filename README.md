# Ktisis

City builder sur la Grèce mythologique, dans l'esprit du *Maître de l'Olympe*, avec un contenu 100 % original.
Moteur : Godot 4.3 (GDScript), 2D isométrique, PC.

![Iolcos, mission 3](docs/capture_iolcos.png)

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
godot --headless --path . -s res://tests/run.gd                 # tests du domaine puis du contenu
godot --headless --path . -s res://tests/run.gd -- domain       # seulement le domaine (quelques secondes)
godot --headless --path . -s res://tests/run.gd -- domain grid  # seulement les suites dont le nom contient « grid »
godot --headless --path . -s res://tests/presentation/smoke.gd  # scène principale et clics simulés
godot --headless --path . -s res://tests/tools/balance.gd -- 2 120   # suivi détaillé d'une mission (0 à 2)
xvfb-run godot --path . -s res://tests/tools/screenshot.gd -- capture.png 12   # capture d'écran
```

Les tests tournent aussi dans GitHub Actions. Dans les sessions cloud de Claude Code, Godot est installé par `.claude/hooks/session-start.sh`.

## Organisation

- `data/` : bâtiments, ressources, dieux et missions en JSON. On équilibre ici, sans toucher au code.
- `src/domain/` : le jeu lui-même, en GDScript pur, sans nœud, sans fichier, sans affichage.
  - `city.gd` : la cité (état du monde) ; elle avance par pas fixes et expose commandes et requêtes.
  - `rules.gd` : constantes de règles (durées, rayons, seuils).
  - `catalog.gd` : définitions du jeu, construites à partir de dictionnaires.
  - `world/` : grille (terrain, routes, chemins), bâtiments, marcheurs, générateur de cartes.
  - `systems/` : une règle par fichier (construction, habitat, logistique, services, beauté, travail, incendies, religion, monuments, objectifs), fonctions sans état qui agissent sur la cité.
  - `save_codec.gd` : cité vers dictionnaire et retour.
- `src/infrastructure/` : ce qui touche aux fichiers (lecture de `data/`, sauvegarde et progression dans `user://`).
- `src/presentation/` : nœuds Godot, rendu isométrique, interface et textes affichés. Seule couche à connaître les deux autres.
- `tests/` : `domain/` (tests unitaires, avec des données écrites à la main dans `lib/fixtures.gd`), `content/` (les vraies données et l'équilibrage de la campagne), `presentation/` (smoke test), `tools/` (planificateur, suivi d'équilibrage, captures).
- `assets/` : sprites optionnels, voir `assets/README.md`.
