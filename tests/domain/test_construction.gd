extends "res://tests/lib/test_case.gd"
## Règles de pose, coût et démolition.

const Grid = preload("res://src/domain/world/grid.gd")


func test_overlap_is_refused() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "house", Vector2i(10, 10))
	eq(c.place("house", Vector2i(11, 11)), "Emplacement occupé", "chevauchement")


func test_terrain_constraints() -> void:
	var c := Fixtures.flat_city()
	eq(c.place("farm", Vector2i(20, 5)), "Il faut une prairie fertile", "ferme hors prairie")
	Fixtures.set_terrain(c, Vector2i(20, 5), Vector2i(22, 7), Grid.T_MEADOW)
	place_ok(c, "farm", Vector2i(20, 5))
	eq(c.place("fishery", Vector2i(5, 5)), "Doit toucher l'eau", "quai loin de l'eau")
	Fixtures.set_terrain(c, Vector2i(30, 30), Vector2i(39, 39), Grid.T_WATER)
	place_ok(c, "fishery", Vector2i(28, 30))
	eq(c.place("house", Vector2i(31, 31)), "Terrain impraticable", "maison dans l'eau")
	eq(c.place("quarry", Vector2i(5, 20)), "Doit être près d'un rocher", "carrière loin des rochers")


func test_cost_in_money_and_resources() -> void:
	var c := Fixtures.flat_city()
	var money := c.money
	place_ok(c, "garden", Vector2i(3, 3))
	eq(c.money, money - 12, "le jardin coûte 12")
	eq(c.place("statue", Vector2i(2, 2)), "Il faut 4 Marbre en entrepôt", "statue sans marbre")
	place_ok(c, "warehouse", Vector2i(20, 20))
	c.building_at(Vector2i(20, 20)).add_stock("marble", 6)
	place_ok(c, "statue", Vector2i(2, 2))
	eq(c.stored_total("marble"), 2, "la statue consomme 4 marbres")
	var poor := Fixtures.flat_city({"start_money": 5})
	eq(poor.place("house", Vector2i(10, 10)), "Pas assez de drachmes", "argent insuffisant")


func test_demolish_frees_the_tiles() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "house", Vector2i(3, 3))
	check(c.demolish(Vector2i(4, 4)), "démolition depuis n'importe quelle case")
	check(c.building_at(Vector2i(3, 3)) == null, "case libérée")
	place_ok(c, "house", Vector2i(3, 3))


func test_roadblock_needs_a_road() -> void:
	var c := Fixtures.flat_city()
	check(c.place("roadblock", Vector2i(5, 5)) != "", "barrage hors route")
	place_ok(c, "roadblock", Vector2i(1, c.entry.y))
	eq(c.grid.road_at(Vector2i(1, c.entry.y)), Grid.R_BLOCK, "la route devient un barrage")


func test_building_must_be_in_the_mission() -> void:
	var c := Fixtures.flat_city({"buildings": ["road", "house"]})
	eq(c.can_place("farm", Vector2i(10, 10)), "Non disponible dans cette mission", "bâtiment hors mission")
	check(not c.is_available("farm"), "ferme indisponible")
