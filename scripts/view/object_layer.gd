extends Node2D
## Bâtiments, marcheurs et aperçu de construction, triés par profondeur et redessinés à chaque image.

const Iso = preload("res://scripts/view/iso.gd")
const Art = preload("res://scripts/view/art.gd")
const Defs = preload("res://scripts/sim/defs.gd")

var game


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.city == null:
		return
	var city = game.city
	var items := []
	for b in city.buildings.values():
		items.append([float(b.pos.x + b.pos.y + 2 * b.size) - 0.5, 0, b])
	var frac: float = game.walker_frac()
	_add_props(city, items)
	for w in city.walkers.values():
		var t: float = clampf((w.move_t + frac) / float(city.WALKER_STEP_TICKS), 0.0, 1.0)
		var p: Vector2 = Vector2(w.prev).lerp(Vector2(w.pos), t) + Vector2(0.5, 0.5)
		items.append([p.x + p.y + 0.1, 1, w, p])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		if it[1] == 0:
			_draw_building(it[2])
		elif it[1] == 1:
			_draw_walker(it[2], it[3])
		else:
			Art.draw_sprite(self, it[2], Iso.to_screen(Vector2(it[3]) + Vector2(1, 1)))
	_draw_preview()


## Arbres des forêts et blocs des rochers, visibles à l'écran seulement, triés avec le reste.
func _add_props(city, items: Array) -> void:
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	view = view.grow(64.0)
	for y in city.height:
		for x in city.width:
			var p := Vector2i(x, y)
			var t: int = city.terrain[city.idx(p)]
			if t != Defs.T_FOREST and t != Defs.T_ROCK:
				continue
			if not view.has_point(Iso.to_screen(Vector2(p) + Vector2(0.5, 0.5))):
				continue
			if city.road_at(p) != 0 or city.building_at(p) != null:
				continue
			var h: int = x * 7 + y * 13 + (x * y) % 5
			var tex: Texture2D = Art.texture("props", "forest_%d" % (h % 4)) if t == Defs.T_FOREST else Art.texture("props", "rock_%d" % (h % 3))
			if tex != null:
				items.append([float(x + y + 2) - 0.5, 2, tex, p])


func _building_texture(b) -> Texture2D:
	if b.kind() == "house":
		if b.pop == 0:
			var empty := Art.texture("buildings", "house_empty")
			if empty != null:
				return empty
		return Art.texture("buildings", "%s_%d" % [b.type, b.level])
	if b.kind() == "monument" and not b.complete:
		var stage := Art.texture("buildings", "%s_s%d" % [b.type, b.stage])
		if stage == null:
			stage = Art.texture("buildings", "monument_s%d" % b.stage)
		if stage != null:
			return stage
	return Art.texture("buildings", b.type)


## Hauteur du haut du bâtiment au-dessus du centre de son emprise (pour les icônes d'alerte).
func _top_height(b, tex: Texture2D) -> float:
	if tex == null:
		return Art.building_height(b)
	return maxf(Art.sprite_height(tex) - b.size * Iso.TH * 0.5 - 10.0, 10.0)


func _draw_building(b) -> void:
	var city = game.city
	var d: Dictionary = b.def
	var n: float = b.size
	var tex := _building_texture(b)
	var bottom := Iso.to_screen(Vector2(b.pos) + Vector2(n, n))
	if tex != null:
		Art.draw_sprite(self, tex, bottom)
	else:
		var h := Art.building_height(b)
		_draw_box(Vector2(b.pos), n, h, Art.building_color(d, b.level))
		if b.kind() == "house" and b.pop > 0:
			_draw_roof(Vector2(b.pos), n, h, 6.0 + b.level * 2.0)
		elif d["category"] in ["religion", "monuments"]:
			_draw_columns(Vector2(b.pos), n, h)
		if b.kind() == "house" and b.pop == 0:
			draw_colored_polygon(Iso.diamond(Vector2(b.pos) + Vector2(0.3, 0.3), n - 0.6), Color(1, 1, 1, 0.35))
		var label: String = Art.SHORT_LABELS.get(b.type, "")
		if label != "":
			var top := Iso.to_screen(Vector2(b.pos) + Vector2(n, n) * 0.5) - Vector2(0, Art.building_height(b))
			draw_string(ThemeDB.fallback_font, top + Vector2(-40, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(0.15, 0.12, 0.1))
	if game.selected_id == b.id:
		draw_polyline(_closed(Iso.diamond(Vector2(b.pos), n)), Color.WHITE, 2.0)
	# Signale les problèmes : bâtiment sans route ou sans employés.
	var problem := false
	if int(d["workers"]) > 0 and b.efficiency <= 0.0 and not (b.kind() == "monument" and b.complete and not d.has("service")):
		problem = true
	if b.kind() == "house" and city.access_tiles(b, city.HOUSE_ROAD_RADIUS).is_empty():
		problem = true
	if problem:
		var c := Iso.to_screen(Vector2(b.pos) + Vector2(n, n) * 0.5) - Vector2(0, _top_height(b, tex) + 14)
		draw_circle(c, 7.0, Color("#c0392b"))
		draw_string(ThemeDB.fallback_font, c + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if b.risk >= 70.0:
		var c2 := Iso.to_screen(Vector2(b.pos) + Vector2(n, n) * 0.5) - Vector2(-10, _top_height(b, tex) + 12)
		draw_circle(c2, 5.0, Color("#ff8c1a"))


## Boîte isométrique : face du dessus claire, faces avant plus sombres (soleil en haut à gauche).
func _draw_box(p: Vector2, n: float, h: float, col: Color) -> void:
	var inset := 0.08
	var q := p + Vector2(inset, inset)
	var s := n - inset * 2.0
	var top := Iso.to_screen(q)
	var right := Iso.to_screen(q + Vector2(s, 0))
	var bottom := Iso.to_screen(q + Vector2(s, s))
	var left := Iso.to_screen(q + Vector2(0, s))
	var up := Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + up, left + up]), col.darkened(0.18))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + up, bottom + up]), col.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([top + up, right + up, bottom + up, left + up]), col.lightened(0.12))
	draw_polyline(PackedVector2Array([top + up, right + up, bottom + up, left + up, top + up]), col.darkened(0.45), 1.0)


## Toit de tuiles en pyramide, posé sur une boîte de hauteur h.
func _draw_roof(p: Vector2, n: float, h: float, rise: float) -> void:
	var q := p + Vector2(0.08, 0.08)
	var s := n - 0.16
	var up := Vector2(0, -h)
	var top := Iso.to_screen(q) + up
	var right := Iso.to_screen(q + Vector2(s, 0)) + up
	var bottom := Iso.to_screen(q + Vector2(s, s)) + up
	var left := Iso.to_screen(q + Vector2(0, s)) + up
	var apex := Iso.to_screen(q + Vector2(s, s) * 0.5) + up + Vector2(0, -rise)
	draw_colored_polygon(PackedVector2Array([top, right, apex]), Art.TERRACOTTA.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([top, apex, left]), Art.TERRACOTTA.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([left, apex, bottom]), Art.TERRACOTTA.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([bottom, apex, right]), Art.TERRACOTTA.darkened(0.3))


## Colonnes sur les faces avant des temples.
func _draw_columns(p: Vector2, n: float, h: float) -> void:
	var q := p + Vector2(0.08, 0.08)
	var s := n - 0.16
	var count := int(n * 2.0)
	var col := Art.MARBLE.darkened(0.45)
	for i in range(1, count):
		var f := float(i) / float(count)
		var a := Iso.to_screen(q + Vector2(f * s, s))
		draw_line(a, a + Vector2(0, -h + 3.0), col, 1.5)
		var b := Iso.to_screen(q + Vector2(s, f * s))
		draw_line(b, b + Vector2(0, -h + 3.0), col, 1.5)


func _draw_walker(w, p: Vector2) -> void:
	var key: String = w.service if w.kind == "service" else w.kind
	var col: Color = Art.WALKER_COLORS.get(key, Color.WHITE)
	var s := Iso.to_screen(p)
	var tex := Art.texture("walkers", key)
	if tex != null:
		Art.draw_sprite(self, tex, s)
		return
	if w.kind == "cart":
		draw_rect(Rect2(s + Vector2(-6, -9), Vector2(12, 8)), col)
		draw_circle(s + Vector2(-4, 0), 2.5, Color(0.2, 0.15, 0.1))
		draw_circle(s + Vector2(4, 0), 2.5, Color(0.2, 0.15, 0.1))
	elif w.kind == "immigrant":
		for i in mini(w.group, 4):
			draw_circle(s + Vector2(-6 + i * 4, -6 - (i % 2) * 2), 3.0, col)
	else:
		draw_line(s, s + Vector2(0, -10), col.darkened(0.3), 3.0)
		draw_circle(s + Vector2(0, -12), 3.5, col)


func _draw_preview() -> void:
	var city = game.city
	if game.tool == "select":
		return
	for t in game.preview_tiles():
		var p: Vector2i = t[0]
		var ok: bool = t[1]
		var n: int = t[2]
		var col := Color(0.3, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.25, 0.2, 0.45)
		if game.tool == "demolish":
			col = Color(0.95, 0.4, 0.1, 0.45)
		draw_colored_polygon(Iso.diamond(Vector2(p), n), col)
	if game.tool == "build" and game.build_type != "" and not game.dragging:
		var d: Dictionary = city.defs.building(game.build_type)
		var r: int = d.get("beauty_radius", 0)
		if r > 0 and d["kind"] != "road":
			var p0: Vector2i = game.build_origin(game.hover)
			draw_polyline(_closed(Iso.diamond(Vector2(p0 - Vector2i(r, r)), d["size"] + 2 * r)), Color(1, 1, 1, 0.3), 1.0)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var res := poly.duplicate()
	res.append(poly[0])
	return res
