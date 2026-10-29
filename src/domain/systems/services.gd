extends RefCounted
## Marcheurs de service : ils partent de leur bâtiment, errent dans les rues en préférant celles
## qu'ils ont peu parcourues, servent les bâtiments qu'ils longent, puis rentrent.
## Les barrages routiers les arrêtent.

const Grid = preload("res://src/domain/world/grid.gd")
const Rules = preload("res://src/domain/rules.gd")
const Access = preload("res://src/domain/systems/access.gd")
const Effects = preload("res://src/domain/systems/effects.gd")
const Housing = preload("res://src/domain/systems/housing.gd")


static func try_spawn(c, b, service: String, god: String) -> void:
	if b.walker_id != -1:
		return
	if b.cooldown > 0:
		b.cooldown -= 1
		return
	if b.efficiency <= 0.0:
		return
	var acc := Access.tiles(c, b, 1)
	if acc.is_empty():
		return
	var start: Vector2i = acc[c.rng.randi() % acc.size()]
	var w = c.spawn_walker("service", b.id, start)
	w.service = service
	w.god = god
	w.steps_left = int(b.def.get("range", 20) * Effects.service_range_mult(c, service))
	w.visited[start] = 1
	b.walker_id = w.id
	_apply(c, w)


static func step(c, w) -> void:
	if w.returning:
		if w.follow_path():
			_finish(c, w)
		return
	var opts := []
	for dir in Grid.DIRS:
		var q: Vector2i = w.pos + dir
		if c.grid.road_at(q) == Grid.R_ROAD and q != w.prev:
			opts.append(q)
	var nxt: Vector2i = w.pos
	if opts.is_empty():
		if w.prev == w.pos:
			_start_return(c, w)
			return
		nxt = w.prev  # cul-de-sac : demi-tour
	else:
		var best := 1 << 30
		var cands := []
		for q in opts:
			var v: int = w.visited.get(q, 0)
			if v < best:
				best = v
				cands = [q]
			elif v == best:
				cands.append(q)
		nxt = cands[c.rng.randi() % cands.size()]
	w.prev = w.pos
	w.pos = nxt
	w.visited[nxt] = int(w.visited.get(nxt, 0)) + 1
	w.steps_left -= 1
	_apply(c, w)
	if w.steps_left <= 0:
		_start_return(c, w)


static func _start_return(c, w) -> void:
	var home = c.buildings.get(w.home)
	if home == null:
		c.walkers.erase(w.id)
		return
	var goals := {}
	for t in Access.tiles(c, home, 1):
		goals[t] = true
	var path: Array = c.grid.find_path([w.pos], goals, false)
	if path.is_empty():
		path = c.grid.find_path([w.pos], goals, true)
	if path.size() <= 1:
		_finish(c, w)
		return
	path.pop_front()
	w.path = path
	w.returning = true


static func _finish(c, w) -> void:
	c.walkers.erase(w.id)
	var home = c.buildings.get(w.home)
	if home != null and home.walker_id == w.id:
		home.walker_id = -1
		home.cooldown = Rules.SERVICE_COOLDOWN


static func _apply(c, w) -> void:
	var home = c.buildings.get(w.home)
	if home == null:
		return
	var seen := {}
	for dy in range(-Rules.SERVICE_RADIUS, Rules.SERVICE_RADIUS + 1):
		for dx in range(-Rules.SERVICE_RADIUS, Rules.SERVICE_RADIUS + 1):
			var bid: int = c.grid.occupant(w.pos + Vector2i(dx, dy))
			if bid == -1 or seen.has(bid):
				continue
			seen[bid] = true
			_serve(c, w, home, c.buildings[bid])


static func _serve(c, w, home, b) -> void:
	if w.service == "guard":
		b.risk = 0.0
		return
	if b.kind() != "house":
		return
	var until: int = c.tick + Rules.SERVICE_TICKS
	match w.service:
		"water":
			b.water_until = until
		"priest":
			b.religion[w.god] = until
		"sanctuary":
			b.religion[w.god] = until
			b.sanctuary_until = until
		"tax":
			var due := int(b.tax_due)
			if due > 0:
				c.money += due
				b.tax_due -= due
		"market":
			if b.pop > 0:
				_sell(home, b)


## La marchande remplit la réserve de nourriture, puis l'huile et la laine des maisons de notable et plus.
static func _sell(agora, house) -> void:
	var need: int = Housing.food_target(house) - house.get_stock("food")
	for res in ["wheat", "fish"]:
		if need <= 0:
			break
		var give := mini(need, agora.get_stock(res))
		if give > 0:
			agora.add_stock(res, -give)
			house.add_stock("food", give)
			need -= give
	if house.level >= 3:
		for res in ["oil", "wool"]:
			var give := mini(Rules.HOUSE_GOODS_STOCK - house.get_stock(res), agora.get_stock(res))
			if give > 0:
				agora.add_stock(res, -give)
				house.add_stock(res, give)
