extends RefCounted
## Identité de l'interface, « stèle de marbre » : panneaux de marbre, méandre et boutons actifs en terre cuite,
## titres en Marcellus SC, texte en Alegreya Sans. Textures générées par tools/art/ui.py.

const DIR := "res://assets/ui/"

const INK := Color("#3a2e24")
const INK_SOFT := Color("#6b5d4c")
const TERRA := Color("#a4462a")
const TERRA_LIGHT := Color("#fbf3e6")
const STONE := Color("#d6cab2")
const GOOD := Color("#4f6a24")
const BAD := Color("#a3301f")
const WARN := Color("#8d5a10")

const ICON_SIZE := 22
const PANEL_MARGIN := 12   # bordure de panel.png (ombre + filets)
const PANEL_SHADOW := 6

static var _theme: Theme
static var _icons := {}


static func font(name: String) -> Font:
	return load(DIR + "fonts/" + name + ".ttf")


static func title_font() -> Font:
	return font("MarcellusSC-Regular")


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load(DIR + "icons/" + name + ".svg")
	return _icons[name]


## Thème partagé par le HUD, le menu et les fenêtres de récit.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("AlegreyaSans-Regular")
	t.default_font_size = 17

	t.set_stylebox("panel", "PanelContainer", _panel_box())
	t.set_stylebox("panel", "TopBar", _top_box())
	t.set_type_variation("TopBar", "PanelContainer")

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", title_font())
	t.set_font_size("font_size", "Title", 21)
	t.set_color("font_color", "Title", TERRA)
	t.set_type_variation("Section", "Label")
	t.set_font("font", "Section", title_font())
	t.set_font_size("font_size", "Section", 17)
	t.set_color("font_color", "Section", TERRA)
	t.set_type_variation("Strong", "Label")
	t.set_font("font", "Strong", font("AlegreyaSans-Bold"))
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", INK_SOFT)
	t.set_font_size("font_size", "Muted", 15)

	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "Button", _button_box(s))
	t.set_stylebox("hover_pressed", "Button", _button_box("pressed"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", TERRA_LIGHT)
	t.set_color("font_hover_pressed_color", "Button", TERRA_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(INK_SOFT, 0.6))
	t.set_color("icon_normal_color", "Button", TERRA)
	t.set_color("icon_hover_color", "Button", TERRA)
	t.set_color("icon_focus_color", "Button", TERRA)
	t.set_color("icon_pressed_color", "Button", TERRA_LIGHT)
	t.set_color("icon_hover_pressed_color", "Button", TERRA_LIGHT)
	t.set_color("icon_disabled_color", "Button", Color(INK_SOFT, 0.5))
	t.set_constant("h_separation", "Button", 7)
	t.set_constant("icon_max_width", "Button", 18)
	# Bouton d'action principale (« Commencer ») : toujours en terre cuite.
	t.set_type_variation("Primary", "Button")
	for s in ["normal", "hover", "pressed"]:
		t.set_stylebox(s, "Primary", _button_box("pressed"))
	t.set_color("font_color", "Primary", TERRA_LIGHT)
	t.set_color("font_hover_color", "Primary", Color.WHITE)
	# Colonne de construction : grandes icônes carrées.
	t.set_type_variation("Dock", "Button")
	t.set_constant("icon_max_width", "Dock", 26)
	# Ligne d'un bâtiment dans le volet : sans cadre tant qu'on ne la survole pas.
	t.set_type_variation("Row", "Button")
	t.set_stylebox("normal", "Row", StyleBoxEmpty.new())
	t.set_stylebox("hover", "Row", _flat(Color(TERRA, 0.10), Color(TERRA, 0.0), 0))
	t.set_stylebox("pressed", "Row", _flat(Color(TERRA, 0.16), Color(TERRA, 0.0), 0))
	t.set_stylebox("hover_pressed", "Row", _flat(Color(TERRA, 0.16), Color(TERRA, 0.0), 0))
	t.set_color("font_pressed_color", "Row", INK)

	var bar_bg := _flat(STONE, STONE, 4)
	bar_bg.set_content_margin_all(0)
	var bar_fill := _flat(Color("#b6553a"), Color("#b6553a"), 4)
	bar_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("separator", "HSeparator", _line(Color("#c9bb9f")))

	t.set_stylebox("panel", "TooltipPanel", _flat(Color("#f4efe4"), Color("#a8977a"), 3))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 15)
	_theme = t
	return t


## Frise de méandre, sur toute la largeur de son conteneur.
static func frieze() -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(DIR + "frieze.png")
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = Vector2(0, 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Icône teintée, pour les libellés (ressources, objectifs...).
static func icon_rect(name: String, color: Color = TERRA, size: int = ICON_SIZE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _panel_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + "panel.png")
	sb.set_texture_margin_all(PANEL_MARGIN)
	sb.set_expand_margin_all(PANEL_SHADOW)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.set_content_margin_all(12)
	return sb


static func _top_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + "topbar.png")
	sb.texture_margin_top = 4
	sb.texture_margin_bottom = 12
	sb.expand_margin_bottom = 10
	sb.content_margin_left = 18
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func _button_box(state: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + "button_%s.png" % state)
	sb.set_texture_margin_all(4)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	if border.a > 0.0:
		sb.set_border_width_all(1)
	return sb


static func _line(c: Color) -> StyleBoxLine:
	var sb := StyleBoxLine.new()
	sb.color = c
	sb.thickness = 1
	return sb
