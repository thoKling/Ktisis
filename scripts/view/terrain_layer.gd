extends Node2D
## Sol, routes et calques d'information. Redessiné seulement quand la carte change.

const Defs = preload("res://scripts/sim/defs.gd")
const Iso = preload("res://scripts/view/iso.gd")
const Art = preload("res://scripts/view/art.gd")

var city
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
	for y in city.height:
		for x in city.width:
			_draw_tile(Vector2i(x, y))
	if overlay == "beauty":
		_draw_beauty()
	# Entrée de la carte.
	var e := Iso.to_screen(Vector2(city.entry) + Vector2(0.5, 0.5))
	draw_circle(e, 7.0, Art.AEGEAN)
	draw_string(ThemeDB.fallback_font, e + Vector2(-30, -12), "Entrée", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_tile(p: Vector2i) -> void:
	var t: int = city.terrain[city.idx(p)]
	var base: Color = Art.TERRAIN_COLORS.get(t, Color.MAGENTA)
	# Légère variation par case pour casser l'uniformité.
	var h := float((p.x * 73856093) ^ (p.y * 19349663)) / 2147483647.0
	base = base.darkened(fposmod(h, 1.0) * 0.06)
	var poly := Iso.diamond(Vector2(p))
	var tex := Art.texture("terrain", str(t))
	if tex != null:
		draw_texture(tex, Iso.to_screen(Vector2(p)) - Vector2(Iso.TW * 0.5, 0))
	else:
		draw_colored_polygon(poly, base)
		if t == Defs.T_FOREST:
			var c := Iso.to_screen(Vector2(p) + Vector2(0.5, 0.5))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(9, 2), c + Vector2(-9, 2)]), Color("#3f5a2a"))
		elif t == Defs.T_ROCK:
			var c := Iso.to_screen(Vector2(p) + Vector2(0.5, 0.5))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 3), c + Vector2(-4, -10), c + Vector2(8, -6), c + Vector2(13, 4)]), Color("#8b8378"))
	var r: int = city.road_at(p)
	if r != 0:
		_draw_road(p, r)


func _draw_road(p: Vector2i, r: int) -> void:
	var mask: int = city.road_mask(p)
	var tex := Art.texture("roads", "road_%d" % mask)
	var c := Iso.to_screen(Vector2(p) + Vector2(0.5, 0.5))
	if tex != null:
		draw_texture(tex, c - tex.get_size() * 0.5)
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
	for y in city.height:
		for x in city.width:
			var v: float = city.beauty[y * city.width + x]
			if absf(v) < 0.5:
				continue
			var col := Color(0.2, 0.9, 0.3, clampf(v / 30.0, 0.0, 0.6)) if v > 0 else Color(0.9, 0.2, 0.2, clampf(-v / 15.0, 0.0, 0.6))
			draw_colored_polygon(Iso.diamond(Vector2(x, y)), col)
