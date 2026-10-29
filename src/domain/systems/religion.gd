extends RefCounted
## Dieux : faveur, fêtes, bénédictions, colères, et choix du dieu protecteur de la cité.

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
			if god == rival(c):
				delta -= float(c.mission["patron_choice"].get("rival_jealousy", 0.0))
			if Monuments.sanctuary_complete(c, god):
				delta += 2.0
			var before: float = c.favor[god]
			c.favor[god] = clampf(before + delta, 0.0, 100.0)
			if before > Rules.UNHAPPY_FAVOR and c.favor[god] <= Rules.UNHAPPY_FAVOR:
				c.log_event("%s est %s de vous : bâtissez-lui des autels ou offrez-lui une fête." % [
					c.catalog.god_name(god), c.catalog.agree(god, "mécontent", "mécontente")], "warn")
		var gd: Dictionary = c.catalog.gods[god]
		if c.favor[god] >= Rules.BLESSING_FAVOR and cd["blessing"] == 0 and c.rng.randf() < 0.25:
			cd["blessing"] = 12
			apply(c, gd["blessing"], god, "good")
		elif c.favor[god] <= Rules.WRATH_FAVOR and cd["wrath"] == 0 and not inhabited.is_empty() and c.rng.randf() < 0.25:
			cd["wrath"] = 8
			apply(c, gd["wrath"], god, "bad")


# ---------------------------------------------------------------- Choix du protecteur

## Les options de la mission : [{"god", "gift", "pitch", "effects"}], vide si la mission n'en propose pas.
static func patron_options(c) -> Array:
	return c.mission.get("patron_choice", {}).get("options", [])


static func patron_option(c, god: String) -> Dictionary:
	for o in patron_options(c):
		if o["god"] == god:
			return o
	return {}


## Le dieu éconduit : jaloux, sa faveur baisse chaque mois s'il n'est pas honoré.
static func rival(c) -> String:
	if c.patron == "" or patron_options(c).is_empty():
		return ""
	for o in patron_options(c):
		if o["god"] != c.patron:
			return o["god"]
	return ""


## Le joueur choisit le protecteur : son présent apparaît sur la colline, ses dons durent toujours,
## son temple devient constructible ; l'autre dieu se sent offensé.
static func choose_patron(c, god: String) -> String:
	var opt := patron_option(c, god)
	if opt.is_empty():
		return "Ce dieu ne prétend pas à la cité"
	if c.patron != "":
		return "La cité a déjà choisi son protecteur"
	var choice: Dictionary = c.mission["patron_choice"]
	c.patron = god
	c.favor[god] = maxf(c.favor[god], float(choice.get("patron_favor", c.favor[god])))
	c.log_event("Le peuple choisit %s pour protecteur de la cité !" % c.catalog.god_name(god), "good")
	if opt.has("gift") and choice.has("gift_at"):
		var at := Vector2i(int(choice["gift_at"][0]), int(choice["gift_at"][1]))
		Construction.add_building(c, opt["gift"], at)
	for e in opt.get("effects", []):
		apply(c, e, god, "good")
	var other := rival(c)
	if other != "":
		c.favor[other] = minf(c.favor[other], float(choice.get("rival_favor", c.favor[other])))
		c.log_event("%s se sent %s : %s pour apaiser sa jalousie." % [c.catalog.god_name(other),
			c.catalog.agree(other, "offensé", "offensée"), c.catalog.agree(other, "honorez-le", "honorez-la")], "warn")
	return ""


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
	c.log_event("Fête en l'honneur %s : sa faveur grandit." % c.catalog.god_of(god), "good")
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
				if b.kind() != "monument" and not b.def.get("sacred", false):
					cands.append(b.id)
			for i in mini(int(e["count"]), cands.size()):
				var k: int = c.rng.randi() % cands.size()
				Construction.remove_building(c, cands[k])
				cands.remove_at(k)
	c.log_event(e["text"], tone)
