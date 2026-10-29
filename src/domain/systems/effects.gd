extends RefCounted
## Effets temporaires ou permanents des dieux (bénédictions, colères, présent du patron).


static func add(c, e: Dictionary, god: String) -> void:
	var eff := e.duplicate()
	eff["god"] = god
	eff["months_left"] = int(e.get("months", 6))
	c.effects.append(eff)


## Fin de mois : les effets temporaires s'usent (months_left = -1 : permanent).
static func monthly(c) -> void:
	var keep := []
	for e in c.effects:
		if e["months_left"] > 0:
			e["months_left"] -= 1
			if e["months_left"] == 0:
				continue
		keep.append(e)
	c.effects = keep


static func production_mult(c, res: String) -> float:
	var m := 1.0
	for e in c.effects:
		if e["type"] == "production_mult" and res in e["resources"]:
			m *= float(e["mult"])
	return m


static func immigration_mult(c) -> float:
	var m := 1.0
	for e in c.effects:
		if e["type"] == "immigration_mult":
			m *= float(e["mult"])
	return m


static func service_range_mult(c, service: String) -> float:
	var m := 1.0
	for e in c.effects:
		if e["type"] == "service_range_mult" and e["service"] == service:
			m *= float(e["mult"])
	return m
