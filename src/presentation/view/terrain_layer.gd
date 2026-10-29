extends Node2D
## Sol, routes et calques d'information. Redessiné seulement quand la carte change.

const Grid = preload("res://src/domain/world/grid.gd")
const Iso = preload("res://src/presentation/view/iso.gd")
const Art = preload("res://src/presentation/view/art.gd")

var city
var relief
var overlay := ""   # "", "beauty"
var _drawn_version := -1
var _drawn_overlay := ""
var _drawn_beauty_tick := -1


func _process(_delta: float) -> void:
	if city == null:
		return
	var beauty_stale: bool = overlay == "beauty" and city.tick - _drawn_beauty_tick > 50
	if city.map_version != _drawn_version or overlay != _drawn_overlay or beauty_stale:
		_drawn_version = city.map_version
		_drawn_overlay = overlay
		_drawn_beauty_tick = city.tick
		queue_redraw()


func _draw() -> void:
	if city == null:
		return
	for y in city.grid.height:
		for x in city.grid.width:
			_draw_tile(Vector2i(x, y))
	if overlay == "beauty":
		_draw_beauty()
	# Entrée de la carte.
	var e := Iso.to_screen(Vector2(city.entry) + Vector2(0.5, 0.5))
	draw_circle(e, 7.0, Art.AEGEAN)
	draw_string(ThemeDB.fallback_font, e + Vector2(-30, -12), "Entrée", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_tile(p: Vector2i) -> void:
	var t: int = city.grid.terrain_at(p)
	var base: Color = Art.TERRAIN_COLORS.get(t, Color.MAGENTA)
	# Légère variation par case pour casser l'uniformité.
	var h := float((p.x * 73856093) ^ (p.y * 19349663)) / 2147483647.0
	base = base.darkened(fposmod(h, 1.0) * 0.06)
	var poly: PackedVector2Array = relief.diamond(Vector2(p))
	var tex := Art.terrain_texture(t, p)
	if t == Grid.T_HILL and not _level(p):
		# Les flancs de la colline sont des falaises de calcaire : seul le plateau est lisse.
		tex = Art.terrain_texture(Grid.T_ROCK, p)
	if tex != null:
		_draw_ground(tex, p)
		if t == Grid.T_WATER:
			_draw_shores(p)
	else:
		draw_colored_polygon(poly, base)
		if t == Grid.T_FOREST:
			var c: Vector2 = relief.to_screen(Vector2(p) + Vector2(0.5, 0.5))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(9, 2), c + Vector2(-9, 2)]), Color("#3f5a2a"))
		elif t == Grid.T_ROCK:
			var c: Vector2 = relief.to_screen(Vector2(p) + Vector2(0.5, 0.5))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 3), c + Vector2(-4, -10), c + Vector2(8, -6), c + Vector2(13, 4)]), Color("#8b8378"))
	var r: int = city.grid.road_at(p)
	if r != 0:
		_draw_road(p, r)


func _level(p: Vector2i) -> bool:
	var h: float = relief.corner(p.x, p.y)
	return relief.corner(p.x + 1, p.y) == h and relief.corner(p.x, p.y + 1) == h and relief.corner(p.x + 1, p.y + 1) == h


## Une texture de sol (ou de route) posée sur la tuile p : à plat, ou épousant le relief.
func _draw_ground(tex: Texture2D, p: Vector2i) -> void:
	if relief.is_flat_tile(p):
		draw_texture_rect(tex, Rect2(Iso.to_screen(Vector2(p)) - Vector2(Iso.TW * 0.5, 0), Vector2(Iso.TW, Iso.TH)), false)
		return
	var pts: PackedVector2Array = relief.diamond(Vector2(p))
	# Soleil en haut à gauche : une pente qui descend vers l'avant (x ou y croissant) est dans l'ombre.
	var hx: float = relief.corner(p.x + 1, p.y) + relief.corner(p.x + 1, p.y + 1) - relief.corner(p.x, p.y) - relief.corner(p.x, p.y + 1)
	var hy: float = relief.corner(p.x, p.y + 1) + relief.corner(p.x + 1, p.y + 1) - relief.corner(p.x, p.y) - relief.corner(p.x + 1, p.y)
	var shade := clampf(1.0 + (hx * 0.9 + hy * 0.45) * 0.006, 0.55, 1.15)
	var col := Color(shade, shade, shade)
	draw_polygon(pts, PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]), tex)


## Sable et écume sur les bords d'une tuile d'eau qui touchent la terre.
func _draw_shores(p: Vector2i) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in 4:
		var q: Vector2i = p + dirs[i]
		if not city.grid.in_bounds(q) or city.grid.terrain_at(q) == Grid.T_WATER:
			continue
		var tex := Art.texture("terrain", "shore_%d" % (1 << i))
		if tex != null:
			draw_texture_rect(tex, Rect2(Iso.to_screen(Vector2(p)) - Vector2(Iso.TW * 0.5, 0), Vector2(Iso.TW, Iso.TH)), false)


func _draw_road(p: Vector2i, r: int) -> void:
	var mask: int = city.grid.road_mask(p)
	var tex := Art.texture("roads", "road_%d" % mask)
	var c: Vector2 = relief.to_screen(Vector2(p) + Vector2(0.5, 0.5))
	if tex != null:
		_draw_ground(tex, p)
	else:
		# La forme découle des voisins : droite, virage, T ou carrefour.
		var offsets := [Vector2(16, 8), Vector2(-16, -8), Vector2(-16, 8), Vector2(16, -8)]
		for i in 4:
			if mask & (1 << i):
				draw_line(c, c + offsets[i], Art.ROAD_EDGE, 16.0)
		for i in 4:
			if mask & (1 << i):
				draw_line(c, c + offsets[i], Art.ROAD_COLOR, 12.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(12, 0), c + Vector2(0, 6), c + Vector2(-12, 0)]), Art.ROAD_COLOR)
	if r == 2:
		draw_line(c + Vector2(-10, -5), c + Vector2(10, 5), Art.TERRACOTTA, 5.0)
		draw_line(c + Vector2(-10, 5), c + Vector2(10, -5), Art.TERRACOTTA, 5.0)


func _draw_beauty() -> void:
	for y in city.grid.height:
		for x in city.grid.width:
			var v: float = city.beauty[y * city.grid.width + x]
			if absf(v) < 0.5:
				continue
			var col := Color(0.2, 0.9, 0.3, clampf(v / 30.0, 0.0, 0.6)) if v > 0 else Color(0.9, 0.2, 0.2, clampf(-v / 15.0, 0.0, 0.6))
			draw_colored_polygon(relief.diamond(Vector2(x, y)), col)
