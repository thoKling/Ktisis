extends "res://tests/lib/test_case.gd"
## Beauté : la décoration embellit, l'industrie enlaidit.

const Grid = preload("res://src/domain/world/grid.gd")


func test_decorations_and_industry() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "house", Vector2i(10, 10))
	var h = c.building_at(Vector2i(10, 10))
	check(is_equal_approx(c.house_beauty(h), 0.0), "beauté nulle au départ")
	place_ok(c, "garden", Vector2i(12, 10))
	place_ok(c, "plaza", Vector2i(10, 12))
	var b1 := c.house_beauty(h)
	check(b1 > 8.0, "jardin et place embellissent (%.1f)" % b1)
	Fixtures.set_terrain(c, Vector2i(14, 8), Vector2i(17, 12), Grid.T_ROCK)
	place_ok(c, "quarry", Vector2i(12, 8))
	check(c.house_beauty(h) < b1, "la carrière enlaidit")
	c.demolish(Vector2i(12, 8))
	check(is_equal_approx(c.house_beauty(h), b1), "démolir la carrière rend la beauté")


func test_beauty_readable_before_first_step() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "garden", Vector2i(12, 10))
	check(c.beauty_at(Vector2i(12, 10)) > 0.0, "la beauté d'une case se lit avant le premier pas")
	check(is_equal_approx(c.beauty_at(Vector2i(0, 0)), 0.0), "case loin du jardin : beauté nulle")
