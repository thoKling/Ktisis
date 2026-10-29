extends RefCounted
## Incendies : chaque bâtiment à risque s'échauffe chaque mois ; le vigile remet le risque à zéro.

const Rules = preload("res://src/domain/rules.gd")
const Construction = preload("res://src/domain/systems/construction.gd")


static func monthly(c) -> void:
	for b in c.buildings.values():
		var r: int = b.def["risk"]
		if r <= 0:
			continue
		b.risk += r
		if b.risk >= Rules.RISK_LIMIT:
			c.log_event("Incendie : %s a brûlé. Construisez des postes de vigie." % b.def["name"], "bad")
			Construction.remove_building(c, b.id)
