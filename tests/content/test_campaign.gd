extends "res://tests/lib/test_case.gd"
## Équilibrage : chaque mission, jouée par le planificateur (tests/tools/planner.gd), se gagne à temps.
## Une mission à choix du protecteur doit se gagner quel que soit le dieu choisi.

const Balance = preload("res://tests/tools/balance.gd")
const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")

const LIMITS := [24, 54, 84]


func test_each_mission_is_winnable() -> void:
	var catalog = CatalogLoader.load_catalog()
	for mi in LIMITS.size():
		var gods := [""]
		var options: Array = catalog.missions[mi].get("patron_choice", {}).get("options", [])
		if not options.is_empty():
			gods = options.map(func(o): return o["god"])
		for god in gods:
			var r: Dictionary = Balance.play(mi, LIMITS[mi], false, true, god)
			var who := "" if god == "" else " (%s)" % god
			print("    mission %d%s : gagnée %s en %d mois, population %d, trésor %d" % [
				mi + 1, who, r["won"], r["months"], r["population"], r["money"]])
			check(r["won"], "mission %d%s gagnée en %d mois" % [mi + 1, who, LIMITS[mi]])
