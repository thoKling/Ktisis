extends "res://tests/lib/test_case.gd"
## Monuments bâtis par étapes.


func test_sanctuary_is_built_stage_by_stage() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 30)
	for i in 12:
		place_ok(c, "house", Vector2i(2 + i * 2, y - 2))
	c.run_months(3)
	place_ok(c, "warehouse", Vector2i(10, y + 1))
	place_ok(c, "sanctuary_demeter", Vector2i(15, y + 1))
	var s = c.building_at(Vector2i(15, y + 1))
	c.run_months(1)
	eq(s.stage, 0, "sans matériaux le chantier attend")
	var w = c.building_at(Vector2i(10, y + 1))
	w.add_stock("marble", 200)
	w.add_stock("wood", 20)
	w.add_stock("oil", 20)
	c.run_months(14)
	check(s.complete, "sanctuaire achevé (étape %d)" % s.stage)
	check(c.sanctuary_complete("demeter"), "sanctuaire reconnu")
