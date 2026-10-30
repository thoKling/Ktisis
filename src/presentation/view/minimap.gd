extends Control
## Carte de la ville en réduction, dans le coin bas droit : terrain, routes, bâtiments et cadre de la vue.
## Un clic (ou un glisser) y déplace la caméra.

const Grid = preload("res://src/domain/world/grid.gd")
const Iso = preload("res://src/presentation/view/iso.gd")
const Art = preload("res://src/presentation/view/art.gd")
const UiTheme = preload("res://src/presentation/view/ui_theme.gd")

const ROAD := Color("#e6d6b0")
const VIEW_FRAME := Color("#fbf3e6")
## Les bâtiments changent aussi sans toucher à la carte (une maison qui grandit) : on repeint de temps en temps.
const REPAINT_TICKS := 20

var game

var _texture: ImageTexture
var _image: Image
var _painted_version := -1
var _painted_tick := -100
var _dragging := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Carte : cliquez pour y porter le regard."


func _process(_delta: float) -> void:
	if game == null or game.city == null:
		return
	var c = game.city
	if c.map_version != _painted_version or c.tick - _painted_tick >= REPAINT_TICKS:
		_paint(c)
	# Le cadre de la vue suit la caméra à chaque image.
	queue_redraw()


## Une case de la carte = un pixel de l'image, que _draw couche en losange.
func _paint(c) -> void:
	_painted_version = c.map_version
	_painted_tick = c.tick
	var g = c.grid
	if _image == null or _image.get_width() != g.width or _image.get_height() != g.height:
		_image = Image.create(g.width, g.height, false, Image.FORMAT_RGBA8)
		_texture = null
	for y in g.height:
		for x in g.width:
			var p := Vector2i(x, y)
			var col: Color = Art.TERRAIN_COLORS.get(g.terrain_at(p), Color.MAGENTA)
			if g.road_at(p) != Grid.R_NONE:
				col = ROAD
			_image.set_pixel(x, y, col)
	for b in c.buildings.values():
		var col: Color = Art.CATEGORY_COLORS.get(b.def.get("category", ""), Art.MARBLE)
		if b.def.get("category", "") == "habitat" and b.pop == 0:
			col = col.lerp(Art.MARBLE, 0.5)
		for dy in b.size:
			for dx in b.size:
				var p: Vector2i = b.pos + Vector2i(dx, dy)
				if g.in_bounds(p):
					_image.set_pixel(p.x, p.y, col)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


## Taille d'une demi-case à l'écran : le losange de la carte remplit le contrôle.
func _scale() -> float:
	var g = game.city.grid
	var n := float(g.width + g.height)
	return minf(size.x / n, size.y * 2.0 / n)


## Coin haut du losange (la case 0, 0).
func _origin() -> Vector2:
	var g = game.city.grid
	var s := _scale()
	var w := float(g.width + g.height) * s
	var h := w * 0.5
	return Vector2((size.x - w) * 0.5 + float(g.height) * s, (size.y - h) * 0.5)


## La carte est le monde réduit : un point du monde à l'écran garde sa place, à l'échelle près.
func _world_to_map(w: Vector2) -> Vector2:
	return _origin() + w * (_scale() / (Iso.TW * 0.5))


func _map_to_world(m: Vector2) -> Vector2:
	return (m - _origin()) * ((Iso.TW * 0.5) / _scale())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2620"))
	if _texture == null:
		return
	var s := _scale()
	# Axe x de la grille vers le bas à droite, axe y vers le bas à gauche.
	draw_set_transform_matrix(Transform2D(Vector2(s, s * 0.5), Vector2(-s, s * 0.5), _origin()))
	draw_texture(_texture, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var e := _world_to_map(Iso.to_screen(Vector2(game.city.entry) + Vector2(0.5, 0.5)))
	draw_circle(e, 3.0, Art.AEGEAN)
	draw_rect(_view_rect(), VIEW_FRAME, false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.INK_SOFT, false, 1.0)


## Ce que montre la caméra, ramené sur la carte.
func _view_rect() -> Rect2:
	var cam: Camera2D = game.camera
	var half := get_viewport_rect().size * 0.5 / cam.zoom
	var a := _world_to_map(cam.position - half)
	var b := _world_to_map(cam.position + half)
	return Rect2(a, b - a)


func look_at_map(m: Vector2) -> void:
	game.camera.position = _map_to_world(m)


func _gui_input(event: InputEvent) -> void:
	if game == null or _texture == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			look_at_map(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		look_at_map(event.position)
		accept_event()
