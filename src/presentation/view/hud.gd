extends CanvasLayer
## Interface de jeu, construite en code : barre du haut, colonne de construction, panneau de mission, chronique.
## L'habillage (marbre, terre cuite, polices, icônes) vient de ui_theme.gd.

const UiTheme = preload("res://src/presentation/view/ui_theme.gd")
const Rules = preload("res://src/domain/rules.gd")
const BuildingInfo = preload("res://src/presentation/building_info.gd")

const CATEGORY_ICONS := {
	"routes": "road", "habitat": "house", "alimentation": "wheat", "industrie": "olive",
	"stockage": "amph", "services": "drop", "religion": "altar", "beaute": "cypress", "monuments": "temple",
}
## Icône du présent de chaque prétendant, sur l'écran de choix.
const GOD_ICONS := {"athena": "olive", "poseidon": "drop"}
const LOG_COLORS := {"good": UiTheme.GOOD, "bad": UiTheme.BAD, "warn": UiTheme.WARN}
const LOG_LINES := 4

var game

var _root: Control
var _money: Label
var _pop: Label
var _workers: Label
var _date: Label
var _speed_buttons := {}
var _overlay_button: Button
var _tool_buttons := {}
var _category_buttons := {}
var _open_category := ""
var _flyout: PanelContainer
var _flyout_title: Label
var _flyout_rows: VBoxContainer
var _build_rows := {}
var _objectives: VBoxContainer
var _stage_label: Label
var _god_rows := {}
var _info_title: Label
var _info_grid: GridContainer
var _info_hint: Label
var _info_lines := []
var _log_panel: PanelContainer
var _log: VBoxContainer
var _hover: PanelContainer
var _hover_label: Label
var _flash: PanelContainer
var _flash_label: Label
var _flash_t := 0.0
var _modal: Control


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	# Sans mipmaps : le marbre tuilé ne montre pas de joints.
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_root)
	_build_top_bar()
	_build_dock()
	_build_side()
	_build_log()
	_build_overlays()


# ---------------------------------------------------------------- Construction des panneaux

func _build_top_bar() -> void:
	var top := PanelContainer.new()
	top.theme_type_variation = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 50
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	top.add_child(row)
	_money = _resource(row, "coin", "Drachmes")
	_pop = _resource(row, "pop", "Population")
	_workers = _resource(row, "work", "Main-d'œuvre disponible et nécessaire")
	_date = _resource(row, "moon", "Date")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var speeds := _group(row)
	for s in [[0, "pause", "Pause (Espace)"], [1, "play1", "Vitesse normale (1)"], [2, "play2", "Vitesse x2 (2)"], [4, "play3", "Vitesse x4 (3)"]]:
		var b := _icon_button(s[1], s[2], func(): game.set_speed(s[0]))
		b.toggle_mode = true
		_speed_buttons[s[0]] = b
		speeds.add_child(b)
	var tools := _group(row)
	_overlay_button = _icon_button("eye", "Afficher la beauté du terrain (B)", func(): game.toggle_overlay())
	_overlay_button.text = "Beauté"
	_overlay_button.toggle_mode = true
	tools.add_child(_overlay_button)
	tools.add_child(_icon_button("scroll", "Sauver (F5)", func(): game.save_game()))
	tools.add_child(_icon_button("menu", "Retour au menu", func(): game.back_to_menu()))


func _build_dock() -> void:
	var dock := PanelContainer.new()
	dock.position = Vector2(12, 64)
	_root.add_child(dock)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	dock.add_child(box)
	_tool_buttons["select"] = _dock_button(box, "cursor", "Sélection (Échap)", func():
		game.set_tool("select")
		clear_build_menu())
	_tool_buttons["demolish"] = _dock_button(box, "pick", "Démolir (Suppr)", func():
		game.set_tool("demolish")
		clear_build_menu())
	box.add_child(HSeparator.new())
	var defs = game.city.catalog
	for cat in defs.categories:
		# Tout ce que la mission propose ; ce qui n'est pas encore permis (le temple d'un dieu non choisi) est filtré à l'ouverture.
		var types := []
		for id in defs.building_order:
			if defs.buildings[id]["category"] == cat["id"] and id in game.city.mission.get("buildings", []):
				types.append(id)
		if types.is_empty():
			continue
		var cat_id: String = cat["id"]
		var b := _dock_button(box, CATEGORY_ICONS.get(cat_id, "temple"), cat["name"], func(): _toggle_category(cat_id, cat["name"], types))
		_category_buttons[cat_id] = b

	_flyout = PanelContainer.new()
	_flyout.custom_minimum_size = Vector2(330, 0)
	_flyout.visible = false
	_root.add_child(_flyout)
	var fbox := VBoxContainer.new()
	fbox.add_theme_constant_override("separation", 4)
	_flyout.add_child(fbox)
	fbox.add_child(UiTheme.frieze())
	_flyout_title = _label("", "Title")
	fbox.add_child(_flyout_title)
	_flyout_rows = VBoxContainer.new()
	_flyout_rows.add_theme_constant_override("separation", 2)
	fbox.add_child(_flyout_rows)


func _build_side() -> void:
	var side := PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -362
	side.offset_right = -12
	side.offset_top = 64
	_root.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	side.add_child(box)
	box.add_child(UiTheme.frieze())
	var title := _label(game.city.mission.get("title", ""), "Title")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	_stage_label = _label("", "Muted")
	_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_label.visible = false
	box.add_child(_stage_label)
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 4)
	box.add_child(_objectives)

	box.add_child(HSeparator.new())
	box.add_child(_section("laurel", "Dieux"))
	for god in game.city.favor:
		box.add_child(_god_row(god))

	box.add_child(HSeparator.new())
	_info_title = _label("", "Section")
	_info_title.visible = false
	box.add_child(_info_title)
	_info_hint = _label("Cliquez sur un bâtiment pour voir sa fiche.", "Muted")
	_info_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info_hint)
	_info_grid = GridContainer.new()
	_info_grid.columns = 2
	_info_grid.add_theme_constant_override("h_separation", 12)
	_info_grid.add_theme_constant_override("v_separation", 2)
	box.add_child(_info_grid)


func _god_row(god: String) -> Control:
	var g: Dictionary = game.city.catalog.gods[god]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	var name := _label("", "")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name)
	var fest := Button.new()
	fest.text = "Fête · %d" % Rules.FESTIVAL_COST
	fest.focus_mode = Control.FOCUS_NONE
	fest.tooltip_text = "Offrir une fête à %s, %s : sa faveur grandit." % [g["name"], g.get("title", "")]
	fest.pressed.connect(func(): game.festival(god))
	grid.add_child(fest)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(bar)
	_god_rows[god] = {"name": name, "bar": bar}
	return grid


func _build_log() -> void:
	# Colonne invisible qui pousse la chronique contre le bas de l'écran, quelle que soit sa hauteur.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_bottom = -12
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	_log_panel = PanelContainer.new()
	_log_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_log_panel.custom_minimum_size = Vector2(640, 0)
	_log_panel.visible = false
	column.add_child(_log_panel)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 2)
	_log_panel.add_child(_log)


func _build_overlays() -> void:
	_hover = PanelContainer.new()
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.add_theme_stylebox_override("panel", UiTheme.theme().get_stylebox("panel", "TooltipPanel"))
	_hover.visible = false
	_root.add_child(_hover)
	_hover_label = _label("", "")
	_hover_label.add_theme_font_size_override("font_size", 15)
	_hover.add_child(_hover_label)

	_flash = PanelContainer.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash.offset_top = 66
	_flash.visible = false
	_root.add_child(_flash)
	_flash_label = _label("", "Strong")
	_flash_label.add_theme_color_override("font_color", UiTheme.TERRA)
	_flash.add_child(_flash_label)


# ---------------------------------------------------------------- Petits éléments

func _resource(parent: Control, icon: String, tip: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(UiTheme.icon_rect(icon))
	var l := _label("", "Strong")
	row.add_child(l)
	parent.add_child(row)
	return l


func _group(parent: Control) -> HBoxContainer:
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 4)
	parent.add_child(g)
	return g


func _icon_button(icon: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = UiTheme.icon(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 36)
	b.pressed.connect(cb)
	return b


func _dock_button(parent: Control, icon: String, tip: String, cb: Callable) -> Button:
	var b := _icon_button(icon, tip, cb)
	b.theme_type_variation = "Dock"
	b.custom_minimum_size = Vector2(50, 50)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.toggle_mode = true
	parent.add_child(b)
	return b


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


func _section(icon: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiTheme.icon_rect(icon, UiTheme.TERRA, 18))
	row.add_child(_label(text, "Section"))
	return row


func _build_row(id: String, icon: String) -> Button:
	var d: Dictionary = game.city.catalog.buildings[id]
	var b := Button.new()
	b.theme_type_variation = "Row"
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 38)
	b.tooltip_text = "%s\nTaille %dx%d, %d employés." % [d.get("desc", ""), d["size"], d["size"], d["workers"]]
	b.pressed.connect(func(): game.set_tool("build", id))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(UiTheme.icon_rect(icon, UiTheme.TERRA, 20))
	var name := _label(d["name"], "")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var cost := "%d" % d["cost"]
	if d.has("cost_res"):
		for r in d["cost_res"]:
			cost += " + %d %s" % [d["cost_res"][r], game.city.catalog.resource_name(r)]
	var cl := _label(cost, "")
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cl)
	row.add_child(UiTheme.icon_rect("coin", UiTheme.INK_SOFT, 15))
	return b


# ---------------------------------------------------------------- Menu de construction

func _toggle_category(cat_id: String, title: String, types: Array) -> void:
	if _open_category == cat_id:
		clear_build_menu()
		return
	_open_category = cat_id
	for c in _flyout_rows.get_children():
		c.queue_free()
	_build_rows.clear()
	for id in types:
		if not game.city.is_available(id):
			continue
		var row := _build_row(id, CATEGORY_ICONS.get(cat_id, "temple"))
		_build_rows[id] = row
		_flyout_rows.add_child(row)
	_flyout_title.text = title
	var anchor: Button = _category_buttons[cat_id]
	_flyout.position = Vector2(anchor.global_position.x + anchor.size.x + 22, anchor.global_position.y - 20)
	_flyout.reset_size()
	_flyout.visible = true


func clear_build_menu() -> void:
	_open_category = ""
	_flyout.visible = false


# ---------------------------------------------------------------- Mise à jour

func refresh() -> void:
	var c = game.city
	_money.text = _thousands(c.money)
	_pop.text = _thousands(c.population)
	_workers.text = "%d / %d" % [c.workers_available, c.workers_needed]
	_workers.add_theme_color_override("font_color", UiTheme.BAD if c.workers_available < c.workers_needed else UiTheme.INK)
	_date.text = BuildingInfo.date_text(c)
	for s in _speed_buttons:
		_speed_buttons[s].set_pressed_no_signal(game.speed == s)
	_overlay_button.set_pressed_no_signal(game.terrain_layer.overlay == "beauty")
	_tool_buttons["select"].set_pressed_no_signal(game.tool == "select" and _open_category == "")
	_tool_buttons["demolish"].set_pressed_no_signal(game.tool == "demolish")
	for cat in _category_buttons:
		_category_buttons[cat].set_pressed_no_signal(cat == _open_category)
	for id in _build_rows:
		_build_rows[id].set_pressed_no_signal(game.tool == "build" and game.build_type == id)
	_refresh_objectives(c)
	for god in _god_rows:
		var g: Dictionary = c.catalog.gods[god]
		var txt := "%s · faveur %d" % [g["name"], int(c.favor[god])]
		if c.patron == god:
			txt += " · protecteur"
		elif c.rival() == god:
			txt += " · jaloux"
		_god_rows[god]["name"].text = txt
		_god_rows[god]["bar"].value = c.favor[god]
	var b = game.selected_building()
	_show_info(BuildingInfo.lines(c, b) if b != null else [])
	_refresh_hover()
	if _flash_t > 0.0:
		_flash_t -= get_process_delta_time()
		if _flash_t <= 0.0:
			_flash.visible = false


func _refresh_objectives(c) -> void:
	var st: Dictionary = c.current_stage()
	_stage_label.visible = not st.is_empty()
	if not st.is_empty():
		_stage_label.text = "Étape %d sur %d · %s" % [st["index"] + 1, st["count"], st["title"]]
	var objs: Array = c.objectives()
	while _objectives.get_child_count() < objs.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiTheme.icon_rect("open", UiTheme.INK_SOFT, 18))
		var l := _label("", "")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_objectives.add_child(row)
	# Une étape peut avoir moins d'objectifs que la précédente.
	for i in _objectives.get_child_count():
		_objectives.get_child(i).visible = i < objs.size()
	for i in objs.size():
		var row := _objectives.get_child(i)
		var done: bool = objs[i]["done"]
		var ic: TextureRect = row.get_child(0)
		ic.texture = UiTheme.icon("check" if done else "open")
		ic.modulate = UiTheme.GOOD if done else UiTheme.INK_SOFT
		var l: Label = row.get_child(1)
		l.text = objs[i]["text"]
		l.add_theme_color_override("font_color", UiTheme.INK_SOFT if done else UiTheme.INK)


## Fiche du bâtiment choisi : la première ligne en titre, les « clé : valeur » en deux colonnes.
func _show_info(lines: Array) -> void:
	if lines == _info_lines:
		return
	_info_lines = lines.duplicate()
	_info_title.visible = not lines.is_empty()
	_info_hint.visible = lines.is_empty()
	for ch in _info_grid.get_children():
		ch.queue_free()
	if lines.is_empty():
		return
	_info_title.text = lines[0]
	for i in range(1, lines.size()):
		var line: String = lines[i]
		var parts := line.split(" : ", true, 1)
		if parts.size() == 2:
			var k := _label(parts[0].strip_edges(), "")
			k.add_theme_color_override("font_color", UiTheme.INK_SOFT)
			k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_info_grid.add_child(k)
			_info_grid.add_child(_label(parts[1], ""))
		else:
			var l := _label(line.strip_edges(), "")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(300, 0)
			_info_grid.add_child(l)
			_info_grid.add_child(Control.new())


func _refresh_hover() -> void:
	if not _hover.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var p := get_viewport().get_mouse_position() + Vector2(18, 22)
	p.x = minf(p.x, vp.x - _hover.size.x - 8)
	p.y = minf(p.y, vp.y - _hover.size.y - 8)
	_hover.position = p


func set_hover_text(t: String) -> void:
	_hover_label.text = t
	_hover.visible = t != "" and _modal == null
	_hover.reset_size()


func flash(t: String) -> void:
	_flash_label.text = t
	_flash.visible = true
	_flash.reset_size()
	_flash.offset_left = -_flash.size.x / 2.0
	_flash.offset_right = _flash.size.x / 2.0
	_flash_t = 3.0


func add_log(e: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var m: int = e.get("month", 0)
	var when := _label("An %d, mois %d" % [m / 12 + 1, m % 12 + 1], "Muted")
	when.custom_minimum_size = Vector2(96, 0)
	row.add_child(when)
	var l := _label(e["text"], "")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if LOG_COLORS.has(e["kind"]):
		l.add_theme_color_override("font_color", LOG_COLORS[e["kind"]])
	row.add_child(l)
	_log.add_child(row)
	while _log.get_child_count() > LOG_LINES:
		var first := _log.get_child(0)
		_log.remove_child(first)
		first.queue_free()
	_log_panel.visible = true


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------------------------------------------------------------- Fenêtres de récit

func show_intro(mission: Dictionary) -> void:
	var text := "\n\n".join(mission.get("intro", []))
	var tips: Array = mission.get("tips", [])
	if not tips.is_empty():
		text += "\n\nConseils :\n• " + "\n• ".join(tips)
	var st: Dictionary = game.city.current_stage()
	if not st.is_empty():
		text += "\n\nPremière étape · %s\n%s" % [st["title"], st["text"]]
	if game.city.needs_patron_choice():
		_show_modal(mission.get("title", ""), text, [], _patron_cards())
		return
	_show_modal(mission.get("title", ""), text, [["Commencer", func():
		_close_modal()
		game.set_speed(1)]])


## Début d'une étape : son récit, et les cartes des dieux si c'est l'heure du choix.
func show_stage(c) -> void:
	var st: Dictionary = c.current_stage()
	if st.is_empty():
		if c.needs_patron_choice():
			_show_modal(c.mission.get("title", ""), "", [], _patron_cards())
		return
	var title := "Étape %d sur %d · %s" % [st["index"] + 1, st["count"], st["title"]]
	if c.needs_patron_choice():
		_show_modal(title, st["text"], [], _patron_cards())
		return
	_show_modal(title, st["text"], [["Continuer", func():
		_close_modal()
		game.set_speed(1)]])


## Une carte par prétendant : son présent, ce qu'il demande, et le bouton qui le choisit.
func _patron_cards() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for o in game.city.patron_options():
		var god: String = o["god"]
		var g: Dictionary = game.city.catalog.gods[god]
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(UiTheme.icon_rect(GOD_ICONS.get(god, "laurel"), Color(g.get("color", "#a4462a")), 26))
		var name := _label(g["name"], "Title")
		head.add_child(name)
		box.add_child(head)
		var sub := _label(g.get("title", ""), "Muted")
		box.add_child(sub)
		var pitch := _label(o.get("pitch", ""), "")
		pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pitch.custom_minimum_size = Vector2(300, 0)
		pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(pitch)
		var b := Button.new()
		b.text = "Choisir %s" % g["name"]
		b.theme_type_variation = "Primary"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func():
			game.choose_patron(god)
			_close_modal()
			game.set_speed(1))
		box.add_child(b)
	return row


func show_victory(mission: Dictionary, has_next: bool) -> void:
	var buttons := [["Menu", func(): game.back_to_menu()], ["Continuer à bâtir", func(): _close_modal()]]
	var title := "Victoire : %s" % mission.get("title", "")
	var text: String = mission.get("outro", "")
	if has_next:
		text += "\n\nLa mission suivante est débloquée dans le menu."
	_show_modal(title, text, buttons)


## La dernière action est l'action principale, en terre cuite.
func _show_modal(title: String, text: String, buttons: Array, extra: Control = null) -> void:
	_close_modal()
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.04, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_modal = bg
	_hover.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UiTheme.frieze())
	var t := _label(title, "Title")
	t.add_theme_font_size_override("font_size", 30)
	box.add_child(t)
	var body := _label(text, "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	body.add_theme_constant_override("line_spacing", 3)
	box.add_child(body)
	if extra != null:
		box.add_child(extra)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	for i in buttons.size():
		var b := Button.new()
		b.text = buttons[i][0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		if i == buttons.size() - 1:
			b.theme_type_variation = "Primary"
		b.pressed.connect(buttons[i][1])
		row.add_child(b)
	box.add_child(row)


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func has_modal() -> bool:
	return _modal != null
