extends RefCounted
## Relief à l'écran : la colline sacrée domine la ville, les rochers forment des buttes.
## Purement visuel (la simulation reste plate) : chaque coin de tuile a une hauteur en pixels,
## la plus basse des quatre tuiles qui s'y touchent (colline 2 niveaux, rocher 1, le reste 0).

const Grid = preload("res://src/domain/world/grid.gd")
const Iso = preload("res://src/presentation/view/iso.gd")

const LEVEL_PX := 28.0
const LEVELS := {Grid.T_HILL: 2, Grid.T_ROCK: 1}

var width := 0
var height := 0
var corners := PackedFloat32Array()
var max_px := 0.0


func _init(grid = null) -> void:
	if grid == null:
		return
	width = grid.width
	height = grid.height
	corners.resize((width + 1) * (height + 1))
	for cy in height + 1:
		for cx in width + 1:
			var lv := 99
			for q in [Vector2i(cx - 1, cy - 1), Vector2i(cx, cy - 1), Vector2i(cx - 1, cy), Vector2i(cx, cy)]:
				var t: int = grid.terrain_at(q) if grid.in_bounds(q) else -1
				lv = mini(lv, LEVELS.get(t, 0))
			var h := lv * LEVEL_PX
			corners[cy * (width + 1) + cx] = h
			max_px = maxf(max_px, h)


func corner(cx: int, cy: int) -> float:
	if corners.is_empty() or cx < 0 or cy < 0 or cx > width or cy > height:
		return 0.0
	return corners[cy * (width + 1) + cx]


## Hauteur en un point de la carte (en tuiles), interpolée entre les coins.
func height_at(p: Vector2) -> float:
	if corners.is_empty():
		return 0.0
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	var fx := p.x - x0
	var fy := p.y - y0
	var a := lerpf(corner(x0, y0), corner(x0 + 1, y0), fx)
	var b := lerpf(corner(x0, y0 + 1), corner(x0 + 1, y0 + 1), fx)
	return lerpf(a, b, fy)


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
