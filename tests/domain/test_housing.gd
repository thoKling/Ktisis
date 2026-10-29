extends "res://tests/lib/test_case.gd"
## Habitat : arrivée des colons, besoins, montée et descente de niveau.


func test_immigrants_fill_houses_near_roads() -> void:
	var c := Fixtures.flat_city()
	Fixtures.main_road(c, 20)
	place_ok(c, "house", Vector2i(5, c.entry.y + 1))
	place_ok(c, "house", Vector2i(8, c.entry.y - 2))
	place_ok(c, "house", Vector2i(15, 30))
	c.run_months(2)
	eq(c.building_at(Vector2i(5, c.entry.y + 1)).pop, 5, "maison au bord de la route pleine")
	eq(c.building_at(Vector2i(8, c.entry.y - 2)).pop, 5, "maison à 1 case de la route pleine")
	eq(c.building_at(Vector2i(15, 30)).pop, 0, "maison sans route vide")
	eq(c.population, 10, "population")
	eq(c.workers_available, 5, "la moitié des habitants travaillent")


func test_no_immigration_without_entry_road() -> void:
	var c := Fixtures.flat_city()
	c.demolish(c.entry)
	place_ok(c, "house", Vector2i(2, c.entry.y + 1))
	c.run_months(2)
	eq(c.population, 0, "personne n'arrive")


func test_food_upgrades_and_hunger_downgrades() -> void:
	var c := Fixtures.flat_city()
	Fixtures.main_road(c, 10)
	place_ok(c, "house", Vector2i(2, c.entry.y + 1))
	c.run_months(1)
	var h = c.building_at(Vector2i(2, c.entry.y + 1))
	eq(h.level, 0, "hutte au départ")
	h.add_stock("food", 10)
	c.run_months(1)
	eq(h.level, 1, "nourrie, elle devient maison simple")
	h.stock.clear()
	c.run_months(1)
	eq(h.level, 1, "un mois de faim ne suffit pas à descendre")
	c.run_months(1)
	eq(h.level, 0, "deux mois de faim : retour à la hutte")


func test_missing_needs_for_next_level() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "house", Vector2i(2, 2))
	var h = c.building_at(Vector2i(2, 2))
	eq(c.house_missing_for_next(h), [["food", true]], "la hutte veut de la nourriture")
	h.level = 2
	h.add_stock("food", 5)
	var missing := []
	for m in c.house_missing_for_next(h):
		missing.append(m[0])
	eq(missing, ["water", "religion", "beauty"], "la maison de famille veut eau, culte et beauté")


func test_food_is_eaten_each_month() -> void:
	var c := Fixtures.flat_city()
	place_ok(c, "house", Vector2i(2, 2))
	var h = c.building_at(Vector2i(2, 2))
	h.pop = 9
	h.add_stock("food", 10)
	c.run_months(1)
	eq(h.get_stock("food"), 8, "9 habitants mangent 2 rations")
