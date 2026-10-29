extends RefCounted
## Accès des bâtiments aux routes et recherche du bâtiment le plus proche par la route.


## Cases de route autour d'un bâtiment, à distance radius (1 = cases qui le touchent). Mis en cache.
static func tiles(c, b, radius: int = 1) -> Array:
	var key: int = b.id * 8 + radius
	var cached = c.access_cache.get(key)
	if cached != null and cached[0] == c.grid.roads_version:
		return cached[1]
	var res := []
	if radius == 1:
		for i in b.size:
			for q in [b.pos + Vector2i(i, -1), b.pos + Vector2i(i, b.size), b.pos + Vector2i(-1, i), b.pos + Vector2i(b.size, i)]:
				if c.grid.is_road(q):
					res.append(q)
	else:
		for y in range(b.pos.y - radius, b.pos.y + b.size + radius):
			for x in range(b.pos.x - radius, b.pos.x + b.size + radius):
				var q := Vector2i(x, y)
				if c.grid.is_road(q):
					res.append(q)
	c.access_cache[key] = [c.grid.roads_version, res]
	return res


static func has_road(c, b, radius: int = 1) -> bool:
	return not tiles(c, b, radius).is_empty()


## Le bâtiment de candidates le plus proche par la route. Renvoie {"b", "path"} ou {}.
static func nearest_by_road(c, from_b, candidates: Array) -> Dictionary:
	var goals := {}
	for cand in candidates:
		for t in tiles(c, cand, 1):
			if not goals.has(t):
				goals[t] = cand.id
	var path: Array = c.grid.find_path(tiles(c, from_b, 1), goals, true)
	if path.is_empty():
		return {}
	return {"b": c.buildings[goals[path[path.size() - 1]]], "path": path}
