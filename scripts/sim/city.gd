extends RefCounted
## Simulation d'une cité, indépendante de l'affichage.
## Avance par pas fixes (step) : on peut accélérer le temps ou la tester sans écran.

const Defs = preload("res://scripts/sim/defs.gd")
const Building = preload("res://scripts/sim/building.gd")
const Walker = preload("res://scripts/sim/walker.gd")
const MapGen = preload("res://scripts/sim/map_gen.gd")

const TICKS_PER_MONTH := 200
const WALKER_STEP_TICKS := 4
const SERVICE_TICKS := 1000
const SERVICE_RADIUS := 2
const HOUSE_ROAD_RADIUS := 2
const CART_LOAD := 10
const PRODUCER_MAX_STOCK := 30
const WORKER_RATIO := 0.5
const IMMIGRATION_PERIOD := 12
const IMMIGRANT_GROUP := 4
const HOUSE_FOOD_MONTHS := 4
const HOUSE_GOODS_STOCK := 2
const FESTIVAL_COST := 150
const FESTIVAL_FAVOR := 12.0
const FESTIVAL_COOLDOWN := 4
const START_FAVOR := 40.0
const RISK_LIMIT := 100.0
const LOGISTICS_PERIOD := 10

const R_NONE := 0
const R_ROAD := 1
const R_BLOCK := 2

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const WORK_PRIORITY := ["alimentation", "stockage", "services", "religion", "industrie", "monuments"]

var defs
var mission := {}
var width := 0
var height := 0
var terrain := PackedByteArray()
var roads := PackedByteArray()
var occ := PackedInt32Array()
var beauty := PackedFloat32Array()
var beauty_dirty := true
var buildings := {}
var next_id := 1
var walkers := {}
var next_walker_id := 1
var money := 0
var tick := 0
var months := 0
var entry := Vector2i.ZERO
var favor := {}
var god_cd := {}
var effects := []
var patron := ""
var events := []
var won := false
var population := 0
var workers_available := 0
var workers_needed := 0
var roads_version := 0
var map_version := 0
var rng := RandomNumberGenerator.new()
var _access_cache := {}
var _no_entry_warned_month := -100
var _labor_warned_month := -100


func _init(mission_def: Dictionary = {}) -> void:
	defs = Defs.get_defs()
	if not mission_def.is_empty():
		setup(mission_def)


func setup(m: Dictionary) -> void:
	mission = m
	var g := MapGen.generate(m["map"])
	width = g["width"]
	height = g["height"]
	terrain = g["terrain"]
	entry = g["entry"]
	roads.resize(width * height)
	roads.fill(R_NONE)
	occ.resize(width * height)
	occ.fill(-1)
	beauty.resize(width * height)
	beauty.fill(0.0)
	money = int(m.get("start_money", 2000))
	rng.seed = int(m["map"].get("seed", 1)) * 31 + 7
	for god in m.get("gods", []):
		favor[god] = START_FAVOR
		god_cd[god] = {"festival": 0, "blessing": 0, "wrath": 0}
	for x in range(0, 4):
		roads[idx(Vector2i(x, entry.y))] = R_ROAD
	roads_version += 1


# ---------------------------------------------------------------- Grille

func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func terrain_at(p: Vector2i) -> int:
	return terrain[idx(p)] if in_bounds(p) else Defs.T_WATER


func is_road(p: Vector2i) -> bool:
	return in_bounds(p) and roads[idx(p)] != R_NONE


func road_at(p: Vector2i) -> int:
	return roads[idx(p)] if in_bounds(p) else R_NONE


func building_at(p: Vector2i):
	if not in_bounds(p):
		return null
	var bid := occ[idx(p)]
	return buildings.get(bid) if bid != -1 else null


## Masque des voisins routiers (1 = est, 2 = ouest, 4 = sud, 8 = nord) : la forme de la route en découle.
func road_mask(p: Vector2i) -> int:
	var m := 0
	for i in DIRS.size():
		if is_road(p + DIRS[i]):
			m |= 1 << i
	return m


func is_available(type: String) -> bool:
	return type in mission.get("buildings", [])


# ---------------------------------------------------------------- Construction

func can_place(type: String, p: Vector2i) -> String:
	var d: Dictionary = defs.building(type)
	if d.is_empty():
		return "Bâtiment inconnu"
	if not is_available(type):
		return "Non disponible dans cette mission"
	if money < int(d["cost"]):
		return "Pas assez de drachmes"
	if d.has("cost_res"):
		for r in d["cost_res"]:
			if stored_total(r) < d["cost_res"][r]:
				return "Il faut %d %s en entrepôt" % [d["cost_res"][r], defs.resource_name(r)]
	var kind: String = d["kind"]
	if kind == "roadblock":
		if road_at(p) != R_ROAD:
			return "Un barrage se pose sur une route"
		return ""
	var s: int = d["size"]
	var meadow := 0
	for y in s:
		for x in s:
			var q := p + Vector2i(x, y)
			if not in_bounds(q):
				return "Hors de la carte"
			var t := terrain[idx(q)]
			if t != Defs.T_GRASS and t != Defs.T_MEADOW:
				return "Terrain impraticable"
			if occ[idx(q)] != -1:
				return "Emplacement occupé"
			if roads[idx(q)] != R_NONE:
				return "Une route passe ici"
			if t == Defs.T_MEADOW:
				meadow += 1
	if d.get("on", "") == "meadow" and meadow * 2 < s * s:
		return "Il faut une prairie fertile"
	if d.get("coast", false) and not _touches_terrain(p, s, Defs.T_WATER, 1):
		return "Doit toucher l'eau"
	if d.has("near"):
		var t_near: int = Defs.TERRAIN_NAMES[d["near"]]
		if not _touches_terrain(p, s, t_near, int(d.get("near_radius", 2))):
			return "Doit être près d'une forêt" if d["near"] == "forest" else "Doit être près d'un rocher"
	return ""


func _touches_terrain(p: Vector2i, s: int, t: int, r: int) -> bool:
	for y in range(p.y - r, p.y + s + r):
		for x in range(p.x - r, p.x + s + r):
			var q := Vector2i(x, y)
			if in_bounds(q) and terrain[idx(q)] == t:
				return true
	return false


func place(type: String, p: Vector2i) -> String:
	var err := can_place(type, p)
	if err != "":
		return err
	var d: Dictionary = defs.building(type)
	money -= int(d["cost"])
	if d.has("cost_res"):
		for r in d["cost_res"]:
			take_from_storage(r, d["cost_res"][r])
	match d["kind"]:
		"road":
			roads[idx(p)] = R_ROAD
			_roads_changed()
		"roadblock":
			roads[idx(p)] = R_BLOCK
			_roads_changed()
		_:
			_add_building(type, p)
			_allocate_workers()
	return ""


## Trace une route le long d'un chemin ; renvoie le nombre de cases posées.
func place_road_path(tiles: Array) -> int:
	var n := 0
	for q in tiles:
		if road_at(q) == R_NONE and place("road", q) == "":
			n += 1
	return n


## Chemin en L entre deux cases, pour tracer les routes au glisser.
static func l_path(a: Vector2i, b: Vector2i) -> Array:
	var res := []
	var sx := 1 if b.x >= a.x else -1
	var sy := 1 if b.y >= a.y else -1
	var x := a.x
	while true:
		res.append(Vector2i(x, a.y))
		if x == b.x:
			break
		x += sx
	var y := a.y
	while y != b.y:
		y += sy
		res.append(Vector2i(b.x, y))
	return res


func _add_building(type: String, p: Vector2i):
	var d: Dictionary = defs.building(type)
	var b := Building.new()
	b.id = next_id
	next_id += 1
	b.type = type
	b.pos = p
	b.size = int(d["size"])
	b.def = d
	buildings[b.id] = b
	for y in b.size:
		for x in b.size:
			occ[idx(p + Vector2i(x, y))] = b.id
	beauty_dirty = true
	map_version += 1
	return b


func demolish(p: Vector2i) -> bool:
	if not in_bounds(p):
		return false
	var bid := occ[idx(p)]
	if bid != -1:
		remove_building(bid)
		return true
	if roads[idx(p)] != R_NONE:
		roads[idx(p)] = R_NONE
		_roads_changed()
		return true
	return false


func remove_building(bid: int) -> void:
	var b = buildings.get(bid)
	if b == null:
		return
	for y in b.size:
		for x in b.size:
			occ[idx(b.pos + Vector2i(x, y))] = -1
	buildings.erase(bid)
	for wid in walkers.keys():
		var w = walkers[wid]
		if w.kind == "service" and w.home == bid:
			walkers.erase(wid)
	beauty_dirty = true
	map_version += 1
	_allocate_workers()


func _roads_changed() -> void:
	roads_version += 1
	map_version += 1


# ---------------------------------------------------------------- Accès et chemins

## Cases de route autour d'un bâtiment, à distance radius (1 = cases qui le touchent).
func access_tiles(b, radius: int = 1) -> Array:
	var key: int = b.id * 8 + radius
	var c = _access_cache.get(key)
	if c != null and c[0] == roads_version:
		return c[1]
	var res := []
	if radius == 1:
		for i in b.size:
			for q in [b.pos + Vector2i(i, -1), b.pos + Vector2i(i, b.size), b.pos + Vector2i(-1, i), b.pos + Vector2i(b.size, i)]:
				if is_road(q):
					res.append(q)
	else:
		for y in range(b.pos.y - radius, b.pos.y + b.size + radius):
			for x in range(b.pos.x - radius, b.pos.x + b.size + radius):
				var q := Vector2i(x, y)
				if is_road(q):
					res.append(q)
	_access_cache[key] = [roads_version, res]
	return res


## Parcours en largeur sur les routes. goals : case -> valeur. Renvoie le chemin (départ et arrivée compris) ou [].
func find_path(starts: Array, goals: Dictionary, allow_block: bool) -> Array:
	if starts.is_empty() or goals.is_empty():
		return []
	var parent := PackedInt32Array()
	parent.resize(width * height)
	parent.fill(-2)
	var queue := PackedInt32Array()
	for s in starts:
		var si := idx(s)
		if parent[si] == -2:
			parent[si] = -1
			queue.append(si)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var p := Vector2i(i % width, i / width)
		if goals.has(p):
			return _rebuild_path(parent, i)
		for dir in DIRS:
			var q: Vector2i = p + dir
			if not in_bounds(q):
				continue
			var j := idx(q)
			if parent[j] != -2:
				continue
			var r := roads[j]
			if r == R_NONE or (r == R_BLOCK and not allow_block):
				continue
			parent[j] = i
			queue.append(j)
	return []


func _rebuild_path(parent: PackedInt32Array, i: int) -> Array:
	var path := []
	while i != -1:
		path.append(Vector2i(i % width, i / width))
		i = parent[i]
	path.reverse()
	return path


## Le bâtiment de candidates le plus proche par la route. Renvoie {"b", "path"} ou {}.
func nearest_by_road(from_b, candidates: Array) -> Dictionary:
	var goals := {}
	for c in candidates:
		for t in access_tiles(c, 1):
			if not goals.has(t):
				goals[t] = c.id
	var path := find_path(access_tiles(from_b, 1), goals, true)
	if path.is_empty():
		return {}
	return {"b": buildings[goals[path[path.size() - 1]]], "path": path}


# ---------------------------------------------------------------- Stockage

func storages() -> Array:
	var res := []
	for b in buildings.values():
		if b.kind() == "storage":
			res.append(b)
	return res


func storage_space(s, res: String) -> int:
	if not res in s.def.get("accepts", []):
		return 0
	return int(s.def["capacity"]) - s.total_stock() - s.total_incoming()


func stored_total(res: String) -> int:
	var t := 0
	for s in storages():
		t += s.get_stock(res)
	return t


func take_from_storage(res: String, n: int) -> void:
	for s in storages():
		var take := mini(n, s.get_stock(res))
		s.add_stock(res, -take)
		n -= take
		if n <= 0:
			return


# ---------------------------------------------------------------- Boucle

func step() -> void:
	tick += 1
	if beauty_dirty:
		_compute_beauty()
	if tick % 20 == 0:
		_allocate_workers()
	for b in buildings.values():
		_update_building(b)
	_update_walkers()
	_immigration()
	if tick % TICKS_PER_MONTH == 0:
		_monthly()


func run_months(n: int) -> void:
	for i in n * TICKS_PER_MONTH:
		step()


func _throttle(b) -> bool:
	return (tick + b.id) % LOGISTICS_PERIOD == 0


func _update_building(b) -> void:
	var d: Dictionary = b.def
	match d["kind"]:
		"producer":
			_update_producer(b)
		"processor":
			_update_processor(b)
		"service":
			if d["service"] == "market":
				_update_agora(b)
			else:
				_try_spawn_service(b, d["service"], d.get("god", ""))
		"monument":
			_update_monument(b)


func _update_producer(b) -> void:
	var d: Dictionary = b.def
	var res: String = d["produces"]
	if b.efficiency > 0.0 and b.get_stock(res) < PRODUCER_MAX_STOCK:
		b.progress += b.efficiency * production_mult(res)
		if b.progress >= d["cycle"]:
			b.progress -= d["cycle"]
			b.add_stock(res, d["amount"])
	if b.get_stock(res) >= mini(CART_LOAD, d["amount"]) and _throttle(b):
		_dispatch_output(b, res)


func _update_processor(b) -> void:
	var d: Dictionary = b.def
	var inp: String = d["input"]
	var out: String = d["produces"]
	var need: int = d["input_amount"]
	if b.efficiency > 0.0 and b.get_stock(inp) >= need and b.get_stock(out) < PRODUCER_MAX_STOCK:
		b.progress += b.efficiency * production_mult(out)
		if b.progress >= d["cycle"]:
			b.progress -= d["cycle"]
			b.add_stock(inp, -need)
			b.add_stock(out, d["amount"])
	if _throttle(b):
		var have: int = b.get_stock(inp) + int(b.incoming.get(inp, 0))
		if have < need * 3 and b.efficiency > 0.0:
			_request_supply(b, inp, need * 3 - have)
		if b.get_stock(out) >= mini(CART_LOAD, d["amount"]):
			_dispatch_output(b, out)


func _update_agora(b) -> void:
	if _throttle(b) and b.efficiency > 0.0:
		var wants: Dictionary = b.def["wants"]
		for res in wants:
			var have: int = b.get_stock(res) + int(b.incoming.get(res, 0))
			if have * 2 < wants[res] and _request_supply(b, res, wants[res] - have):
				break
	if b.total_stock() > 0:
		_try_spawn_service(b, "market", "")


func _update_monument(b) -> void:
	var d: Dictionary = b.def
	if b.complete:
		if d.has("service"):
			_try_spawn_service(b, d["service"], d.get("god", ""))
		return
	var st: Dictionary = d["stages"][b.stage]
	var missing := false
	for res in st:
		var have: int = b.get_stock(res)
		if have < st[res]:
			missing = true
			var with_incoming: int = have + int(b.incoming.get(res, 0))
			if with_incoming < st[res] and _throttle(b) and b.efficiency > 0.0:
				_request_supply(b, res, mini(CART_LOAD * 2, st[res] - with_incoming))
	if missing or b.efficiency <= 0.0:
		return
	b.progress += b.efficiency
	if b.progress >= d["stage_ticks"]:
		b.progress = 0.0
		for res in st:
			b.add_stock(res, -st[res])
		b.stage += 1
		if b.stage >= d["stages"].size():
			b.complete = true
			_event("%s est achevé !" % d["name"], "good")
		else:
			_event("%s : étape %d sur %d achevée." % [d["name"], b.stage, d["stages"].size()], "good")


## Envoie un livreur porter la production vers le stockage le plus proche.
func _dispatch_output(b, res: String) -> void:
	if b.cart_id != -1:
		return
	var amt := mini(CART_LOAD, b.get_stock(res))
	var cands := []
	for s in storages():
		if s.efficiency > 0.0 and storage_space(s, res) >= amt:
			cands.append(s)
	if cands.is_empty():
		return
	var r := nearest_by_road(b, cands)
	if r.is_empty():
		return
	b.add_stock(res, -amt)
	r["b"].add_incoming(res, amt)
	var path: Array = r["path"]
	var w = _spawn_walker("cart", b.id, path[0])
	path.pop_front()
	w.path = path
	w.target = r["b"].id
	w.cargo_res = res
	w.cargo_amt = amt
	b.cart_id = w.id


## Fait venir une ressource depuis le stockage le plus proche. Renvoie true si un livreur part.
func _request_supply(b, res: String, amount: int) -> bool:
	if b.fetch_id != -1 or amount <= 0:
		return false
	var cands := []
	for s in storages():
		if s.efficiency > 0.0 and s.get_stock(res) > 0:
			cands.append(s)
	if cands.is_empty():
		return false
	var r := nearest_by_road(b, cands)
	if r.is_empty():
		return false
	var s = r["b"]
	var take := mini(mini(amount, CART_LOAD * 4), s.get_stock(res))
	s.add_stock(res, -take)
	b.add_incoming(res, take)
	var path: Array = r["path"]
	path.reverse()
	var w = _spawn_walker("cart", s.id, path[0])
	path.pop_front()
	w.path = path
	w.target = b.id
	w.cargo_res = res
	w.cargo_amt = take
	b.fetch_id = w.id
	return true


# ---------------------------------------------------------------- Marcheurs

func _spawn_walker(kind: String, home: int, start: Vector2i):
	var w := Walker.new()
	w.id = next_walker_id
	next_walker_id += 1
	w.kind = kind
	w.home = home
	w.pos = start
	w.prev = start
	walkers[w.id] = w
	return w


func _try_spawn_service(b, service: String, god: String) -> void:
	if b.walker_id != -1:
		return
	if b.cooldown > 0:
		b.cooldown -= 1
		return
	if b.efficiency <= 0.0:
		return
	var acc := access_tiles(b, 1)
	if acc.is_empty():
		return
	var start: Vector2i = acc[rng.randi() % acc.size()]
	var w = _spawn_walker("service", b.id, start)
	w.service = service
	w.god = god
	w.steps_left = int(b.def.get("range", 20) * service_range_mult(service))
	w.visited[start] = 1
	b.walker_id = w.id
	_apply_service(w)


func _update_walkers() -> void:
	for wid in walkers.keys():
		var w = walkers.get(wid)
		if w == null:
			continue
		w.move_t += 1
		if w.move_t < WALKER_STEP_TICKS:
			continue
		w.move_t = 0
		if w.kind == "service":
			_step_service(w)
		else:
			_step_path(w)


func _step_service(w) -> void:
	if w.returning:
		if w.path.is_empty():
			_finish_service(w)
			return
		w.prev = w.pos
		w.pos = w.path.pop_front()
		if w.path.is_empty():
			_finish_service(w)
		return
	var opts := []
	for dir in DIRS:
		var q: Vector2i = w.pos + dir
		if road_at(q) == R_ROAD and q != w.prev:
			opts.append(q)
	var nxt: Vector2i = w.pos
	if opts.is_empty():
		if w.prev != w.pos:
			nxt = w.prev
		else:
			_start_return(w)
			return
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
		nxt = cands[rng.randi() % cands.size()]
	w.prev = w.pos
	w.pos = nxt
	w.visited[nxt] = int(w.visited.get(nxt, 0)) + 1
	w.steps_left -= 1
	_apply_service(w)
	if w.steps_left <= 0:
		_start_return(w)


func _start_return(w) -> void:
	var home = buildings.get(w.home)
	if home == null:
		walkers.erase(w.id)
		return
	var goals := {}
	for t in access_tiles(home, 1):
		goals[t] = true
	var path := find_path([w.pos], goals, false)
	if path.is_empty():
		path = find_path([w.pos], goals, true)
	if path.size() <= 1:
		_finish_service(w)
		return
	path.pop_front()
	w.path = path
	w.returning = true


func _finish_service(w) -> void:
	walkers.erase(w.id)
	var home = buildings.get(w.home)
	if home != null and home.walker_id == w.id:
		home.walker_id = -1
		home.cooldown = 10


func _step_path(w) -> void:
	if w.path.is_empty():
		_arrive(w)
		return
	w.prev = w.pos
	w.pos = w.path.pop_front()
	if w.path.is_empty():
		_arrive(w)


func _arrive(w) -> void:
	walkers.erase(w.id)
	var src = buildings.get(w.home)
	if src != null and src.cart_id == w.id:
		src.cart_id = -1
	var t = buildings.get(w.target)
	if t == null:
		return
	if w.kind == "immigrant":
		t.incoming_pop = maxi(0, t.incoming_pop - w.group)
		var room: int = house_cap(t) - t.pop
		t.pop += clampi(w.group, 0, maxi(room, 0))
		return
	if t.fetch_id == w.id:
		t.fetch_id = -1
	t.add_incoming(w.cargo_res, -w.cargo_amt)
	var amount: int = w.cargo_amt
	if t.kind() == "storage":
		amount = mini(amount, int(t.def["capacity"]) - t.total_stock())
	if amount > 0:
		t.add_stock(w.cargo_res, amount)


func _apply_service(w) -> void:
	var home = buildings.get(w.home)
	if home == null:
		return
	var seen := {}
	for dy in range(-SERVICE_RADIUS, SERVICE_RADIUS + 1):
		for dx in range(-SERVICE_RADIUS, SERVICE_RADIUS + 1):
			var q: Vector2i = w.pos + Vector2i(dx, dy)
			if not in_bounds(q):
				continue
			var bid := occ[idx(q)]
			if bid == -1 or seen.has(bid):
				continue
			seen[bid] = true
			_serve(w, home, buildings[bid])


func _serve(w, home, b) -> void:
	if w.service == "guard":
		b.risk = 0.0
		return
	if b.kind() != "house":
		return
	match w.service:
		"water":
			b.water_until = tick + SERVICE_TICKS
		"priest":
			b.religion[w.god] = tick + SERVICE_TICKS
		"sanctuary":
			b.religion[w.god] = tick + SERVICE_TICKS
			b.sanctuary_until = tick + SERVICE_TICKS
		"tax":
			var due := int(b.tax_due)
			if due > 0:
				money += due
				b.tax_due -= due
		"market":
			if b.pop > 0:
				_sell(home, b)


func _sell(agora, house) -> void:
	var need: int = house_food_target(house) - house.get_stock("food")
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
			var give := mini(HOUSE_GOODS_STOCK - house.get_stock(res), agora.get_stock(res))
			if give > 0:
				agora.add_stock(res, -give)
				house.add_stock(res, give)


# ---------------------------------------------------------------- Habitat

func house_levels() -> Array:
	return defs.building("house")["levels"]


func house_cap(b) -> int:
	return house_levels()[b.level]["cap"]


func house_food_target(b) -> int:
	return maxi(2, food_consumption(b) * HOUSE_FOOD_MONTHS)


func food_consumption(b) -> int:
	return ceili(b.pop / 5.0)


func houses() -> Array:
	var res := []
	for b in buildings.values():
		if b.kind() == "house":
			res.append(b)
	return res


func house_beauty(b) -> float:
	var t := 0.0
	for y in b.size:
		for x in b.size:
			t += beauty[idx(b.pos + Vector2i(x, y))]
	return t / float(b.size * b.size)


func house_need_met(b, need: String, value) -> bool:
	match need:
		"food":
			return b.get_stock("food") > 0
		"water":
			return b.water_until > tick
		"religion":
			for g in b.religion:
				if b.religion[g] > tick:
					return true
			return false
		"beauty":
			return house_beauty(b) >= float(value)
		"oil":
			return b.get_stock("oil") > 0
		"wool":
			return b.get_stock("wool") > 0
		"sanctuary":
			return b.sanctuary_until > tick
	return false


func house_target_level(b) -> int:
	var levels := house_levels()
	var lv := 0
	for i in range(1, levels.size()):
		var ok := true
		for need in levels[i]["needs"]:
			if not house_need_met(b, need, levels[i]["needs"][need]):
				ok = false
				break
		if not ok:
			break
		lv = i
	return lv


func _update_houses() -> void:
	var levels := house_levels()
	for b in houses():
		if b.pop <= 0:
			continue
		b.add_stock("food", -mini(food_consumption(b), b.get_stock("food")))
		if b.level >= 4:
			for res in ["oil", "wool"]:
				b.add_stock(res, -mini(1, b.get_stock(res)))
		var target := house_target_level(b)
		if target > b.level:
			b.level += 1
			b.fail_months = 0
		elif target < b.level:
			b.fail_months += 1
			if b.fail_months >= 2:
				b.level -= 1
				b.fail_months = 0
		else:
			b.fail_months = 0
		var cap: int = levels[b.level]["cap"]
		if b.pop > cap:
			b.pop = cap
		b.tax_due += b.pop * float(levels[b.level]["tax"])
	_count_population()


func _count_population() -> void:
	population = 0
	for b in houses():
		population += b.pop


func hungry_fraction() -> float:
	var n := 0
	var hungry := 0
	for b in houses():
		if b.pop > 0:
			n += 1
			if b.get_stock("food") <= 0:
				hungry += 1
	return hungry / float(n) if n > 0 else 0.0


func _immigration() -> void:
	var period := maxi(1, int(IMMIGRATION_PERIOD / immigration_mult()))
	if tick % period != 0:
		return
	if not is_road(entry):
		if months - _no_entry_warned_month >= 6:
			_no_entry_warned_month = months
			_event("Les colons ne trouvent pas de route depuis l'entrée de la carte.", "warn")
		return
	if months >= 3 and hungry_fraction() > 0.5 and rng.randf() < 0.6:
		return
	var goals := {}
	for b in houses():
		if house_cap(b) - b.pop - b.incoming_pop <= 0:
			continue
		for t in access_tiles(b, HOUSE_ROAD_RADIUS):
			if not goals.has(t):
				goals[t] = b.id
	if goals.is_empty():
		return
	var path := find_path([entry], goals, true)
	if path.is_empty():
		return
	var h = buildings[goals[path[path.size() - 1]]]
	var g := mini(IMMIGRANT_GROUP, house_cap(h) - h.pop - h.incoming_pop)
	var w = _spawn_walker("immigrant", -1, path[0])
	path.pop_front()
	w.path = path
	w.target = h.id
	w.group = g
	h.incoming_pop += g


# ---------------------------------------------------------------- Main-d'œuvre

func _allocate_workers() -> void:
	_count_population()
	workers_available = int(population * WORKER_RATIO)
	var order := []
	for b in buildings.values():
		if int(b.def["workers"]) > 0:
			order.append(b)
	order.sort_custom(func(a, c):
		var pa := WORK_PRIORITY.find(a.def["category"])
		var pc := WORK_PRIORITY.find(c.def["category"])
		if pa != pc:
			return pa < pc
		return a.id < c.id)
	var left := workers_available
	workers_needed = 0
	for b in order:
		var need: int = b.def["workers"]
		if b.complete and not b.def.has("service"):
			b.workers = 0
			b.efficiency = 0.0
			continue
		workers_needed += need
		if access_tiles(b, 1).is_empty():
			b.workers = 0
			b.efficiency = 0.0
			continue
		var give := mini(need, left)
		left -= give
		b.workers = give
		b.efficiency = give / float(need)


# ---------------------------------------------------------------- Mois

func _monthly() -> void:
	months += 1
	_update_houses()
	_allocate_workers()
	if workers_needed > workers_available and months - _labor_warned_month >= 6:
		_labor_warned_month = months
		_event("Il manque %d travailleurs : certains bâtiments tournent au ralenti." % (workers_needed - workers_available), "warn")
	_update_risk()
	_update_gods()
	_update_effects()
	_check_objectives()


func _update_risk() -> void:
	for b in buildings.values():
		var r: int = b.def["risk"]
		if r <= 0:
			continue
		b.risk += r
		if b.risk >= RISK_LIMIT:
			_event("Incendie : %s a brûlé. Construisez des postes de vigie." % b.def["name"], "bad")
			remove_building(b.id)


func _update_gods() -> void:
	var inhabited := []
	for b in houses():
		if b.pop > 0:
			inhabited.append(b)
	for god in favor:
		var cd: Dictionary = god_cd[god]
		for k in cd:
			cd[k] = maxi(0, cd[k] - 1)
		if not inhabited.is_empty():
			var covered := 0
			for b in inhabited:
				if b.religion.get(god, 0) > tick:
					covered += 1
			var delta := covered / float(inhabited.size()) * 4.0 - 1.0
			if sanctuary_complete(god):
				delta += 2.0
			var before: float = favor[god]
			favor[god] = clampf(favor[god] + delta, 0.0, 100.0)
			if before > 25.0 and favor[god] <= 25.0:
				_event("%s est mécontent de vous : bâtissez-lui des autels ou offrez-lui une fête." % defs.gods[god]["name"], "warn")
		var gd: Dictionary = defs.gods[god]
		if favor[god] >= 80.0 and cd["blessing"] == 0 and rng.randf() < 0.25:
			cd["blessing"] = 12
			apply_effect(gd["blessing"], god)
		elif favor[god] <= 15.0 and cd["wrath"] == 0 and not inhabited.is_empty() and rng.randf() < 0.25:
			cd["wrath"] = 8
			apply_effect(gd["wrath"], god)
	if mission.get("patron_contest", false) and patron == "":
		var best := ""
		for god in favor:
			if favor[god] >= float(mission.get("patron_threshold", 70)) and (best == "" or favor[god] > favor[best]):
				best = god
		if best != "":
			patron = best
			_event("%s devient le patron de la cité !" % defs.gods[best]["name"], "good")
			apply_effect(defs.gods[best]["patron_bonus"], best)


func sanctuary_complete(god: String) -> bool:
	for b in buildings.values():
		if b.kind() == "monument" and b.complete and b.def.get("god", "") == god:
			return true
	return false


func festival(god: String) -> String:
	if not favor.has(god):
		return "Ce dieu n'est pas honoré ici"
	if money < FESTIVAL_COST:
		return "Une fête coûte %d drachmes" % FESTIVAL_COST
	if god_cd[god]["festival"] > 0:
		return "Une fête a déjà eu lieu récemment (encore %d mois)" % god_cd[god]["festival"]
	money -= FESTIVAL_COST
	favor[god] = minf(100.0, favor[god] + FESTIVAL_FAVOR)
	god_cd[god]["festival"] = FESTIVAL_COOLDOWN
	_event("Fête en l'honneur de %s : sa faveur grandit." % defs.gods[god]["name"], "good")
	return ""


func apply_effect(e: Dictionary, god: String) -> void:
	var kind: String = e["type"]
	match kind:
		"production_mult", "immigration_mult", "service_range_mult":
			var eff := e.duplicate()
			eff["god"] = god
			eff["months_left"] = int(e.get("months", 6))
			effects.append(eff)
		"lose_population":
			for b in houses():
				b.pop -= int(b.pop * float(e["fraction"]))
			_count_population()
		"destroy_random":
			var cands := []
			for b in buildings.values():
				if b.kind() != "monument":
					cands.append(b.id)
			for i in mini(int(e["count"]), cands.size()):
				var k := rng.randi() % cands.size()
				remove_building(cands[k])
				cands.remove_at(k)
	var kind_txt := "good"
	if e == defs.gods[god]["wrath"]:
		kind_txt = "bad"
	_event(e["text"], kind_txt)


func _update_effects() -> void:
	var keep := []
	for e in effects:
		if e["months_left"] > 0:
			e["months_left"] -= 1
			if e["months_left"] == 0:
				continue
		keep.append(e)
	effects = keep


func production_mult(res: String) -> float:
	var m := 1.0
	for e in effects:
		if e["type"] == "production_mult" and res in e["resources"]:
			m *= float(e["mult"])
	return m


func immigration_mult() -> float:
	var m := 1.0
	for e in effects:
		if e["type"] == "immigration_mult":
			m *= float(e["mult"])
	return m


func service_range_mult(service: String) -> float:
	var m := 1.0
	for e in effects:
		if e["type"] == "service_range_mult" and e["service"] == service:
			m *= float(e["mult"])
	return m


# ---------------------------------------------------------------- Beauté

func _compute_beauty() -> void:
	beauty.fill(0.0)
	for b in buildings.values():
		var v: float = b.def["beauty"]
		if v == 0.0:
			continue
		var r: int = b.def["beauty_radius"]
		for y in range(b.pos.y - r, b.pos.y + b.size + r):
			for x in range(b.pos.x - r, b.pos.x + b.size + r):
				var q := Vector2i(x, y)
				if not in_bounds(q):
					continue
				var dx := maxi(maxi(b.pos.x - x, x - (b.pos.x + b.size - 1)), 0)
				var dy := maxi(maxi(b.pos.y - y, y - (b.pos.y + b.size - 1)), 0)
				var dist := maxi(dx, dy)
				beauty[idx(q)] += v * (1.0 - float(dist) / float(r + 1))
	beauty_dirty = false


# ---------------------------------------------------------------- Objectifs

func objectives() -> Array:
	var res := []
	var levels := house_levels()
	for o in mission.get("objectives", []):
		var text := ""
		var done := false
		match o["type"]:
			"population":
				done = population >= int(o["value"])
				text = "Population : %d / %d" % [population, int(o["value"])]
			"houses_level":
				var n := 0
				for b in houses():
					if b.level >= int(o["level"]):
						n += 1
				done = n >= int(o["count"])
				text = "%s ou mieux : %d / %d" % [levels[int(o["level"])]["name"], n, int(o["count"])]
			"monument":
				var name: String = defs.building(o["building"])["name"]
				for b in buildings.values():
					if b.type == o["building"] and b.complete:
						done = true
				text = "Achever : %s" % name
			"patron":
				done = patron != ""
				if done:
					text = "Patron de la cité : %s" % defs.gods[patron]["name"]
				else:
					text = "Choisir un patron (faveur %d)" % int(mission.get("patron_threshold", 70))
			"favor":
				done = favor.get(o["god"], 0.0) >= float(o["value"])
				text = "Faveur de %s : %d / %d" % [defs.gods[o["god"]]["name"], int(favor.get(o["god"], 0.0)), int(o["value"])]
			"money":
				done = money >= int(o["value"])
				text = "Trésor : %d / %d" % [money, int(o["value"])]
		res.append({"text": text, "done": done})
	return res


func _check_objectives() -> void:
	if won:
		return
	var all_done := true
	for o in objectives():
		if not o["done"]:
			all_done = false
	if all_done:
		won = true
		_event("Tous les objectifs sont remplis !", "good")


# ---------------------------------------------------------------- Divers

func _event(text: String, kind: String = "info") -> void:
	events.append({"text": text, "kind": kind, "month": months})


func date_text() -> String:
	return "An %d, mois %d" % [months / 12 + 1, months % 12 + 1]


func building_info(b) -> Array:
	var d: Dictionary = b.def
	var lines := []
	if b.kind() == "house":
		var levels := house_levels()
		lines.append("%s (niveau %d)" % [levels[b.level]["name"], b.level + 1])
		lines.append("Habitants : %d / %d" % [b.pop, house_cap(b)])
		if access_tiles(b, HOUSE_ROAD_RADIUS).is_empty():
			lines.append("Aucune route à moins de 2 cases : personne ne viendra.")
		lines.append("Nourriture : %d" % b.get_stock("food"))
		lines.append("Eau : %s" % ("oui" if b.water_until > tick else "non"))
		lines.append("Culte : %s" % ("oui" if house_need_met(b, "religion", null) else "non"))
		lines.append("Beauté : %d" % int(house_beauty(b)))
		if b.level >= 3:
			lines.append("Huile : %d, laine : %d" % [b.get_stock("oil"), b.get_stock("wool")])
			lines.append("Accès au sanctuaire : %s" % ("oui" if b.sanctuary_until > tick else "non"))
		if b.level + 1 < levels.size():
			var missing := []
			var needs: Dictionary = levels[b.level + 1]["needs"]
			for need in needs:
				if not house_need_met(b, need, needs[need]):
					missing.append(_need_name(need, needs[need]))
			if missing.is_empty():
				lines.append("Montera bientôt : %s" % levels[b.level + 1]["name"])
			else:
				lines.append("Pour devenir %s : %s" % [levels[b.level + 1]["name"], ", ".join(missing)])
	else:
		lines.append(d["name"])
		if int(d["workers"]) > 0:
			lines.append("Employés : %d / %d" % [b.workers, d["workers"]])
			if access_tiles(b, 1).is_empty():
				lines.append("Ne touche aucune route : inactif.")
		match d["kind"]:
			"producer", "processor":
				lines.append("Production : %d %%" % int(100.0 * b.progress / float(d["cycle"])))
		if b.kind() == "monument" and not b.complete:
			var st: Dictionary = d["stages"][b.stage]
			lines.append("Étape %d sur %d" % [b.stage + 1, d["stages"].size()])
			for res in st:
				lines.append("  %s : %d / %d" % [defs.resource_name(res), b.get_stock(res), st[res]])
			lines.append("Travaux : %d %%" % int(100.0 * b.progress / float(d["stage_ticks"])))
		elif b.kind() == "monument":
			lines.append("Achevé")
		if b.total_stock() > 0 and b.kind() != "monument":
			var parts := []
			for res in b.stock:
				parts.append("%s %d" % [defs.resource_name(res), b.stock[res]])
			lines.append("Stock : " + ", ".join(parts))
		if b.kind() == "storage":
			lines.append("Capacité : %d / %d" % [b.total_stock(), d["capacity"]])
	if int(d["risk"]) > 0:
		lines.append("Risque d'incendie : %d %%" % int(b.risk))
	return lines


func _need_name(need: String, value) -> String:
	match need:
		"food": return "nourriture"
		"water": return "eau"
		"religion": return "culte"
		"beauty": return "beauté %d" % int(value)
		"oil": return "huile"
		"wool": return "laine"
		"sanctuary": return "sanctuaire"
	return need


# ---------------------------------------------------------------- Sauvegarde

func to_dict() -> Dictionary:
	var bl := []
	for b in buildings.values():
		bl.append(b.to_dict())
	return {
		"version": 1, "mission": mission["id"], "width": width, "height": height, "tick": tick, "months": months, "money": money,
		"terrain": Marshalls.raw_to_base64(terrain), "roads": Marshalls.raw_to_base64(roads),
		"buildings": bl, "favor": favor.duplicate(), "god_cd": god_cd.duplicate(true),
		"effects": effects.duplicate(true), "patron": patron, "won": won,
	}


static func from_dict(d: Dictionary):
	var defs_ = Defs.get_defs()
	var mi: int = defs_.mission_index(d["mission"])
	if mi < 0:
		return null
	var c = load("res://scripts/sim/city.gd").new(defs_.missions[mi])
	c.width = int(d.get("width", c.width))
	c.height = int(d.get("height", c.height))
	c.occ.resize(c.width * c.height)
	c.occ.fill(-1)
	c.beauty.resize(c.width * c.height)
	c.terrain = Marshalls.base64_to_raw(d["terrain"])
	c.roads = Marshalls.base64_to_raw(d["roads"])
	c.roads_version += 1
	c.tick = int(d["tick"])
	c.months = int(d["months"])
	c.money = int(d["money"])
	for bd in d["buildings"]:
		var b = c._add_building(bd["type"], Vector2i(int(bd["x"]), int(bd["y"])))
		b.load_dict(bd)
	for g in d["favor"]:
		if c.favor.has(g):
			c.favor[g] = float(d["favor"][g])
	for g in d["god_cd"]:
		if not c.god_cd.has(g):
			continue
		for k in d["god_cd"][g]:
			c.god_cd[g][k] = int(d["god_cd"][g][k])
	c.effects = []
	for e in d["effects"]:
		e["months_left"] = int(e["months_left"])
		c.effects.append(e)
	c.patron = d.get("patron", "")
	c.won = bool(d.get("won", false))
	c._allocate_workers()
	return c
