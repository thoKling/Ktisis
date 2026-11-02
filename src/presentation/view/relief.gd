extends RefCounted
## Relief à l'écran : la colline sacrée domine la ville, les rochers forment des montagnes.
## Purement visuel (la simulation reste plate). Chaque coin de tuile a une hauteur en pixels, la plus basse
## des quatre tuiles qui s'y touchent : colline en terrasses (HILL_TIERS, un palier toutes les deux tuiles
## d'éloignement du bord : une pente, puis un replat) ; rocher de plus en plus haut vers le cœur du massif
## (ROCK_STEP par tuile d'éloignement du bord, jusqu'à ROCK_MAX_STEPS), avec un peu d'irrégularité.
## Entre les coins, la surface est une interpolation cubique monotone (pentes arrondies, sans dépassement :
## ce qui est plat le reste) et les pentes reçoivent un léger bruit, pour ne pas paraître taillées au cordeau.

const Grid = preload("res://src/domain/world/grid.gd")
const Iso = preload("res://src/presentation/view/iso.gd")

## Hauteur des terrasses de la colline sacrée, du bas vers le sommet.
const HILL_TIERS := [20.0, 38.0, 54.0]
const ROCK_STEP := 16.0
const ROCK_MAX_STEPS := 3
const CORNER_JITTER := 5.0
const SLOPE_NOISE := 4.0
const NOISE_RES := 3            # points de bruit par tuile
## Gardé pour compatibilité : hauteur d'un « niveau » (pas de recherche de la tuile sous la souris).
const LEVEL_PX := 16.0

var width := 0
var height := 0
var corners := PackedFloat32Array()
var tan_x := PackedFloat32Array()
var tan_y := PackedFloat32Array()
var max_px := 0.0


## platforms : [[pos: Vector2i, size: int], ...] les monuments posés sur la colline. Leur emprise est
## aplanie à la hauteur de sa terrasse la plus haute (un soubassement), pour qu'ils soient bien à plat.
func _init(grid = null, platforms: Array = []) -> void:
	if grid == null:
		return
	width = grid.width
	height = grid.height
	var tile_h := _tile_heights(grid)
	var plat := PackedFloat32Array()
	plat.resize(width * height)
	plat.fill(-1.0)
	for pl in platforms:
		var pos: Vector2i = pl[0]
		var sz: int = pl[1]
		var top := 0.0
		for y in range(pos.y, pos.y + sz):
			for x in range(pos.x, pos.x + sz):
				if x >= 0 and y >= 0 and x < width and y < height:
					top = maxf(top, tile_h[y * width + x])
		for y in range(pos.y, pos.y + sz):
			for x in range(pos.x, pos.x + sz):
				if x >= 0 and y >= 0 and x < width and y < height:
					plat[y * width + x] = maxf(plat[y * width + x], top)
	var n := (width + 1) * (height + 1)
	corners.resize(n)
	for cy in height + 1:
		for cx in width + 1:
			var h := 1e9
			var on_plat := -1.0
			var all_rock := true
			for q in [Vector2i(cx - 1, cy - 1), Vector2i(cx, cy - 1), Vector2i(cx - 1, cy), Vector2i(cx, cy)]:
				var inside: bool = q.x >= 0 and q.y >= 0 and q.x < width and q.y < height
				h = minf(h, tile_h[q.y * width + q.x] if inside else 0.0)
				if inside:
					on_plat = maxf(on_plat, plat[q.y * width + q.x])
				all_rock = all_rock and inside and grid.terrain_at(q) == Grid.T_ROCK
			if on_plat >= 0.0:
				h = on_plat
			if all_rock and h > 0.0:
				h = maxf(h + (_hash(cx, cy, 7) - 0.5) * 2.0 * CORNER_JITTER, 2.0)
			corners[cy * (width + 1) + cx] = h
			max_px = maxf(max_px, h)
	max_px += SLOPE_NOISE
	# Tangentes monotones : nulles dès qu'un des deux côtés est plat ou que la pente change de sens.
	tan_x.resize(n)
	tan_y.resize(n)
	for cy in height + 1:
		for cx in width + 1:
			var c := corner(cx, cy)
			tan_x[cy * (width + 1) + cx] = _tangent(c - corner(cx - 1, cy), corner(cx + 1, cy) - c)
			tan_y[cy * (width + 1) + cx] = _tangent(c - corner(cx, cy - 1), corner(cx, cy + 1) - c)


## Hauteur propre à chaque tuile : terrasses de la colline, ou rocher selon la distance au bord du massif.
func _tile_heights(grid) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(width * height)
	var rock_d := _distance_inside(grid, Grid.T_ROCK)
	var hill_e := _round_distance_inside(grid, Grid.T_HILL)
	for y in height:
		for x in width:
			var i := y * width + x
			var t: int = grid.terrain_at(Vector2i(x, y))
			if t == Grid.T_HILL:
				# Distance euclidienne au bord (et non en cases) : des terrasses aux contours arrondis.
				out[i] = HILL_TIERS[clampi(int((hill_e[i] - 0.5) / 2.0), 0, HILL_TIERS.size() - 1)]
			elif t == Grid.T_ROCK:
				out[i] = ROCK_STEP * mini(rock_d[i], ROCK_MAX_STEPS)
	return out


## Pour chaque tuile du terrain `kind`, distance euclidienne (en tuiles) entre son centre et le centre de la
## plus proche tuile d'un autre terrain (1 au bord) ; 0 pour les autres tuiles. Recherche bornée à 8 tuiles.
func _round_distance_inside(grid, kind: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(width * height)
	const R := 8
	for y in height:
		for x in width:
			if grid.terrain_at(Vector2i(x, y)) != kind:
				continue
			var best := float(R + 1)
			for dy in range(-R, R + 1):
				for dx in range(-R, R + 1):
					var q := Vector2i(x + dx, y + dy)
					var other: bool = q.x < 0 or q.y < 0 or q.x >= width or q.y >= height or grid.terrain_at(q) != kind
					if other:
						best = minf(best, Vector2(dx, dy).length())
			out[y * width + x] = best
	return out


## Pour chaque tuile du terrain `kind`, distance (en tuiles, diagonales comprises) à la plus proche tuile
## d'un autre terrain : 1 au bord, 2 juste derrière... ; 0 pour les autres tuiles.
func _distance_inside(grid, kind: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	var queue: Array[Vector2i] = []
	for y in height:
		for x in width:
			var inside: bool = grid.terrain_at(Vector2i(x, y)) == kind
			dist[y * width + x] = 1 << 20 if inside else 0
			if not inside:
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d: int = dist[p.y * width + p.x]
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := Vector2i(p.x + dx, p.y + dy)
				if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
					continue
				if dist[q.y * width + q.x] > d + 1:
					dist[q.y * width + q.x] = d + 1
					queue.append(q)
	for i in dist.size():
		if dist[i] >= 1 << 20:
			dist[i] = 99   # massif sans bord sur la carte (cas limite)
	return dist


static func _tangent(left: float, right: float) -> float:
	if left == 0.0 or right == 0.0 or signf(left) != signf(right):
		return 0.0
	return 2.0 * left * right / (left + right)   # moyenne harmonique : jamais de dépassement


static func _hash(x: int, y: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func corner(cx: int, cy: int) -> float:
	if corners.is_empty() or cx < 0 or cy < 0 or cx > width or cy > height:
		return 0.0
	return corners[cy * (width + 1) + cx]


## Hauteur en un point de la carte (en tuiles) : surface lisse entre les coins, plus le bruit des pentes.
func height_at(p: Vector2) -> float:
	if corners.is_empty():
		return 0.0
	var h := _smooth_at(p)
	if SLOPE_NOISE <= 0.0:
		return h
	var e := 0.05
	var gx := (_smooth_at(p + Vector2(e, 0)) - _smooth_at(p - Vector2(e, 0))) / (2.0 * e)
	var gy := (_smooth_at(p + Vector2(0, e)) - _smooth_at(p - Vector2(0, e))) / (2.0 * e)
	var amp := clampf(Vector2(gx, gy).length() / 30.0, 0.0, 1.0) * SLOPE_NOISE
	if amp <= 0.0:
		return h
	return h + (_noise(p) - 0.5) * 2.0 * amp


func _smooth_at(p: Vector2) -> float:
	var x0 := clampi(floori(p.x), 0, maxi(width - 1, 0))
	var y0 := clampi(floori(p.y), 0, maxi(height - 1, 0))
	var fx := clampf(p.x - x0, 0.0, 1.0)
	var fy := clampf(p.y - y0, 0.0, 1.0)
	var ax := [2.0 * fx * fx * fx - 3.0 * fx * fx + 1.0, -2.0 * fx * fx * fx + 3.0 * fx * fx]
	var bx := [fx * fx * fx - 2.0 * fx * fx + fx, fx * fx * fx - fx * fx]
	var ay := [2.0 * fy * fy * fy - 3.0 * fy * fy + 1.0, -2.0 * fy * fy * fy + 3.0 * fy * fy]
	var by := [fy * fy * fy - 2.0 * fy * fy + fy, fy * fy * fy - fy * fy]
	var h := 0.0
	for j in 2:
		for i in 2:
			var k := (y0 + j) * (width + 1) + x0 + i
			h += corners[k] * ax[i] * ay[j] + tan_x[k] * bx[i] * ay[j] + tan_y[k] * ax[i] * by[j]
	return h


func _noise(p: Vector2) -> float:
	return noise_at(p * NOISE_RES)


## Bruit de valeurs continu (un point par unité), entre 0 et 1.
func noise_at(q: Vector2) -> float:
	var x0 := floori(q.x)
	var y0 := floori(q.y)
	var fx := q.x - x0
	var fy := q.y - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash(x0, y0, 3), _hash(x0 + 1, y0, 3), fx)
	var b := lerpf(_hash(x0, y0 + 1, 3), _hash(x0 + 1, y0 + 1, 3), fx)
	return lerpf(a, b, fy)


## Pente (pixels de hauteur par tuile, en x et en y) au point p, pour l'ombrage.
func slope_at(p: Vector2) -> Vector2:
	var e := 0.08
	return Vector2(height_at(p + Vector2(e, 0)) - height_at(p - Vector2(e, 0)),
		height_at(p + Vector2(0, e)) - height_at(p - Vector2(0, e))) / (2.0 * e)


## Point de la carte vers l'écran, relief compris.
func to_screen(p: Vector2) -> Vector2:
	return Iso.to_screen(p) - Vector2(0.0, height_at(p))


## Losange relevé d'une zone de n x n tuiles.
func diamond(p: Vector2, n: float = 1.0) -> PackedVector2Array:
	return PackedVector2Array([to_screen(p), to_screen(p + Vector2(n, 0)), to_screen(p + Vector2(n, n)), to_screen(p + Vector2(0, n))])


func is_flat_tile(p: Vector2i) -> bool:
	return corner(p.x, p.y) == 0.0 and corner(p.x + 1, p.y) == 0.0 and corner(p.x, p.y + 1) == 0.0 \
		and corner(p.x + 1, p.y + 1) == 0.0


## La tuile sous un point de l'écran : parmi les tuiles relevées dont le losange contient le point,
## la plus en avant (celle qui est dessinée par-dessus).
func tile_at(s: Vector2) -> Vector2i:
	var best := Iso.tile_at(s)
	if max_px <= 0.0:
		return best
	var best_depth := -1
	var d := 0.0
	while d <= max_px:
		var q := Iso.tile_at(s + Vector2(0.0, d))
		for c in [q, q + Vector2i(1, 0), q + Vector2i(0, 1), q - Vector2i(1, 0), q - Vector2i(0, 1)]:
			if c.x + c.y > best_depth and Geometry2D.is_point_in_polygon(s, diamond(Vector2(c))):
				best = c
				best_depth = c.x + c.y
		d += LEVEL_PX * 0.25
	return best
