extends "res://tests/lib/test_case.gd"
## Incendies et vigiles.


func test_fire_without_guard() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	place_ok(c, "house", Vector2i(4, y + 1))
	c.run_months(24)
	check(c.building_at(Vector2i(4, y + 1)) != null, "pas d'incendie avant que le risque n'atteigne 100")
	c.run_months(3)
	check(c.building_at(Vector2i(4, y + 1)) == null, "une maison sans vigile finit par brûler")


func test_guard_prevents_fire() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	place_ok(c, "house", Vector2i(4, y + 1))
	place_ok(c, "guard_post", Vector2i(8, y + 1))
	c.run_months(27)
	check(c.building_at(Vector2i(4, y + 1)) != null, "le vigile prévient l'incendie")
