extends "res://tests/lib/test_case.gd"
## Marcheurs de service : eau, culte, impôt.


func _street(c) -> int:
	var y: int = c.entry.y
	Fixtures.main_road(c, 20)
	for i in 4:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	return y


func test_water_and_religion_reach_houses() -> void:
	var c := Fixtures.flat_city()
	var y := _street(c)
	place_ok(c, "fountain", Vector2i(12, y + 1))
	place_ok(c, "altar_demeter", Vector2i(13, y + 1))
	c.run_months(3)
	var h = c.building_at(Vector2i(2, y + 1))
	check(c.house_need_met(h, "water"), "eau livrée")
	check(c.house_need_met(h, "religion"), "culte livré")
	check(h.religion.has("demeter"), "culte de Déméter")


func test_roadblock_stops_service_walkers() -> void:
	var c := Fixtures.flat_city()
	var y := _street(c)
	place_ok(c, "roadblock", Vector2i(11, y))
	place_ok(c, "fountain", Vector2i(14, y + 1))
	c.run_months(3)
	check(not c.house_need_met(c.building_at(Vector2i(2, y + 1)), "water"), "l'eau ne passe pas le barrage")


func test_tax_collector_brings_money() -> void:
	var c := Fixtures.flat_city()
	var y := _street(c)
	place_ok(c, "tax_office", Vector2i(12, y + 1))
	var money := c.money
	c.run_months(4)
	check(c.money > money, "l'impôt rentre (%d -> %d)" % [money, c.money])
