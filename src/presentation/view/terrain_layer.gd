extends Node2D
## Sol, routes et calques d'information. Redessiné seulement quand la carte change.

const Grid = preload("res://src/domain/world/grid.gd")
const Iso = preload("res://src/presentation/view/iso.gd")
const Art = preload("res://src/presentation/view/art.gd")

## Une tuile en pente est dessinée en SLOPE_SUBDIV x SLOPE_SUBDIV quads.
const SLOPE_SUBDIV := 4

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
		_draw_ground(tex, p, t == Grid.T_ROCK or t == Grid.T_HILL)
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
func _draw_ground(tex: Texture2D, p: Vector2i, soft_base := false) -> void:
	if relief.is_flat_tile(p):
		draw_texture_rect(tex, Rect2(Iso.to_screen(Vector2(p)) - Vector2(Iso.TW * 0.5, 0), Vector2(Iso.TW, Iso.TH)), false)
		return
	# Tuile en pente : découpée en petits quads qui épousent la surface arrondie du relief, ombrés sommet
	# par sommet (soleil en haut à gauche : une pente qui descend vers l'avant est dans l'ombre).
	# Au pied d'une pente, l'herbe passe sous la roche et la roche s'efface par endroits : pas de bord net.
	var n := SLOPE_SUBDIV
	var o := Vector2(p)
	var low := minf(minf(relief.corner(p.x, p.y), relief.corner(p.x + 1, p.y)),
		minf(relief.corner(p.x, p.y + 1), relief.corner(p.x + 1, p.y + 1)))
	var under: Texture2D = Art.terrain_texture(Grid.T_GRASS, p) if soft_base and low == 0.0 else null
	var pos := PackedVector2Array()
	var shades := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	for j in n + 1:
		for i in n + 1:
			var q := o + Vector2(i, j) / n
			var h: float = relief.height_at(q)
			pos.append(Iso.to_screen(q) - Vector2(0.0, h))
			var g: Vector2 = relief.slope_at(q)
			shades.append(clampf(1.0 + (g.x * 0.9 + g.y * 0.45) * 0.01, 0.62, 1.12))
			alphas.append(clampf(h / 10.0 + (relief.noise_at(q * 2.0) - 0.5) * 1.4, 0.0, 1.0) if under != null else 1.0)
	for j in n:
		for i in n:
			var ks := [j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i + 1, (j + 1) * (n + 1) + i]
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			var flat := PackedColorArray()
			for k in ks:
				var f := Vector2(k % (n + 1), k / (n + 1)) / n
				pts.append(pos[k])
				uvs.append(Vector2(0.5 + (f.x - f.y) * 0.5, (f.x + f.y) * 0.5))
				cols.append(Color(shades[k], shades[k], shades[k], alphas[k]))
				flat.append(Color(shades[k], shades[k], shades[k]))
			if under != null:
				draw_polygon(pts, flat, uvs, under)
			draw_polygon(pts, cols, uvs, tex)


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
			var v: float = city.beauty_at(Vector2i(x, y))
			if absf(v) < 0.5:
				continue
			var col := Color(0.2, 0.9, 0.3, clampf(v / 30.0, 0.0, 0.6)) if v > 0 else Color(0.9, 0.2, 0.2, clampf(-v / 15.0, 0.0, 0.6))
			draw_colored_polygon(relief.diamond(Vector2(x, y)), col)
