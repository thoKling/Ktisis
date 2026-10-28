extends RefCounted
## Construit automatiquement des cités « raisonnables » pour vérifier que les missions se gagnent.
## Ce n'est pas une IA de jeu : un quadrillage de rues, des services, puis l'industrie là où le terrain le permet.

const City = preload("res://src/domain/city.gd")
const Grid = preload("res://src/domain/world/grid.gd")


## Quadrillage de rues : colonnes tous les 7 cases à partir de x0, lignes aux ordonnées ys.
static func streets(c: City, x0: int, cols: int, ys: Array) -> void:
	var y0: int = c.entry.y
	c.place_road_path(Grid.l_path(Vector2i(0, y0), Vector2i(x0 + 7 * cols, y0)))
	var ymin: int = ys.min()
	var ymax: int = ys.max()
	for i in cols + 1:
		var x := x0 + 7 * i
		c.place_road_path(Grid.l_path(Vector2i(x, ymin), Vector2i(x, ymax)))
	for yy in ys:
		c.place_road_path(Grid.l_path(Vector2i(x0, yy), Vector2i(x0 + 7 * cols, yy)))


## Quartier : rues, services répartis bloc par bloc (per_block[k] pour le bloc k), puis maisons 2x2.
static func district(c: City, x0: int, cols: int, ys: Array, per_block: Array, max_houses: int) -> int:
	streets(c, x0, cols, ys)
	var blocks := []
	for j in ys.size() - 1:
		for i in cols:
			blocks.append(Rect2i(x0 + 7 * i, ys[j], 7, ys[j + 1] - ys[j]))
	for k in blocks.size():
		var r: Rect2i = blocks[k]
		for t in per_block[k % per_block.size()]:
			place_in(c, t, r.position, r.end + Vector2i(1, 1))
	var n := 0
	for r in blocks:
		for yy in range(r.position.y + 1, r.end.y - 1, 2):
			for xx in [r.position.x + 1, r.position.x + 3, r.position.x + 5]:
				var p := Vector2i(xx, yy)
				if n < max_houses and _near_road(c, p, 2, 2) and c.place("house", p) == "":
					n += 1
	return n


static func _near_road(c: City, p: Vector2i, s: int, r: int) -> bool:
	for y in range(p.y - r, p.y + s + r):
		for x in range(p.x - r, p.x + s + r):
			if c.grid.road_at(Vector2i(x, y)) != Grid.R_NONE:
				return true
	return false


## Pose un bâtiment au premier endroit libre de la zone qui touche une route.
static func place_in(c: City, type: String, from: Vector2i, to: Vector2i) -> bool:
	var s: int = c.catalog.building(type)["size"]
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var p := Vector2i(x, y)
			if c.can_place(type, p) != "":
				continue
			var touches := false
			for i in s:
				for q in [p + Vector2i(i, -1), p + Vector2i(i, s), p + Vector2i(-1, i), p + Vector2i(s, i)]:
					if c.grid.road_at(q) == Grid.R_ROAD:
						touches = true
			if touches and c.place(type, p) == "":
				return true
	return false


## Pose count bâtiments n'importe où sur la carte, en les reliant au réseau par une route.
static func place_linked(c: City, type: String, count: int, max_link: int = 25) -> int:
	var s: int = c.catalog.building(type)["size"]
	var placed := 0
	for y in range(1, c.grid.height - s):
		for x in range(1, c.grid.width - s):
			if placed >= count:
				return placed
			var p := Vector2i(x, y)
			if c.can_place(type, p) != "":
				continue
			if road_link(c, p, s, max_link) and c.place(type, p) == "":
				placed += 1
	return placed


## Trace une route depuis un côté du bâtiment futur jusqu'à la route la plus proche.
static func road_link(c: City, p: Vector2i, s: int, max_link: int) -> bool:
	for side in [p + Vector2i(s, 0), p + Vector2i(-1, 0), p + Vector2i(0, s), p + Vector2i(0, -1)]:
		if not c.grid.in_bounds(side):
			continue
		if c.grid.road_at(side) == Grid.R_ROAD:
			return true
		if c.can_place("road", side) != "":
			continue
		var best := Vector2i(-1, -1)
		var best_d := 1 << 30
		for y in c.grid.height:
			for x in c.grid.width:
				var q := Vector2i(x, y)
				if c.grid.road_at(q) == Grid.R_ROAD:
					var d: int = absi(q.x - side.x) + absi(q.y - side.y)
					if d < best_d:
						best_d = d
						best = q
		if best.x < 0 or best_d > max_link:
			continue
		var ok := true
		for path in [Grid.l_path(side, best), Grid.l_path(best, side)]:
			ok = true
			for q in path:
				var footprint: bool = q.x >= p.x and q.y >= p.y and q.x < p.x + s and q.y < p.y + s
				if footprint or (c.grid.road_at(q) == Grid.R_NONE and c.can_place("road", q) != ""):
					ok = false
					break
			if ok:
				c.place_road_path(path)
				return true
	return false


## Remplit les cases libres le long des rues avec des jardins.
static func gardens(c: City, from: Vector2i, to: Vector2i, max_count: int) -> int:
	var n := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if n >= max_count:
				return n
			if c.place("garden", Vector2i(x, y)) == "":
				n += 1
	return n


static func build_thebes(c: City) -> bool:
	var y0: int = c.entry.y
	var farms := place_linked(c, "farm", 4)
	var h := district(c, 6, 3, [y0 - 9, y0, y0 + 9], [
		["agora", "fountain"], ["granary", "fountain", "altar_demeter"], ["fountain", "guard_post", "tax_office"],
		["agora", "fountain", "guard_post"], ["fountain", "altar_demeter"], ["guard_post", "fountain"]], 40)
	return h >= 25 and farms >= 3


## Mission 2 : une ville plus grande, des autels surtout pour Athéna, oliveraies et pressoir.
static func build_athenes(c: City) -> bool:
	var y0: int = c.entry.y
	var farms := place_linked(c, "farm", 5)
	place_linked(c, "fishery", 2)
	place_linked(c, "olive_grove", 1)
	var h := district(c, 6, 4, [y0 - 18, y0 - 9, y0, y0 + 9, y0 + 18], [
		["agora", "fountain", "guard_post"], ["granary", "fountain", "altar_athena"], ["fountain", "plaza", "tax_office"],
		["warehouse", "fountain", "guard_post"], ["fountain", "altar_athena", "plaza"], ["agora", "fountain", "guard_post"],
		["fountain", "plaza", "altar_poseidon"], ["press", "fountain", "guard_post"]], 60)
	return h >= 40 and farms >= 4


## Mission 3 : d'abord une ville qui vit, l'industrie et les monuments viennent ensuite (voir wishlist).
static func build_iolcos(c: City) -> bool:
	var y0: int = c.entry.y
	var farms := place_linked(c, "farm", 4)
	place_linked(c, "fishery", 2)
	var h := district(c, 6, 5, [y0 - 18, y0 - 9, y0, y0 + 9, y0 + 18], [
		["agora", "fountain"], ["granary", "fountain", "altar_hera"], ["fountain", "guard_post"],
		["warehouse", "fountain", "plaza"], ["agora", "fountain", "guard_post", "tax_office"], ["fountain", "altar_hera"],
		["fountain", "guard_post"], ["fountain", "plaza"], ["agora", "fountain", "altar_hera"],
		["granary", "fountain", "guard_post"]], 70)
	return h >= 50 and farms >= 3


## Ce que le planificateur ajoute en cours de partie, dans l'ordre, quand le trésor le permet.
static func wishlist(mission_id: String) -> Array:
	match mission_id:
		"iolcos":
			return [["woodcutter", 2], ["guard_post", 6], ["olive_grove", 1], ["press", 1], ["sheepfold", 2], ["quarry", 2],
				["warehouse", 2], ["fishery", 3], ["argo_shipyard", 1], ["sanctuary_hera", 1], ["farm", 6]]
	return []


static func develop(c: City, keep: int = 200) -> void:
	for item in wishlist(c.mission["id"]):
		var type: String = item[0]
		var have := 0
		for b in c.buildings.values():
			if b.type == type:
				have += 1
		if have >= item[1]:
			continue
		if c.money < int(c.catalog.building(type)["cost"]) + keep:
			return
		if type == "guard_post":
			var y0: int = c.entry.y
			place_in(c, type, Vector2i(6, y0 - 18), Vector2i(42, y0 + 19))
		else:
			place_linked(c, type, 1, 30)
		return


## En cours de partie : dépense le surplus en jardins et places autour des maisons les moins belles.
static func embellish(c: City, keep: int = 300) -> int:
	var n := 0
	var hs := c.houses()
	hs.sort_custom(func(a, b): return c.house_beauty(a) < c.house_beauty(b))
	for h in hs:
		if c.money < keep:
			break
		for type in ["statue", "plaza", "garden"]:
			if not c.is_available(type):
				continue
			var s: int = c.catalog.building(type)["size"]
			var done := false
			for y in range(h.pos.y - s - 1, h.pos.y + h.size + 2):
				for x in range(h.pos.x - s - 1, h.pos.x + h.size + 2):
					if c.money >= keep and c.place(type, Vector2i(x, y)) == "":
						n += 1
						done = true
						break
				if done:
					break
	return n
