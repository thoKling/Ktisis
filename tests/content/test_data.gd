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
		var all_objectives: Array = m.get("objectives", [])
		for st in m.get("stages", []):
			check(st.get("title", "") != "" and st.get("text", "") != "", "%s : étape sans titre ou sans récit" % m["id"])
			all_objectives += st["objectives"]
		check(not all_objectives.is_empty(), "%s : objectifs" % m["id"])
		for o in all_objectives:
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
		if str(m["map"].get("coast", "")) != "" or "fishery" in m["buildings"]:
			check(water > 100, "%s : côte" % m["id"])
		for type in ["farm", "fishery", "quarry", "woodcutter", "argo_shipyard", "olive_grove"]:
			if type in m["buildings"]:
				check(_somewhere(c, type), "%s : aucun emplacement pour %s" % [m["id"], type])
		_check_patron_choice(c)


## Chaque prétendant a un dieu, un présent qui tient sur la colline, et son temple dans la mission.
func _check_patron_choice(c) -> void:
	var m: Dictionary = c.mission
	if not m.has("patron_choice"):
		return
	var opts: Array = m["patron_choice"]["options"]
	eq(opts.size(), 2, "%s : deux prétendants" % m["id"])
	for o in opts:
		check(o["god"] in m["gods"], "%s : %s honoré dans la mission" % [m["id"], o["god"]])
		var temples := 0
		for id in m["buildings"]:
			if c.catalog.building(id).get("patron", "") == o["god"]:
				temples += 1
		eq(temples, 1, "%s : un temple pour %s" % [m["id"], o["god"]])
		var trial = City.new(c.catalog, m)
		# Le choix vient à l'étape qui le demande.
		for i in m.get("stages", []).size():
			for so in m["stages"][i]["objectives"]:
				if so["type"] == "patron":
					trial.stage = i
		check(trial.needs_patron_choice(), "%s : une étape demande le choix" % m["id"])
		eq(trial.choose_patron(o["god"]), "", "%s : choix de %s" % [m["id"], o["god"]])
		var at := Vector2i(int(m["patron_choice"]["gift_at"][0]), int(m["patron_choice"]["gift_at"][1]))
		var gift = trial.building_at(at)
		check(gift != null and gift.type == o["gift"], "%s : présent de %s posé" % [m["id"], o["god"]])
		for x in 2:
			for y in 2:
				eq(trial.grid.terrain_at(at + Vector2i(x, y)), Grid.T_HILL, "%s : présent sur la colline" % m["id"])
		for id in m["buildings"]:
			if c.catalog.building(id).get("on", "") == "hill" and trial.is_available(id):
				check(_somewhere(trial, id), "%s : place pour %s sur la colline" % [m["id"], id])


func _somewhere(c, type: String) -> bool:
	for y in c.grid.height:
		for x in c.grid.width:
			if c.can_place(type, Vector2i(x, y)) == "":
				return true
	return false
