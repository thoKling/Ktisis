extends "res://tests/lib/test_case.gd"
## Contenu du jeu (res://data) : définitions cohérentes et cartes jouables.

const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")
const City = preload("res://src/domain/city.gd")
const Grid = preload("res://src/domain/world/grid.gd")


func test_references_are_valid() -> void:
	var cat = CatalogLoader.load_catalog()
	check(cat.buildings.size() > 20, "bâtiments chargés")
	eq(cat.missions.size(), 3, "missions")
	for m in cat.missions:
		for b in m["buildings"]:
			check(cat.buildings.has(b), "%s : bâtiment inconnu %s" % [m["id"], b])
		for g in m["gods"]:
			check(cat.gods.has(g), "%s : dieu inconnu %s" % [m["id"], g])
		for o in m["objectives"]:
			if o["type"] == "monument":
				check(cat.buildings.has(o["building"]), "%s : monument inconnu" % m["id"])
	var categories := []
	for cat_def in cat.categories:
		categories.append(cat_def["id"])
	for id in cat.buildings:
		var b: Dictionary = cat.buildings[id]
		check(b["category"] in categories, "%s : catégorie inconnue" % id)
		for k in ["produces", "input"]:
			if b.has(k):
				check(cat.resources.has(b[k]), "%s : ressource inconnue %s" % [id, b[k]])
		if b["kind"] == "service" and b["service"] == "priest":
			check(cat.gods.has(b["god"]), "%s : dieu inconnu" % id)
		if b.has("stages"):
			for st in b["stages"]:
				for r in st:
					check(_storable(cat, r), "%s : %s ne se stocke nulle part" % [id, r])


func _storable(cat, res: String) -> bool:
	for s in cat.buildings.values():
		if s["kind"] == "storage" and res in s["accepts"]:
			return true
	return false


func test_maps_are_playable() -> void:
	var cat = CatalogLoader.load_catalog()
	for m in cat.missions:
		var c := City.new(cat, m)
		check(c.grid.is_road(c.entry), "%s : route d'entrée" % m["id"])
		var meadow := 0
		var water := 0
		for t in c.grid.terrain:
			if t == Grid.T_MEADOW:
				meadow += 1
			if t == Grid.T_WATER:
				water += 1
		check(meadow > 50, "%s : prairies (%d)" % [m["id"], meadow])
		if str(m["map"].get("coast", "")) != "":
			check(water > 100, "%s : côte" % m["id"])
		for type in ["farm", "fishery", "quarry", "woodcutter", "argo_shipyard", "olive_grove"]:
			if type in m["buildings"]:
				check(_somewhere(c, type), "%s : aucun emplacement pour %s" % [m["id"], type])


func _somewhere(c, type: String) -> bool:
	for y in c.grid.height:
		for x in c.grid.width:
			if c.can_place(type, Vector2i(x, y)) == "":
				return true
	return false
