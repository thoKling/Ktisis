extends RefCounted
## Pose et démolition : règles de terrain, coûts, routes et barrages.

const Grid = preload("res://src/domain/world/grid.gd")
const Building = preload("res://src/domain/world/building.gd")
const Labor = preload("res://src/domain/systems/labor.gd")
const Logistics = preload("res://src/domain/systems/logistics.gd")


## Raison du refus, ou "" si la pose est possible.
static func can_place(c, type: String, p: Vector2i) -> String:
	var d: Dictionary = c.catalog.building(type)
	if d.is_empty():
		return "Bâtiment inconnu"
	if not c.is_available(type):
		return "Non disponible dans cette mission"
	if c.money < int(d["cost"]):
		return "Pas assez de drachmes"
	if d.has("cost_res"):
		for r in d["cost_res"]:
			if Logistics.stored_total(c, r) < d["cost_res"][r]:
				return "Il faut %d %s en entrepôt" % [d["cost_res"][r], c.catalog.resource_name(r)]
	var g = c.grid
	if d["kind"] == "roadblock":
		if g.road_at(p) != Grid.R_ROAD:
			return "Un barrage se pose sur une route"
		return ""
	var s: int = d["size"]
	var meadow := 0
	for y in s:
		for x in s:
			var q := p + Vector2i(x, y)
			if not g.in_bounds(q):
				return "Hors de la carte"
			if not g.is_buildable(q):
				return "Terrain impraticable"
			if g.occupant(q) != -1:
				return "Emplacement occupé"
			if g.is_road(q):
				return "Une route passe ici"
			if g.terrain_at(q) == Grid.T_MEADOW:
				meadow += 1
	if d.get("on", "") == "meadow" and meadow * 2 < s * s:
		return "Il faut une prairie fertile"
	if d.get("coast", false) and not g.touches_terrain(p, s, Grid.T_WATER, 1):
		return "Doit toucher l'eau"
	if d.has("near"):
		var t_near: int = Grid.TERRAIN_NAMES[d["near"]]
		if not g.touches_terrain(p, s, t_near, int(d.get("near_radius", 2))):
			return "Doit être près d'une forêt" if d["near"] == "forest" else "Doit être près d'un rocher"
	return ""


static func place(c, type: String, p: Vector2i) -> String:
	var err := can_place(c, type, p)
	if err != "":
		return err
	var d: Dictionary = c.catalog.building(type)
	c.money -= int(d["cost"])
	if d.has("cost_res"):
		for r in d["cost_res"]:
			Logistics.take_from_storage(c, r, d["cost_res"][r])
	match d["kind"]:
		"road":
			c.grid.set_road(p, Grid.R_ROAD)
			c.map_version += 1
		"roadblock":
			c.grid.set_road(p, Grid.R_BLOCK)
			c.map_version += 1
		_:
			add_building(c, type, p)
			Labor.allocate(c)
	return ""


## Trace une route le long d'un chemin ; renvoie le nombre de cases posées.
static func place_road_path(c, tiles: Array) -> int:
	var n := 0
	for q in tiles:
		if c.grid.road_at(q) == Grid.R_NONE and place(c, "road", q) == "":
			n += 1
	return n


## Ajoute un bâtiment sans contrôle ni coût (utilisé par place et par le chargement d'une sauvegarde).
static func add_building(c, type: String, p: Vector2i):
	var d: Dictionary = c.catalog.building(type)
	var b := Building.new()
	b.id = c.next_id
	c.next_id += 1
	b.type = type
	b.pos = p
	b.size = int(d["size"])
	b.def = d
	c.buildings[b.id] = b
	for y in b.size:
		for x in b.size:
			c.grid.occ[c.grid.idx(p + Vector2i(x, y))] = b.id
	c.beauty_dirty = true
	c.map_version += 1
	return b


static func demolish(c, p: Vector2i) -> bool:
	var g = c.grid
	if not g.in_bounds(p):
		return false
	var bid: int = g.occupant(p)
	if bid != -1:
		remove_building(c, bid)
		return true
	if g.is_road(p):
		g.set_road(p, Grid.R_NONE)
		c.map_version += 1
		return true
	return false


static func remove_building(c, bid: int) -> void:
	var b = c.buildings.get(bid)
	if b == null:
		return
	for y in b.size:
		for x in b.size:
			c.grid.occ[c.grid.idx(b.pos + Vector2i(x, y))] = -1
	c.buildings.erase(bid)
	# Les marcheurs de service disparaissent avec leur bâtiment ; les livreurs finissent leur trajet.
	for wid in c.walkers.keys():
		var w = c.walkers[wid]
		if w.kind == "service" and w.home == bid:
			c.walkers.erase(wid)
	c.beauty_dirty = true
	c.map_version += 1
	Labor.allocate(c)
