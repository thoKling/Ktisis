extends RefCounted
## Sauvegarde : convertit une cité en dictionnaire (prêt pour JSON) et inversement.
## L'écriture sur disque est l'affaire de l'infrastructure.

const City = preload("res://src/domain/city.gd")
const Construction = preload("res://src/domain/systems/construction.gd")
const Labor = preload("res://src/domain/systems/labor.gd")

const VERSION := 1


static func to_dict(c) -> Dictionary:
	var bl := []
	for b in c.buildings.values():
		bl.append(b.to_dict())
	return {
		"version": VERSION, "mission": c.mission["id"], "width": c.grid.width, "height": c.grid.height,
		"tick": c.tick, "months": c.months, "money": c.money,
		"terrain": Marshalls.raw_to_base64(c.grid.terrain), "roads": Marshalls.raw_to_base64(c.grid.roads),
		"buildings": bl, "favor": c.favor.duplicate(), "god_cd": c.god_cd.duplicate(true),
		"effects": c.effects.duplicate(true), "patron": c.patron, "won": c.won,
	}


## Recrée la cité ; null si la mission de la sauvegarde n'existe plus.
static func from_dict(catalog, d: Dictionary):
	var m: Dictionary = catalog.mission(str(d.get("mission", "")))
	if m.is_empty():
		return null
	var c := City.new(catalog, m)
	var g = c.grid
	g.width = int(d.get("width", g.width))
	g.height = int(d.get("height", g.height))
	g.terrain = Marshalls.base64_to_raw(d["terrain"])
	g.roads = Marshalls.base64_to_raw(d["roads"])
	g.occ.resize(g.width * g.height)
	g.occ.fill(-1)
	g.roads_version += 1
	c.tick = int(d["tick"])
	c.months = int(d["months"])
	c.money = int(d["money"])
	for bd in d["buildings"]:
		var b = Construction.add_building(c, bd["type"], Vector2i(int(bd["x"]), int(bd["y"])))
		b.load_dict(bd)
	for god in d["favor"]:
		if c.favor.has(god):
			c.favor[god] = float(d["favor"][god])
	for god in d["god_cd"]:
		if not c.god_cd.has(god):
			continue
		for k in d["god_cd"][god]:
			c.god_cd[god][k] = int(d["god_cd"][god][k])
	c.effects = []
	for e in d["effects"]:
		e["months_left"] = int(e["months_left"])
		c.effects.append(e)
	c.patron = d.get("patron", "")
	c.won = bool(d.get("won", false))
	Labor.allocate(c)
	return c
