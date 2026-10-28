extends "res://tests/lib/test_case.gd"
## Production, stockage et livraisons.

const Grid = preload("res://src/domain/world/grid.gd")


## Ferme -> grenier -> agora -> maisons : les maisons nourries montent de niveau.
func test_food_chain_feeds_houses() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 30)
	Fixtures.set_terrain(c, Vector2i(20, y + 1), Vector2i(22, y + 3), Grid.T_MEADOW)
	place_ok(c, "farm", Vector2i(20, y + 1))
	place_ok(c, "granary", Vector2i(15, y + 1))
	place_ok(c, "agora", Vector2i(10, y - 3))
	for i in 6:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	for i in 4:
		place_ok(c, "house", Vector2i(14 + i * 2, y - 2))
	c.run_months(8)
	check(c.population >= 40, "population %d" % c.population)
	var fed := 0
	for h in c.houses():
		if h.level >= 1:
			fed += 1
	check(fed >= 8, "maisons nourries montées de niveau : %d" % fed)


## Oliveraie -> entrepôt -> pressoir -> entrepôt.
func test_processor_chain() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 30)
	for i in 8:
		place_ok(c, "house", Vector2i(2 + i * 2, y - 2))
	c.run_months(2)
	Fixtures.set_terrain(c, Vector2i(20, y + 1), Vector2i(22, y + 3), Grid.T_MEADOW)
	place_ok(c, "olive_grove", Vector2i(20, y + 1))
	place_ok(c, "warehouse", Vector2i(16, y + 1))
	place_ok(c, "press", Vector2i(24, y + 1))
	c.run_months(8)
	check(c.stored_total("oil") > 0, "de l'huile arrive à l'entrepôt (%d)" % c.stored_total("oil"))


func test_unstaffed_building_produces_nothing() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 30)
	Fixtures.set_terrain(c, Vector2i(20, y + 1), Vector2i(22, y + 3), Grid.T_MEADOW)
	place_ok(c, "farm", Vector2i(20, y + 1))
	c.run_months(2)
	var farm = c.building_at(Vector2i(20, y + 1))
	eq(farm.workers, 0, "aucun habitant, aucun employé")
	eq(farm.total_stock(), 0, "pas de récolte")
