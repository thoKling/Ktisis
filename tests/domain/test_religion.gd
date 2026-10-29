extends "res://tests/lib/test_case.gd"
## Faveur des dieux, fêtes et choix du dieu protecteur.

const Grid = preload("res://src/domain/world/grid.gd")


func test_favor_follows_worship() -> void:
	var c := Fixtures.flat_city({"gods": ["athena", "poseidon"]})
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	for i in 5:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	place_ok(c, "altar_athena", Vector2i(13, y + 1))
	c.run_months(4)
	check(c.favor["athena"] > c.favor["poseidon"], "Athéna, honorée, passe devant Poséidon")


func test_festival_costs_money_and_has_cooldown() -> void:
	var c := Fixtures.flat_city({"gods": ["demeter"]})
	var money := c.money
	var favor: float = c.favor["demeter"]
	eq(c.festival("demeter"), "", "fête")
	check(c.favor["demeter"] > favor, "la fête plaît")
	check(c.money < money, "la fête coûte")
	check(c.festival("demeter") != "", "pas deux fêtes d'affilée")
	check(c.festival("zeus") != "", "dieu absent de la mission")


func test_the_city_waits_for_its_patron() -> void:
	var c := Fixtures.contested_city()
	check(c.needs_patron_choice(), "le choix est à faire")
	eq(c.rival(), "", "pas encore de dieu éconduit")
	check(not c.is_available("temple_athena") and not c.is_available("temple_poseidon"),
		"aucun temple de prétendant avant le choix")
	check(c.is_available("gate"), "les monuments communs de l'Acropole restent disponibles")
	check(c.choose_patron("hera") != "", "Héra ne prétend pas à la cité")
	check(not Fixtures.flat_city().needs_patron_choice(), "une mission sans prétendants n'attend rien")


func test_choosing_athena() -> void:
	var c := Fixtures.contested_city()
	var buildings := c.buildings.size()
	eq(c.choose_patron("athena"), "", "choix d'Athéna")
	eq(c.patron, "athena", "Athéna protège la cité")
	eq(c.rival(), "poseidon", "Poséidon est éconduit")
	check(not c.needs_patron_choice(), "le choix est fait")
	check(c.choose_patron("poseidon") != "", "on ne change pas de protecteur")
	eq(c.buildings.size(), buildings + 1, "le présent apparaît")
	var gift = c.building_at(Vector2i(26, 6))
	check(gift != null and gift.type == "olive_gift", "l'olivier sacré pousse sur la colline")
	check(not c.demolish(Vector2i(26, 6)), "on n'abat pas l'olivier sacré")
	eq(c.production_mult("olives"), 1.5, "les oliveraies produisent moitié plus")
	eq(c.production_mult("fish"), 1.0, "rien pour la pêche")
	eq(c.favor["athena"], 60.0, "la protectrice est ravie")
	eq(c.favor["poseidon"], 25.0, "le dieu éconduit est offensé")
	eq(c.events[-1]["text"], "Poséidon se sent offensé : honorez-le pour apaiser sa jalousie.", "avertissement")
	check(c.is_available("temple_athena"), "le temple d'Athéna se bâtit")
	check(not c.is_available("temple_poseidon"), "celui de Poséidon, non")


func test_choosing_poseidon() -> void:
	var c := Fixtures.contested_city()
	eq(c.choose_patron("poseidon"), "", "choix de Poséidon")
	eq(c.rival(), "athena", "Athéna est éconduite")
	eq(c.events[-1]["text"], "Athéna se sent offensée : honorez-la pour apaiser sa jalousie.", "accord au féminin")
	c.festival("athena")
	eq(c.events[-1]["text"], "Fête en l'honneur d'Athéna : sa faveur grandit.", "élision")
	eq(c.building_at(Vector2i(26, 6)).type, "spring_gift", "la source jaillit sur la colline")
	eq(c.production_mult("fish"), 1.5, "la pêche rapporte moitié plus")
	eq(c.production_mult("olives"), 1.0, "rien pour les olives")
	check(c.is_available("temple_poseidon") and not c.is_available("temple_athena"), "seul son temple se bâtit")


func test_the_rival_is_jealous() -> void:
	# Mêmes maisons, mêmes autels pour les deux dieux : seul le dieu éconduit perd de la faveur.
	var c := Fixtures.contested_city()
	c.choose_patron("athena")
	c.favor["athena"] = 50.0
	c.favor["poseidon"] = 50.0
	var y := c.entry.y
	Fixtures.main_road(c, 20)
	for i in 5:
		place_ok(c, "house", Vector2i(2 + i * 2, y + 1))
	c.run_months(3)
	check(c.favor["poseidon"] < c.favor["athena"] - 2.0, "Poséidon s'aigrit plus vite (%d contre %d)" % [
		c.favor["poseidon"], c.favor["athena"]])
