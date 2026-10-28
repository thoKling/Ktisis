extends "res://tests/lib/test_case.gd"
## Faveur des dieux, fêtes et patronage.


func test_favor_follows_worship_and_patron_is_chosen() -> void:
	var c := Fixtures.flat_city({"gods": ["athena", "poseidon"], "patron_contest": true, "patron_threshold": 70})
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	for i in 5:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "altar_athena", Vector2i(13, y + 1))
	c.run_months(4)
	check(c.favor["athena"] > c.favor["poseidon"], "Athéna, honorée, passe devant Poséidon")
	c.run_months(6)
	eq(c.patron, "athena", "Athéna devient patronne")
	check(c.production_mult("olives") >= 1.5, "bonus de l'olivier sacré")


func test_festival_costs_money_and_has_cooldown() -> void:
	var c := Fixtures.flat_city({"gods": ["demeter"]})
	var money := c.money
	var favor: float = c.favor["demeter"]
	eq(c.festival("demeter"), "", "fête")
	check(c.favor["demeter"] > favor, "la fête plaît")
	check(c.money < money, "la fête coûte")
	check(c.festival("demeter") != "", "pas deux fêtes d'affilée")
	check(c.festival("zeus") != "", "dieu absent de la mission")
