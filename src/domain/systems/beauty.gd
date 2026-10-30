extends RefCounted
## Beauté de chaque case : jardins, statues et temples l'augmentent, l'industrie la baisse,
## avec une décroissance linéaire jusqu'à beauty_radius.


static func recompute(c) -> void:
	var g = c.grid
	c.beauty.resize(g.width * g.height)
	c.beauty.fill(0.0)
	for b in c.buildings.values():
		var v: float = b.def["beauty"]
		if v == 0.0:
			continue
		var r: int = b.def["beauty_radius"]
		for y in range(b.pos.y - r, b.pos.y + b.size + r):
			for x in range(b.pos.x - r, b.pos.x + b.size + r):
				var q := Vector2i(x, y)
				if not g.in_bounds(q):
					continue
				var dx := maxi(maxi(b.pos.x - x, x - (b.pos.x + b.size - 1)), 0)
				var dy := maxi(maxi(b.pos.y - y, y - (b.pos.y + b.size - 1)), 0)
				var dist := maxi(dx, dy)
				c.beauty[g.idx(q)] += v * (1.0 - float(dist) / float(r + 1))
	c.beauty_dirty = false


## Beauté moyenne sur l'emprise d'un bâtiment.
## Beauté d'une case ; calcule la carte si elle n'est pas à jour (ex. avant le premier pas).
static func at(c, p: Vector2i) -> float:
	if c.beauty_dirty:
		recompute(c)
	return c.beauty[c.grid.idx(p)]


static func of_building(c, b) -> float:
	if c.beauty_dirty:
		recompute(c)
	var t := 0.0
	for y in b.size:
		for x in b.size:
			t += c.beauty[c.grid.idx(b.pos + Vector2i(x, y))]
	return t / float(b.size * b.size)
