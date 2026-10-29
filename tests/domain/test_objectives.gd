extends "res://tests/lib/test_case.gd"
## Objectifs de mission et victoire.


func test_population_objective_wins() -> void:
	var c := Fixtures.flat_city({"objectives": [{"type": "population", "value": 10}]})
	Fixtures.main_road(c, 20)
	place_ok(c, "house", Vector2i(5, c.entry.y + 1))
	c.run_months(1)
	check(not c.won, "pas encore gagné")
	place_ok(c, "house", Vector2i(8, c.entry.y + 1))
	c.run_months(2)
	check(c.won, "10 habitants : victoire")
	check(c.objectives()[0]["done"], "objectif rempli")


func test_money_and_level_objectives() -> void:
	var c := Fixtures.flat_city({"start_money": 500, "objectives": [
		{"type": "money", "value": 1000}, {"type": "houses_level", "level": 1, "count": 1}]})
	var objs := c.objectives()
	eq(objs[0]["text"], "Trésor : 500 / 1000", "texte du trésor")
	eq(objs[1]["text"], "Maison simple ou mieux : 0 / 1", "texte des maisons")
	check(not objs[0]["done"] and not objs[1]["done"], "rien n'est rempli")


func test_acropolis_objectives_follow_the_choice() -> void:
	var c := Fixtures.contested_city({"objectives": [{"type": "patron_monument"}, {"type": "rival_favor", "value": 40}]})
	var objs := c.objectives()
	eq(objs[0]["text"], "Achever le temple du dieu protecteur", "temple avant le choix")
	eq(objs[1]["text"], "Apaiser le dieu éconduit (faveur 40)", "rival avant le choix")
	c.choose_patron("poseidon")
	objs = c.objectives()
	eq(objs[0]["text"], "Achever : Temple de Poséidon", "le temple du protecteur choisi")
	eq(objs[1]["text"], "Apaiser Athéna : faveur 25 / 40", "la déesse éconduite")
	check(not objs[0]["done"] and not objs[1]["done"], "rien n'est encore fait")
	c.favor["athena"] = 45.0
	check(c.objectives()[1]["done"], "Athéna apaisée")
