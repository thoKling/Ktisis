extends RefCounted
## Main-d'œuvre : une part des habitants travaille, répartie par priorité de catégorie puis par ordre de construction.
## Un bâtiment sans route ne reçoit personne.

const Rules = preload("res://src/domain/rules.gd")
const Access = preload("res://src/domain/systems/access.gd")


static func allocate(c) -> void:
	c.recount_population()
	c.workers_available = int(c.population * Rules.WORKER_RATIO)
	var order := []
	for b in c.buildings.values():
		if int(b.def["workers"]) > 0:
			order.append(b)
	order.sort_custom(func(a, d):
		var pa := Rules.WORK_PRIORITY.find(a.def["category"])
		var pd := Rules.WORK_PRIORITY.find(d.def["category"])
		if pa != pd:
			return pa < pd
		return a.id < d.id)
	var left: int = c.workers_available
	c.workers_needed = 0
	for b in order:
		var need: int = b.def["workers"]
		if b.complete and not b.def.has("service"):
			b.workers = 0
			b.efficiency = 0.0
			continue
		c.workers_needed += need
		if not Access.has_road(c, b):
			b.workers = 0
			b.efficiency = 0.0
			continue
		var give := mini(need, left)
		left -= give
		b.workers = give
		b.efficiency = give / float(need)


## Prévient le joueur, au plus une fois par semestre, quand il manque des bras.
static func warn_shortage(c) -> void:
	if c.workers_needed > c.workers_available and c.months - c.labor_warned_month >= 6:
		c.labor_warned_month = c.months
		c.log_event("Il manque %d travailleurs : certains bâtiments tournent au ralenti." % (c.workers_needed - c.workers_available), "warn")
