extends RefCounted
## Objectifs de mission : état de chacun et victoire quand tout est rempli.
## Une mission peut se jouer en étapes (« stages ») : chacune a son récit et ses objectifs,
## la suivante commence quand tout est rempli, et la dernière achevée donne la victoire.

const Housing = preload("res://src/domain/systems/housing.gd")
const Monuments = preload("res://src/domain/systems/monuments.gd")


## Les étapes de la mission : [{"title", "text", "objectives"}], vide pour une mission d'un seul tenant.
static func stages(c) -> Array:
	return c.mission.get("stages", [])


## Les objectifs à remplir maintenant : ceux de l'étape en cours, ou ceux de la mission.
static func current(c) -> Array:
	var st := stages(c)
	if st.is_empty():
		return c.mission.get("objectives", [])
	return st[mini(c.stage, st.size() - 1)]["objectives"]


## [{"text", "done"}] dans l'ordre de la mission (ou de l'étape en cours).
static func evaluate(c) -> Array:
	var res := []
	var levels := Housing.levels(c)
	for o in current(c):
		var text := ""
		var done := false
		match o["type"]:
			"population":
				done = c.population >= int(o["value"])
				text = "Population : %d / %d" % [c.population, int(o["value"])]
			"houses_level":
				var n := 0
				for b in c.houses():
					if b.level >= int(o["level"]):
						n += 1
				done = n >= int(o["count"])
				text = "%s ou mieux : %d / %d" % [levels[int(o["level"])]["name"], n, int(o["count"])]
			"monument":
				done = Monuments.is_complete(c, o["building"])
				text = "Achever : %s" % c.catalog.building(o["building"])["name"]
			"patron_monument":
				# Le temple du protecteur choisi : ce bâtiment de la mission réservé au patron.
				var type := _patron_monument(c)
				done = type != "" and Monuments.is_complete(c, type)
				if type == "":
					text = "Achever le temple du dieu protecteur"
				else:
					text = "Achever : %s" % c.catalog.building(type)["name"]
			"rival_favor":
				var r: String = c.rival()
				var f: float = c.favor.get(r, 0.0)
				done = r != "" and f >= float(o["value"])
				if r == "":
					text = "Apaiser le dieu éconduit (faveur %d)" % int(o["value"])
				else:
					text = "Apaiser %s : faveur %d / %d" % [c.catalog.god_name(r), int(f), int(o["value"])]
			"patron":
				done = c.patron != ""
				if done:
					text = "Patron de la cité : %s" % c.catalog.god_name(c.patron)
				else:
					text = "Choisir le dieu protecteur de la cité"
			"favor":
				var f: float = c.favor.get(o["god"], 0.0)
				done = f >= float(o["value"])
				text = "Faveur %s : %d / %d" % [c.catalog.god_of(o["god"]), int(f), int(o["value"])]
			"money":
				done = c.money >= int(o["value"])
				text = "Trésor : %d / %d" % [c.money, int(o["value"])]
		res.append({"text": text, "done": done})
	return res


static func _patron_monument(c) -> String:
	if c.patron == "":
		return ""
	for id in c.mission.get("buildings", []):
		var d: Dictionary = c.catalog.building(id)
		if d.get("kind", "") == "monument" and d.get("patron", "") == c.patron:
			return id
	return ""


static func check(c) -> void:
	if c.won:
		return
	for o in evaluate(c):
		if not o["done"]:
			return
	var st := stages(c)
	if c.stage + 1 < st.size():
		c.stage += 1
		c.log_event("Nouvelle étape : %s" % st[c.stage]["title"], "good")
		# Une étape peut être déjà remplie en arrivant (la cité a pris de l'avance).
		check(c)
		return
	c.won = true
	c.log_event("Tous les objectifs sont remplis !", "good")
