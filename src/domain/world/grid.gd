extends RefCounted
## La carte : terrain, routes et occupation des cases, avec la recherche de chemin sur les routes.

const T_GRASS := 0
const T_WATER := 1
const T_FOREST := 2
const T_ROCK := 3
const T_MEADOW := 4
## Colline sacrée (l'Acropole) : seuls les routes et les monuments faits pour elle s'y posent.
const T_HILL := 5
const TERRAIN_NAMES := {"grass": T_GRASS, "water": T_WATER, "forest": T_FOREST, "rock": T_ROCK, "meadow": T_MEADOW,
	"hill": T_HILL}

const R_NONE := 0
const R_ROAD := 1
const R_BLOCK := 2

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width := 0
var height := 0
var terrain := PackedByteArray()
var roads := PackedByteArray()
var occ := PackedInt32Array()
## Change à chaque modification des routes (sert à invalider les caches d'accès).
var roads_version := 0


func _init(w: int = 0, h: int = 0, t: PackedByteArray = PackedByteArray()) -> void:
	width = w
	height = h
	terrain = t
	if terrain.size() != w * h:
		terrain.resize(w * h)
		terrain.fill(T_GRASS)
	roads.resize(w * h)
	roads.fill(R_NONE)
	occ.resize(w * h)
	occ.fill(-1)


func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func terrain_at(p: Vector2i) -> int:
	return terrain[idx(p)] if in_bounds(p) else T_WATER


func set_terrain(p: Vector2i, t: int) -> void:
	terrain[idx(p)] = t


func road_at(p: Vector2i) -> int:
	return roads[idx(p)] if in_bounds(p) else R_NONE


func is_road(p: Vector2i) -> bool:
	return road_at(p) != R_NONE


func set_road(p: Vector2i, r: int) -> void:
	roads[idx(p)] = r
	roads_version += 1


func occupant(p: Vector2i) -> int:
	return occ[idx(p)] if in_bounds(p) else -1


func is_buildable(p: Vector2i) -> bool:
	var t := terrain_at(p)
	return in_bounds(p) and (t == T_GRASS or t == T_MEADOW)


## Masque des voisins routiers (1 = est, 2 = ouest, 4 = sud, 8 = nord) : la forme de la route en découle.
func road_mask(p: Vector2i) -> int:
	var m := 0
	for i in DIRS.size():
		if is_road(p + DIRS[i]):
			m |= 1 << i
	return m


## Vrai si une case de type t se trouve à moins de r cases de la zone s x s posée en p.
func touches_terrain(p: Vector2i, s: int, t: int, r: int) -> bool:
	for y in range(p.y - r, p.y + s + r):
		for x in range(p.x - r, p.x + s + r):
			var q := Vector2i(x, y)
			if in_bounds(q) and terrain[idx(q)] == t:
				return true
	return false


## Parcours en largeur sur les routes. goals : case -> valeur.
## Renvoie le chemin (départ et arrivée compris) ou [].
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
