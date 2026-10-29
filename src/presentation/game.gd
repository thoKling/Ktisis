extends Node2D
## Une partie en cours : fait avancer la simulation, gère la caméra, les outils et l'interface.

signal quit_to_menu
signal mission_won(index: int)

const City = preload("res://src/domain/city.gd")
const Grid = preload("res://src/domain/world/grid.gd")
const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")
const FileStore = preload("res://src/infrastructure/file_store.gd")
const BuildingInfo = preload("res://src/presentation/building_info.gd")
const Iso = preload("res://src/presentation/view/iso.gd")
const TerrainLayer = preload("res://src/presentation/view/terrain_layer.gd")
const ObjectLayer = preload("res://src/presentation/view/object_layer.gd")
const Hud = preload("res://src/presentation/view/hud.gd")
const Relief = preload("res://src/presentation/view/relief.gd")

const TICKS_PER_SECOND := 10.0
const PAN_SPEED := 900.0
const TERRAIN_LABELS := ["Herbe", "Eau", "Forêt", "Rocher", "Prairie fertile", "Colline sacrée"]

var city
var mission_index := 0
var speed := 1
var tool := "select"
var build_type := ""
var hover := Vector2i.ZERO
var dragging := false
var drag_start := Vector2i.ZERO
var selected_id := -1

var _acc := 0.0
var _events_read := 0
var _won_shown := false
var _pan_drag := false

var relief
var terrain_layer
var object_layer
var camera: Camera2D
var hud


func setup(index: int, loaded_city = null) -> void:
	mission_index = index
	if loaded_city != null:
		city = loaded_city
	else:
		var catalog = CatalogLoader.load_catalog()
		city = City.new(catalog, catalog.missions[index])


func _ready() -> void:
	relief = Relief.new(city.grid)
	terrain_layer = TerrainLayer.new()
	terrain_layer.city = city
	terrain_layer.relief = relief
	add_child(terrain_layer)
	object_layer = ObjectLayer.new()
	object_layer.game = self
	add_child(object_layer)
	camera = Camera2D.new()
	add_child(camera)
	camera.position = Iso.to_screen(Vector2(city.entry) + Vector2(12, 0))
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	if city.tick == 0 or city.needs_patron_choice():
		speed = 0
		hud.show_intro(city.mission)
	_won_shown = city.won
	_events_read = city.events.size()


func _process(delta: float) -> void:
	_pan(delta)
	if speed > 0:
		_acc += delta * TICKS_PER_SECOND * speed
		var n := 0
		while _acc >= 1.0 and n < 200:
			city.step()
			_acc -= 1.0
			n += 1
	while _events_read < city.events.size():
		hud.add_log(city.events[_events_read])
		_events_read += 1
	if city.won and not _won_shown:
		_won_shown = true
		speed = 0
		mission_won.emit(mission_index)
		hud.show_victory(city.mission, mission_index + 1 < city.catalog.missions.size())
	hud.refresh()


## Avancement entre deux pas de simulation, pour des marcheurs fluides.
func walker_frac() -> float:
	return clampf(_acc, 0.0, 1.0) if speed > 0 else 0.0


func _pan(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	camera.position += v * PAN_SPEED * delta / camera.zoom.x


# ---------------------------------------------------------------- Outils

func set_tool(t: String, type: String = "") -> void:
	tool = t
	build_type = type
	dragging = false


func set_speed(s: int) -> void:
	speed = s


func build_origin(p: Vector2i) -> Vector2i:
	if build_type == "":
		return p
	var s: int = city.catalog.building(build_type)["size"]
	return p - Vector2i((s - 1) / 2, (s - 1) / 2)


func _drag_kind() -> String:
	if tool == "demolish":
		return "rect"
	if tool == "build" and build_type == "road":
		return "line"
	if tool == "build" and build_type in ["house", "garden"]:
		return "fill"
	return ""


## Cases de l'aperçu : [position, valide, taille].
func preview_tiles() -> Array:
	var res := []
	if tool == "demolish":
		var a := drag_start if dragging else hover
		for p in _rect(a, hover, 1):
			res.append([p, true, 1])
		return res
	if tool != "build" or build_type == "":
		return res
	var s: int = city.catalog.building(build_type)["size"]
	var kind := _drag_kind()
	if dragging and kind == "line":
		for p in Grid.l_path(drag_start, hover):
			res.append([p, city.grid.road_at(p) != 0 or city.can_place("road", p) == "", 1])
	elif dragging and kind == "fill":
		for p in _rect(drag_start, hover, s):
			res.append([p, city.can_place(build_type, p) == "", s])
	else:
		var p := build_origin(hover)
		res.append([p, city.can_place(build_type, p) == "", s])
	return res


func _rect(a: Vector2i, b: Vector2i, step: int) -> Array:
	var res := []
	var x0 := mini(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var x1 := maxi(a.x, b.x)
	var y1 := maxi(a.y, b.y)
	var y := y0
	while y <= y1:
		var x := x0
		while x <= x1:
			res.append(Vector2i(x, y))
			x += step
		y += step
	return res


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		hover = relief.tile_at(get_canvas_transform().affine_inverse() * event.position)
	if event is InputEventMouseMotion:
		if _pan_drag:
			camera.position -= event.relative / camera.zoom.x
		hud.set_hover_text(_hover_text())
	elif event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.4, 0.4), Vector2(2.5, 2.5))
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.4, 0.4), Vector2(2.5, 2.5))
		MOUSE_BUTTON_MIDDLE:
			_pan_drag = event.pressed
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				set_tool("select")
				hud.clear_build_menu()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if tool == "select":
					var b = city.building_at(hover)
					selected_id = b.id if b != null else -1
				elif _drag_kind() != "":
					dragging = true
					drag_start = hover
				else:
					_apply_build([build_origin(hover)])
			elif dragging:
				_finish_drag()


func _finish_drag() -> void:
	dragging = false
	match _drag_kind():
		"line":
			var n: int = city.place_road_path(Grid.l_path(drag_start, hover))
			if n == 0 and city.grid.road_at(hover) == 0:
				hud.flash(city.can_place("road", hover))
		"rect":
			for p in _rect(drag_start, hover, 1):
				city.demolish(p)
		"fill":
			var s: int = city.catalog.building(build_type)["size"]
			_apply_build(_rect(drag_start, hover, s))


func _apply_build(positions: Array) -> void:
	var last_err := ""
	var ok := 0
	for p in positions:
		var err: String = city.place(build_type, p)
		if err == "":
			ok += 1
		else:
			last_err = err
	if ok == 0 and last_err != "":
		hud.flash(last_err)


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			set_tool("select")
			selected_id = -1
			hud.clear_build_menu()
		KEY_SPACE:
			speed = 0 if speed > 0 else 1
		KEY_1:
			speed = 1
		KEY_2:
			speed = 2
		KEY_3:
			speed = 4
		KEY_B:
			toggle_overlay()
		KEY_F5:
			save_game()
		KEY_DELETE:
			set_tool("demolish")


func toggle_overlay() -> void:
	terrain_layer.overlay = "" if terrain_layer.overlay == "beauty" else "beauty"


func _hover_text() -> String:
	if not city.grid.in_bounds(hover):
		return ""
	if tool == "build" and build_type != "":
		var err: String = city.can_place(build_type, build_origin(hover))
		var d: Dictionary = city.catalog.building(build_type)
		return "%s : %s" % [d["name"], err if err != "" else "%d drachmes" % d["cost"]]
	var b = city.building_at(hover)
	if b != null:
		return BuildingInfo.lines(city, b)[0]
	return "%s  (beauté %d)" % [TERRAIN_LABELS[city.grid.terrain_at(hover)], int(city.beauty[city.grid.idx(hover)])]


func selected_building():
	return city.buildings.get(selected_id)


# ---------------------------------------------------------------- Sauvegarde

func save_game() -> void:
	hud.flash("Partie sauvegardée" if FileStore.save_city(city) else "Impossible d'écrire la sauvegarde")


func choose_patron(god: String) -> void:
	var err: String = city.choose_patron(god)
	if err != "":
		hud.flash(err)
	# Le temple du protecteur vient d'apparaître : la liste ouverte doit être refaite.
	hud.clear_build_menu()


func festival(god: String) -> void:
	var err: String = city.festival(god)
	if err != "":
		hud.flash(err)


func back_to_menu() -> void:
	quit_to_menu.emit()
