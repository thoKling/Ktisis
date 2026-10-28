extends RefCounted
## Textes affichés pour la cité : date, fiche d'un bâtiment, nom des besoins.

const NEED_NAMES := {
	"food": "nourriture", "water": "eau", "religion": "culte", "oil": "huile",
	"wool": "laine", "sanctuary": "sanctuaire",
}


static func date_text(c) -> String:
	return "An %d, mois %d" % [c.months / 12 + 1, c.months % 12 + 1]


static func need_name(need: String, value) -> String:
	if need == "beauty":
		return "beauté %d" % int(value)
	return NEED_NAMES.get(need, need)


## Lignes de la fiche d'un bâtiment ; la première sert de titre.
static func lines(c, b) -> Array:
	var d: Dictionary = b.def
	var res := []
	if b.kind() == "house":
		_house_lines(c, b, res)
	else:
		res.append(d["name"])
		if int(d["workers"]) > 0:
			res.append("Employés : %d / %d" % [b.workers, d["workers"]])
			if not c.has_road_access(b):
				res.append("Ne touche aucune route : inactif.")
		if d["kind"] in ["producer", "processor"]:
			res.append("Production : %d %%" % int(100.0 * b.progress / float(d["cycle"])))
		if b.kind() == "monument" and not b.complete:
			var st: Dictionary = d["stages"][b.stage]
			res.append("Étape %d sur %d" % [b.stage + 1, d["stages"].size()])
			for r in st:
				res.append("  %s : %d / %d" % [c.catalog.resource_name(r), b.get_stock(r), st[r]])
			res.append("Travaux : %d %%" % int(100.0 * b.progress / float(d["stage_ticks"])))
		elif b.kind() == "monument":
			res.append("Achevé")
		if b.total_stock() > 0 and b.kind() != "monument":
			var parts := []
			for r in b.stock:
				parts.append("%s %d" % [c.catalog.resource_name(r), b.stock[r]])
			res.append("Stock : " + ", ".join(parts))
		if b.kind() == "storage":
			res.append("Capacité : %d / %d" % [b.total_stock(), d["capacity"]])
	if int(d["risk"]) > 0:
		res.append("Risque d'incendie : %d %%" % int(b.risk))
	return res


static func _house_lines(c, b, res: Array) -> void:
	var levels: Array = c.catalog.house_levels()
	res.append("%s (niveau %d)" % [levels[b.level]["name"], b.level + 1])
	res.append("Habitants : %d / %d" % [b.pop, c.house_cap(b)])
	if not c.has_road_access(b):
		res.append("Aucune route à moins de 2 cases : personne ne viendra.")
	res.append("Nourriture : %d" % b.get_stock("food"))
	res.append("Eau : %s" % _yes(c.house_need_met(b, "water")))
	res.append("Culte : %s" % _yes(c.house_need_met(b, "religion")))
	res.append("Beauté : %d" % int(c.house_beauty(b)))
	if b.level >= 3:
		res.append("Huile : %d, laine : %d" % [b.get_stock("oil"), b.get_stock("wool")])
		res.append("Accès au sanctuaire : %s" % _yes(c.house_need_met(b, "sanctuary")))
	if b.level + 1 >= levels.size():
		return
	var next: String = levels[b.level + 1]["name"]
	var missing := []
	for m in c.house_missing_for_next(b):
		missing.append(need_name(m[0], m[1]))
	if missing.is_empty():
		res.append("Montera bientôt : %s" % next)
	else:
		res.append("Pour devenir %s : %s" % [next, ", ".join(missing)])


static func _yes(v: bool) -> String:
	return "oui" if v else "non"
