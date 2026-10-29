extends "res://tests/lib/test_case.gd"
## Sauvegarde : une cité convertie en JSON puis relue est la même et continue de vivre.

const SaveCodec = preload("res://src/domain/save_codec.gd")


func test_round_trip_through_json() -> void:
	var c := Fixtures.flat_city()
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	for i in 4:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "fountain", Vector2i(12, y + 1))
	c.run_months(3)
	var text := JSON.stringify(SaveCodec.to_dict(c))
	var c2 = SaveCodec.from_dict(c.catalog, JSON.parse_string(text))
	check(c2 != null, "chargement")
	eq(c2.population, c.population, "population")
	eq(c2.money, c.money, "trésor")
	eq(c2.months, c.months, "date")
	eq(c2.buildings.size(), c.buildings.size(), "bâtiments")
	check(c2.grid.is_road(Vector2i(10, y)), "routes")
	eq(c2.building_at(Vector2i(2, y + 1)).level, c.building_at(Vector2i(2, y + 1)).level, "niveau des maisons")
	c2.run_months(1)
	check(c2.population >= c.population, "la cité rechargée continue de vivre")


func test_unknown_mission_gives_null() -> void:
	var c := Fixtures.flat_city()
	var d := SaveCodec.to_dict(c)
	d["mission"] = "inconnue"
	check(SaveCodec.from_dict(c.catalog, d) == null, "mission inconnue")
