extends RefCounted
## Habitat : besoins des maisons, montée et descente de niveau, consommation, impôt dû et arrivée des colons.

const Rules = preload("res://src/domain/rules.gd")
const Access = preload("res://src/domain/systems/access.gd")
const Effects = preload("res://src/domain/systems/effects.gd")
const Beauty = preload("res://src/domain/systems/beauty.gd")


static func levels(c) -> Array:
	return c.catalog.house_levels()


static func cap(c, b) -> int:
	return levels(c)[b.level]["cap"]


static func food_consumption(b) -> int:
	return ceili(b.pop / Rules.PEOPLE_PER_FOOD)


## Réserve de nourriture que la marchande cherche à remplir.
static func food_target(b) -> int:
	return maxi(2, food_consumption(b) * Rules.HOUSE_FOOD_MONTHS)


static func need_met(c, b, need: String, value = null) -> bool:
	match need:
		"food":
			return b.get_stock("food") > 0
		"water":
			return b.water_until > c.tick
		"religion":
			for g in b.religion:
				if b.religion[g] > c.tick:
					return true
			return false
		"beauty":
			return Beauty.of_building(c, b) >= float(value)
		"oil":
			return b.get_stock("oil") > 0
		"wool":
			return b.get_stock("wool") > 0
		"sanctuary":
			return b.sanctuary_until > c.tick
	return false


## Besoins du niveau suivant qui ne sont pas couverts : [[besoin, valeur], ...].
static func missing_for_next(c, b) -> Array:
	var lv := levels(c)
	if b.level + 1 >= lv.size():
		return []
	var res := []
	var needs: Dictionary = lv[b.level + 1]["needs"]
	for need in needs:
		if not need_met(c, b, need, needs[need]):
			res.append([need, needs[need]])
	return res


## Niveau le plus haut dont tous les besoins (cumulés) sont couverts.
static func target_level(c, b) -> int:
	var lv := levels(c)
	var best := 0
	for i in range(1, lv.size()):
		for need in lv[i]["needs"]:
			if not need_met(c, b, need, lv[i]["needs"][need]):
				return best
		best = i
	return best


## Fin de mois : on mange, on monte ou on descend d'un niveau, l'impôt s'accumule.
static func monthly(c) -> void:
	var lv := levels(c)
	for b in c.houses():
		if b.pop <= 0:
			continue
		b.add_stock("food", -mini(food_consumption(b), b.get_stock("food")))
		if b.level >= 4:
			for res in ["oil", "wool"]:
				b.add_stock(res, -mini(1, b.get_stock(res)))
		var target := target_level(c, b)
		if target > b.level:
			b.level += 1
			b.fail_months = 0
		elif target < b.level:
			b.fail_months += 1
			if b.fail_months >= Rules.HOUSE_DOWNGRADE_MONTHS:
				b.level -= 1
				b.fail_months = 0
		else:
			b.fail_months = 0
		b.pop = mini(b.pop, lv[b.level]["cap"])
		b.tax_due += b.pop * float(lv[b.level]["tax"])
	c.recount_population()


static func hungry_fraction(c) -> float:
	var n := 0
	var hungry := 0
	for b in c.houses():
		if b.pop > 0:
			n += 1
			if b.get_stock("food") <= 0:
				hungry += 1
	return hungry / float(n) if n > 0 else 0.0


## Envoie régulièrement un groupe de colons depuis l'entrée vers la maison libre la plus proche.
static func immigration(c) -> void:
	var period := maxi(1, int(Rules.IMMIGRATION_PERIOD / Effects.immigration_mult(c)))
	if c.tick % period != 0:
		return
	if not c.grid.is_road(c.entry):
		if c.months - c.entry_warned_month >= 6:
			c.entry_warned_month = c.months
			c.log_event("Les colons ne trouvent pas de route depuis l'entrée de la carte.", "warn")
		return
	if c.months >= 3 and hungry_fraction(c) > 0.5 and c.rng.randf() < 0.6:
		return
	var goals := {}
	for b in c.houses():
		if cap(c, b) - b.pop - b.incoming_pop <= 0:
			continue
		for t in Access.tiles(c, b, Rules.HOUSE_ROAD_RADIUS):
			if not goals.has(t):
				goals[t] = b.id
	if goals.is_empty():
		return
	var path: Array = c.grid.find_path([c.entry], goals, true)
	if path.is_empty():
		return
	var h = c.buildings[goals[path[path.size() - 1]]]
	var g := mini(Rules.IMMIGRANT_GROUP, cap(c, h) - h.pop - h.incoming_pop)
	var w = c.spawn_walker("immigrant", -1, path[0])
	path.pop_front()
	w.path = path
	w.target = h.id
	w.group = g
	h.incoming_pop += g


static func step_immigrant(c, w) -> void:
	if not w.follow_path():
		return
	c.walkers.erase(w.id)
	var h = c.buildings.get(w.target)
	if h == null:
		return
	h.incoming_pop = maxi(0, h.incoming_pop - w.group)
	h.pop += clampi(w.group, 0, maxi(cap(c, h) - h.pop, 0))
