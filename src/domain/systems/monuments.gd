extends RefCounted
## Monuments bâtis par étapes : chaque étape attend ses matériaux, puis des mois de travaux.
## Un sanctuaire achevé envoie son prêtre.

const Rules = preload("res://src/domain/rules.gd")
const Logistics = preload("res://src/domain/systems/logistics.gd")
const Services = preload("res://src/domain/systems/services.gd")


static func update(c, b) -> void:
	var d: Dictionary = b.def
	if b.complete:
		if d.has("service"):
			Services.try_spawn(c, b, d["service"], d.get("god", ""))
		return
	var st: Dictionary = d["stages"][b.stage]
	var missing := false
	for res in st:
		var have: int = b.get_stock(res)
		if have >= st[res]:
			continue
		missing = true
		var with_incoming: int = have + int(b.incoming.get(res, 0))
		if with_incoming < st[res] and b.efficiency > 0.0 and Logistics.is_logistics_tick(c, b):
			Logistics.request_supply(c, b, res, mini(Rules.CART_LOAD * 2, st[res] - with_incoming))
	if missing or b.efficiency <= 0.0:
		return
	b.progress += b.efficiency
	if b.progress < d["stage_ticks"]:
		return
	b.progress = 0.0
	for res in st:
		b.add_stock(res, -st[res])
	b.stage += 1
	if b.stage >= d["stages"].size():
		b.complete = true
		c.log_event("%s est achevé !" % d["name"], "good")
	else:
		c.log_event("%s : étape %d sur %d achevée." % [d["name"], b.stage, d["stages"].size()], "good")


static func is_complete(c, type: String) -> bool:
	for b in c.buildings.values():
		if b.type == type and b.complete:
			return true
	return false


static func sanctuary_complete(c, god: String) -> bool:
	for b in c.buildings.values():
		if b.kind() == "monument" and b.complete and b.def.get("god", "") == god:
			return true
	return false
