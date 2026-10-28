extends SceneTree
## Tests headless de la simulation :
##   godot --headless --path . -s res://tests/run_tests.gd

const Defs = preload("res://scripts/sim/defs.gd")
const City = preload("res://scripts/sim/city.gd")
const Planner = preload("res://tests/planner.gd")
const Balance = preload("res://tests/balance.gd")

var failures := 0
var checks := 0
var current := ""


func _initialize() -> void:
	var tests := [
		"test_data_valid",
		"test_maps_generate",
		"test_placement_rules",
		"test_road_mask_and_path",
		"test_immigration_fills_houses",
		"test_food_chain_upgrades_houses",
		"test_water_and_religion",
		"test_beauty",
		"test_fire_and_guard",
		"test_processor_chain",
		"test_monument_stages",
		"test_favor_and_patron",
		"test_save_load",
		"test_campaign_playable",
	]
	for t in tests:
		current = t
		var before := failures
		call(t)
		print("%s %s" % ["OK   " if failures == before else "ÉCHEC", t])
	print("%d vérifications, %d échecs" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  [%s] %s" % [current, msg])


## Mission de test : tout est disponible, carte plate.
func flat_city(extra := {}) -> City:
	var defs = Defs.get_defs()
	var m := {
		"id": "test", "title": "Test",
		"map": {"width": 40, "height": 40, "seed": 5, "coast": "", "lakes": 0, "meadows": 0, "forests": 0, "rocks": 0},
		"start_money": 100000, "gods": [],
		"buildings": defs.building_order.duplicate(),
		"objectives": [{"type": "population", "value": 50}],
	}
	m.merge(extra, true)
	return City.new(m)


func set_terrain(c: City, from: Vector2i, to: Vector2i, t: int) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			c.terrain[c.idx(Vector2i(x, y))] = t


## Route horizontale depuis l'entrée jusqu'à x_end.
func main_road(c: City, x_end: int) -> void:
	c.place_road_path(City.l_path(Vector2i(0, c.entry.y), Vector2i(x_end, c.entry.y)))


func place_ok(c: City, type: String, p: Vector2i) -> void:
	var err := c.place(type, p)
	check(err == "", "pose de %s en %s : %s" % [type, p, err])


# ------------------------------------------------------------------

func test_data_valid() -> void:
	var defs = Defs.get_defs()
	check(defs.buildings.size() > 20, "bâtiments chargés")
	check(defs.missions.size() == 3, "3 missions")
	for m in defs.missions:
		for b in m["buildings"]:
			check(defs.buildings.has(b), "%s : bâtiment inconnu %s" % [m["id"], b])
		for g in m["gods"]:
			check(defs.gods.has(g), "%s : dieu inconnu %s" % [m["id"], g])
		for o in m["objectives"]:
			if o["type"] == "monument":
				check(defs.buildings.has(o["building"]), "objectif monument inconnu")
	for id in defs.buildings:
		var b: Dictionary = defs.buildings[id]
		for k in ["produces", "input"]:
			if b.has(k):
				check(defs.resources.has(b[k]), "%s : ressource inconnue %s" % [id, b[k]])
		if b["kind"] == "service" and b["service"] == "priest":
			check(defs.gods.has(b["god"]), "%s : dieu inconnu" % id)
		if b.has("stages"):
			for st in b["stages"]:
				for r in st:
					var stored := false
					for s in defs.buildings.values():
						if s["kind"] == "storage" and r in s["accepts"]:
							stored = true
					check(stored, "%s : %s ne se stocke nulle part" % [id, r])


func test_maps_generate() -> void:
	var defs = Defs.get_defs()
	for m in defs.missions:
		var c := City.new(m)
		check(c.width > 0 and c.terrain.size() == c.width * c.height, "%s : carte générée" % m["id"])
		check(c.is_road(c.entry), "%s : route d'entrée" % m["id"])
		var meadow := 0
		var water := 0
		for t in c.terrain:
			if t == Defs.T_MEADOW:
				meadow += 1
			if t == Defs.T_WATER:
				water += 1
		check(meadow > 50, "%s : prairies (%d)" % [m["id"], meadow])
		if str(m["map"].get("coast", "")) != "":
			check(water > 100, "%s : côte" % m["id"])
		# Les bâtiments à contraintes de terrain doivent pouvoir se poser quelque part.
		for type in ["farm", "fishery", "quarry", "woodcutter", "argo_shipyard", "olive_grove"]:
			if not type in m["buildings"]:
				continue
			var found := false
			for y in c.height:
				for x in c.width:
					if c.can_place(type, Vector2i(x, y)) == "":
						found = true
						break
				if found:
					break
			check(found, "%s : aucun emplacement pour %s" % [m["id"], type])


func test_placement_rules() -> void:
	var c := flat_city()
	place_ok(c, "house", Vector2i(10, 10))
	check(c.place("house", Vector2i(11, 11)) != "", "chevauchement refusé")
	check(c.place("farm", Vector2i(20, 5)) == "Il faut une prairie fertile", "ferme hors prairie refusée")
	set_terrain(c, Vector2i(20, 5), Vector2i(22, 7), Defs.T_MEADOW)
	place_ok(c, "farm", Vector2i(20, 5))
	check(c.place("fishery", Vector2i(5, 5)) == "Doit toucher l'eau", "quai loin de l'eau refusé")
	set_terrain(c, Vector2i(30, 30), Vector2i(39, 39), Defs.T_WATER)
	place_ok(c, "fishery", Vector2i(28, 30))
	check(c.place("house", Vector2i(31, 31)) == "Terrain impraticable", "pas de maison dans l'eau")
	check(c.place("statue", Vector2i(2, 2)) != "", "statue sans marbre refusée")
	var money := c.money
	place_ok(c, "garden", Vector2i(3, 3))
	check(c.money == money - 12, "le jardin coûte 12")
	check(c.demolish(Vector2i(3, 3)), "démolition")
	check(c.building_at(Vector2i(3, 3)) == null, "case libérée")
	check(c.place("roadblock", Vector2i(5, 5)) != "", "barrage hors route refusé")
	place_ok(c, "roadblock", Vector2i(1, c.entry.y))
	var poor := flat_city({"start_money": 5})
	check(poor.place("house", Vector2i(10, 10)) == "Pas assez de drachmes", "argent insuffisant")
	var m1 := City.new(Defs.get_defs().missions[0])
	check(m1.can_place("quarry", Vector2i(10, 10)) == "Non disponible dans cette mission", "bâtiment hors mission")


func test_road_mask_and_path() -> void:
	var c := flat_city()
	c.place_road_path(City.l_path(Vector2i(5, 5), Vector2i(10, 8)))
	check(c.is_road(Vector2i(10, 5)) and c.is_road(Vector2i(10, 8)) and c.is_road(Vector2i(7, 5)), "chemin en L")
	check(c.road_mask(Vector2i(7, 5)) == 3, "droite est-ouest")
	check(c.road_mask(Vector2i(10, 5)) == 2 | 4, "virage")
	c.place_road_path(City.l_path(Vector2i(10, 5), Vector2i(10, 2)))
	check(c.road_mask(Vector2i(10, 5)) == 2 | 4 | 8, "jonction en T")
	var p := c.find_path([Vector2i(5, 5)], {Vector2i(10, 8): true}, false)
	check(p.size() == 9, "plus court chemin (%d)" % p.size())
	c.place("roadblock", Vector2i(8, 5))
	check(c.find_path([Vector2i(5, 5)], {Vector2i(10, 8): true}, false).is_empty(), "barrage bloque les services")
	check(not c.find_path([Vector2i(5, 5)], {Vector2i(10, 8): true}, true).is_empty(), "barrage laisse passer les livreurs")


func test_immigration_fills_houses() -> void:
	var c := flat_city()
	main_road(c, 20)
	place_ok(c, "house", Vector2i(5, c.entry.y + 1))
	place_ok(c, "house", Vector2i(8, c.entry.y - 2))
	place_ok(c, "house", Vector2i(15, 30))  # loin de toute route
	c.run_months(2)
	check(c.building_at(Vector2i(5, c.entry.y + 1)).pop == 5, "maison 1 pleine")
	check(c.building_at(Vector2i(8, c.entry.y - 2)).pop == 5, "maison 2 pleine")
	check(c.building_at(Vector2i(15, 30)).pop == 0, "maison sans route vide")
	check(c.population == 10, "population %d" % c.population)
	check(c.workers_available == 5, "travailleurs")


## Ville minimale : grenier, ferme, agora. Les maisons deviennent des maisons simples.
func test_food_chain_upgrades_houses() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 30)
	set_terrain(c, Vector2i(20, y + 1), Vector2i(22, y + 3), Defs.T_MEADOW)
	place_ok(c, "farm", Vector2i(20, y + 1))
	place_ok(c, "granary", Vector2i(15, y + 1))
	place_ok(c, "agora", Vector2i(10, y - 3))
	for i in 6:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1) if i < 6 else Vector2i(0, 0))
	for i in 4:
		place_ok(c, "house", Vector2i(14 + i * 2, y - 2))
	c.run_months(8)
	var granary = c.building_at(Vector2i(15, y + 1))
	var agora = c.building_at(Vector2i(10, y - 3))
	check(c.population >= 40, "population %d" % c.population)
	var fed := 0
	for h in c.houses():
		if h.level >= 1:
			fed += 1
	check(fed >= 8, "maisons nourries montées de niveau : %d" % fed)
	check(granary.total_stock() + agora.total_stock() > 0 or fed >= 8, "le blé circule")


func test_water_and_religion() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 20)
	for i in 4:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "fountain", Vector2i(12, y + 1))
	place_ok(c, "altar_demeter", Vector2i(13, y + 1))
	c.run_months(3)
	var h = c.building_at(Vector2i(2, y + 1))
	check(c.house_need_met(h, "water", null), "eau livrée")
	check(c.house_need_met(h, "religion", null), "culte livré")
	check(h.religion.has("demeter"), "culte de Déméter")


func test_beauty() -> void:
	var c := flat_city()
	place_ok(c, "house", Vector2i(10, 10))
	var h = c.building_at(Vector2i(10, 10))
	c.step()
	check(is_equal_approx(c.house_beauty(h), 0.0), "beauté nulle au départ")
	place_ok(c, "garden", Vector2i(12, 10))
	place_ok(c, "plaza", Vector2i(10, 12))
	c.step()
	var b1 := c.house_beauty(h)
	check(b1 > 8.0, "jardin et place embellissent (%.1f)" % b1)
	set_terrain(c, Vector2i(14, 8), Vector2i(17, 12), Defs.T_ROCK)
	place_ok(c, "quarry", Vector2i(12, 8))
	c.step()
	check(c.house_beauty(h) < b1, "la carrière enlaidit")


func test_fire_and_guard() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 20)
	place_ok(c, "house", Vector2i(4, y + 1))
	place_ok(c, "house", Vector2i(14, y + 1))
	c.run_months(27)
	check(c.building_at(Vector2i(4, y + 1)) == null, "une maison sans vigile finit par brûler")
	var c2 := flat_city()
	main_road(c2, 20)
	place_ok(c2, "house", Vector2i(4, y + 1))
	place_ok(c2, "guard_post", Vector2i(8, y + 1))
	c2.run_months(27)
	check(c2.building_at(Vector2i(4, y + 1)) != null, "le vigile prévient l'incendie")


## Oliveraie -> entrepôt -> pressoir -> entrepôt.
func test_processor_chain() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 30)
	for i in 8:
		place_ok(c, "house", Vector2i(2 + i * 2, y - 2))
	c.run_months(2)
	set_terrain(c, Vector2i(20, y + 1), Vector2i(22, y + 3), Defs.T_MEADOW)
	place_ok(c, "olive_grove", Vector2i(20, y + 1))
	place_ok(c, "warehouse", Vector2i(16, y + 1))
	place_ok(c, "press", Vector2i(24, y + 1))
	c.run_months(8)
	check(c.stored_total("oil") > 0, "de l'huile arrive à l'entrepôt (%d)" % c.stored_total("oil"))


func test_monument_stages() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 30)
	for i in 12:
		place_ok(c, "house", Vector2i(2 + i * 2, y - 2))
	c.run_months(3)
	place_ok(c, "warehouse", Vector2i(10, y + 1))
	place_ok(c, "sanctuary_demeter", Vector2i(15, y + 1))
	c.run_months(1)
	var w = c.building_at(Vector2i(10, y + 1))
	w.add_stock("marble", 200)
	w.add_stock("wood", 20)
	w.add_stock("oil", 20)
	c.run_months(14)
	var s = c.building_at(Vector2i(15, y + 1))
	check(s.complete, "sanctuaire achevé (étape %d)" % s.stage)
	check(c.sanctuary_complete("demeter"), "sanctuaire reconnu")


func test_favor_and_patron() -> void:
	var c := flat_city({"gods": ["athena", "poseidon"], "patron_contest": true, "patron_threshold": 70})
	var y := c.entry.y
	main_road(c, 20)
	for i in 5:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "altar_athena", Vector2i(13, y + 1))
	c.run_months(4)
	check(c.favor["athena"] > c.favor["poseidon"], "Athéna, honorée, passe devant Poséidon")
	check(c.festival("athena") == "", "fête")
	check(c.festival("athena") != "", "pas deux fêtes d'affilée")
	c.run_months(6)
	check(c.patron == "athena", "Athéna devient patronne (%s, faveur %.0f)" % [c.patron, c.favor["athena"]])
	check(c.production_mult("olives") >= 1.5, "bonus de l'olivier sacré")


func test_save_load() -> void:
	var c := flat_city()
	var y := c.entry.y
	main_road(c, 20)
	for i in 4:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "fountain", Vector2i(12, y + 1))
	c.run_months(3)
	# La sauvegarde ne connaît que les missions de la campagne : on y rattache la cité de test.
	c.mission = Defs.get_defs().missions[0]
	var text := JSON.stringify(c.to_dict())
	var c2 = City.from_dict(JSON.parse_string(text))
	check(c2 != null, "chargement")
	check(c2.population == c.population, "population conservée")
	check(c2.money == c.money, "trésor conservé")
	check(c2.buildings.size() == c.buildings.size(), "bâtiments conservés")
	check(c2.is_road(Vector2i(10, y)), "routes conservées")
	c2.run_months(1)
	check(c2.population >= c.population, "la cité rechargée continue de vivre")


## Chaque mission, jouée par le planificateur (tests/planner.gd), se gagne dans un délai raisonnable :
## l'équilibrage de la campagne tient.
func test_campaign_playable() -> void:
	var limits := [24, 48, 84]
	for mi in 3:
		var r: Dictionary = Balance.play(mi, limits[mi], false)
		print("    mission %d : gagnée %s en %d mois, population %d, trésor %d" % [mi + 1, r["won"], r["months"], r["population"], r["money"]])
		check(r["won"], "mission %d gagnée en %d mois" % [mi + 1, limits[mi]])
