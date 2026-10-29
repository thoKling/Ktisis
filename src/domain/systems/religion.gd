extends RefCounted
## Dieux : faveur, fêtes, bénédictions, colères et concours pour le patronage de la cité.

const Rules = preload("res://src/domain/rules.gd")
const Effects = preload("res://src/domain/systems/effects.gd")
const Construction = preload("res://src/domain/systems/construction.gd")
const Monuments = preload("res://src/domain/systems/monuments.gd")


static func setup(c, gods: Array) -> void:
	for god in gods:
		c.favor[god] = Rules.START_FAVOR
		c.god_cd[god] = {"festival": 0, "blessing": 0, "wrath": 0}


## Fin de mois : la faveur suit la part des maisons couvertes par les prêtres du dieu.
static func monthly(c) -> void:
	var inhabited := []
	for b in c.houses():
		if b.pop > 0:
			inhabited.append(b)
	for god in c.favor:
		var cd: Dictionary = c.god_cd[god]
		for k in cd:
			cd[k] = maxi(0, cd[k] - 1)
		if not inhabited.is_empty():
			var covered := 0
			for b in inhabited:
				if b.religion.get(god, 0) > c.tick:
					covered += 1
			var delta := covered / float(inhabited.size()) * 4.0 - 1.0
			if Monuments.sanctuary_complete(c, god):
				delta += 2.0
			var before: float = c.favor[god]
			c.favor[god] = clampf(before + delta, 0.0, 100.0)
			if before > Rules.UNHAPPY_FAVOR and c.favor[god] <= Rules.UNHAPPY_FAVOR:
				c.log_event("%s est mécontent de vous : bâtissez-lui des autels ou offrez-lui une fête." % c.catalog.god_name(god), "warn")
		var gd: Dictionary = c.catalog.gods[god]
		if c.favor[god] >= Rules.BLESSING_FAVOR and cd["blessing"] == 0 and c.rng.randf() < 0.25:
			cd["blessing"] = 12
			apply(c, gd["blessing"], god, "good")
		elif c.favor[god] <= Rules.WRATH_FAVOR and cd["wrath"] == 0 and not inhabited.is_empty() and c.rng.randf() < 0.25:
			cd["wrath"] = 8
			apply(c, gd["wrath"], god, "bad")
	_patron_contest(c)


## Mission à concours : le premier dieu à atteindre le seuil devient patron et laisse son présent.
static func _patron_contest(c) -> void:
	if not c.mission.get("patron_contest", false) or c.patron != "":
		return
	var threshold := float(c.mission.get("patron_threshold", 70))
	var best := ""
	for god in c.favor:
		if c.favor[god] >= threshold and (best == "" or c.favor[god] > c.favor[best]):
			best = god
	if best == "":
		return
	c.patron = best
	c.log_event("%s devient le patron de la cité !" % c.catalog.god_name(best), "good")
	apply(c, c.catalog.gods[best]["patron_bonus"], best, "good")


static func festival(c, god: String) -> String:
	if not c.favor.has(god):
		return "Ce dieu n'est pas honoré ici"
	if c.money < Rules.FESTIVAL_COST:
		return "Une fête coûte %d drachmes" % Rules.FESTIVAL_COST
	if c.god_cd[god]["festival"] > 0:
		return "Une fête a déjà eu lieu récemment (encore %d mois)" % c.god_cd[god]["festival"]
	c.money -= Rules.FESTIVAL_COST
	c.favor[god] = minf(100.0, c.favor[god] + Rules.FESTIVAL_FAVOR)
	c.god_cd[god]["festival"] = Rules.FESTIVAL_COOLDOWN
	c.log_event("Fête en l'honneur de %s : sa faveur grandit." % c.catalog.god_name(god), "good")
	return ""


static func apply(c, e: Dictionary, god: String, tone: String) -> void:
	match e["type"]:
		"production_mult", "immigration_mult", "service_range_mult":
			Effects.add(c, e, god)
		"lose_population":
			for b in c.houses():
				b.pop -= int(b.pop * float(e["fraction"]))
			c.recount_population()
		"destroy_random":
			var cands := []
			for b in c.buildings.values():
				if b.kind() != "monument":
					cands.append(b.id)
			for i in mini(int(e["count"]), cands.size()):
				var k: int = c.rng.randi() % cands.size()
				Construction.remove_building(c, cands[k])
				cands.remove_at(k)
	c.log_event(e["text"], tone)
