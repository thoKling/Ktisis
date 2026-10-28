extends CanvasLayer
## Interface de jeu, construite en code : barre du haut, menu de construction, objectifs, dieux, journal.

const Art = preload("res://scripts/view/art.gd")

var game

var _top_label: Label
var _gods_box: VBoxContainer
var _god_labels := {}
var _objectives: Label
var _info: Label
var _hover: Label
var _flash: Label
var _flash_t := 0.0
var _log: VBoxContainer
var _build_list: VBoxContainer
var _speed_buttons := {}
var _modal: Control


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Barre du haut.
	var top := _panel(root)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 40
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top.add_child(top_row)
	_top_label = Label.new()
	_top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_top_label)
	for s in [[0, "Pause"], [1, "x1"], [2, "x2"], [4, "x4"]]:
		var b := _button(s[1], func(): game.set_speed(s[0]))
		b.toggle_mode = true
		_speed_buttons[s[0]] = b
		top_row.add_child(b)
	top_row.add_child(_button("Beauté (B)", func(): game.toggle_overlay()))
	top_row.add_child(_button("Sauver (F5)", func(): game.save_game()))
	top_row.add_child(_button("Menu", func(): game.back_to_menu()))

	# Menu de construction à gauche.
	var left := _panel(root)
	left.position = Vector2(8, 52)
	left.custom_minimum_size = Vector2(190, 0)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	left_box.add_child(_title("Construire"))
	left_box.add_child(_button("Sélection (Échap)", func():
		game.set_tool("select")
		clear_build_menu()))
	left_box.add_child(_button("Démolir (Suppr)", func():
		game.set_tool("demolish")
		clear_build_menu()))
	var defs = game.city.defs
	for cat in defs.categories:
		var types := []
		for id in defs.building_order:
			if defs.buildings[id]["category"] == cat["id"] and game.city.is_available(id):
				types.append(id)
		if types.is_empty():
			continue
		left_box.add_child(_button(cat["name"], func(): _open_category(types)))

	var build_panel := _panel(root)
	build_panel.position = Vector2(206, 52)
	_build_list = VBoxContainer.new()
	build_panel.add_child(_build_list)
	build_panel.visible = false
	_build_list.set_meta("panel", build_panel)

	# Colonne de droite : objectifs, dieux, bâtiment choisi.
	var right := _panel(root)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -330
	right.offset_right = -8
	right.offset_top = 52
	var right_box := VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(310, 0)
	right.add_child(right_box)
	right_box.add_child(_title(game.city.mission.get("title", "")))
	_objectives = Label.new()
	right_box.add_child(_objectives)
	right_box.add_child(HSeparator.new())
	right_box.add_child(_title("Dieux"))
	_gods_box = VBoxContainer.new()
	right_box.add_child(_gods_box)
	for god in game.city.favor:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_god_labels[god] = l
		row.add_child(l)
		row.add_child(_button("Fête (%d)" % game.city.FESTIVAL_COST, func(): game.festival(god)))
		_gods_box.add_child(row)
	right_box.add_child(HSeparator.new())
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(_info)

	# Bas : survol, message bref et journal.
	var bottom := _panel(root)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_top = -150
	bottom.offset_bottom = -8
	bottom.offset_left = 8
	bottom.offset_right = 640
	var bottom_box := VBoxContainer.new()
	bottom.add_child(bottom_box)
	_hover = Label.new()
	bottom_box.add_child(_hover)
	_flash = Label.new()
	_flash.add_theme_color_override("font_color", Color("#ffcf6b"))
	bottom_box.add_child(_flash)
	_log = VBoxContainer.new()
	bottom_box.add_child(_log)


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.13, 0.85)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Art.OCHRE)
	return l


func _open_category(types: Array) -> void:
	for c in _build_list.get_children():
		c.queue_free()
	var defs = game.city.defs
	for id in types:
		var d: Dictionary = defs.buildings[id]
		var label := "%s  (%d)" % [d["name"], d["cost"]]
		if d.has("cost_res"):
			for r in d["cost_res"]:
				label += " + %d %s" % [d["cost_res"][r], defs.resource_name(r)]
		var b := _button(label, func(): game.set_tool("build", id))
		b.tooltip_text = "%s\nTaille %dx%d, %d employés." % [d.get("desc", ""), d["size"], d["size"], d["workers"]]
		_build_list.add_child(b)
	_build_list.get_meta("panel").visible = true


func clear_build_menu() -> void:
	_build_list.get_meta("panel").visible = false


func refresh() -> void:
	var c = game.city
	_top_label.text = "Drachmes : %d     Population : %d     Main-d'œuvre : %d (besoin %d)     %s" % [
		c.money, c.population, c.workers_available, c.workers_needed, c.date_text()]
	for s in _speed_buttons:
		_speed_buttons[s].button_pressed = game.speed == s
	var lines := []
	for o in c.objectives():
		lines.append(("[fait] " if o["done"] else "- ") + o["text"])
	_objectives.text = "\n".join(lines)
	for god in _god_labels:
		var g: Dictionary = c.defs.gods[god]
		var txt := "%s : faveur %d" % [g["name"], int(c.favor[god])]
		if c.patron == god:
			txt += " (patron)"
		_god_labels[god].text = txt
	var b = game.selected_building()
	_info.text = "\n".join(c.building_info(b)) if b != null else "Cliquez sur un bâtiment pour le détail."
	if _flash_t > 0.0:
		_flash_t -= get_process_delta_time()
		if _flash_t <= 0.0:
			_flash.text = ""


func set_hover_text(t: String) -> void:
	_hover.text = t


func flash(t: String) -> void:
	_flash.text = t
	_flash_t = 3.0


func add_log(e: Dictionary) -> void:
	var l := Label.new()
	var m: int = e.get("month", 0)
	l.text = "[An %d, mois %d] %s" % [m / 12 + 1, m % 12 + 1, e["text"]]
	var colors := {"good": Color("#9fe39f"), "bad": Color("#ff8f80"), "warn": Color("#ffcf6b")}
	if colors.has(e["kind"]):
		l.add_theme_color_override("font_color", colors[e["kind"]])
	_log.add_child(l)
	while _log.get_child_count() > 4:
		var first := _log.get_child(0)
		_log.remove_child(first)
		first.queue_free()


# ---------------------------------------------------------------- Fenêtres de récit

func show_intro(mission: Dictionary) -> void:
	var text := "\n\n".join(mission.get("intro", []))
	var tips: Array = mission.get("tips", [])
	if not tips.is_empty():
		text += "\n\nConseils :\n- " + "\n- ".join(tips)
	_show_modal(mission.get("title", ""), text, [["Commencer", func():
		_close_modal()
		game.set_speed(1)]])


func show_victory(mission: Dictionary, has_next: bool) -> void:
	var buttons := [["Continuer à bâtir", func(): _close_modal()]]
	buttons.append(["Menu", func(): game.back_to_menu()])
	var title := "Victoire : %s" % mission.get("title", "")
	var text: String = mission.get("outro", "")
	if has_next:
		text += "\n\nLa mission suivante est débloquée dans le menu."
	_show_modal(title, text, buttons)


func _show_modal(title: String, text: String, buttons: Array) -> void:
	_close_modal()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_modal = bg
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var panel := _panel(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var t := _title(title)
	t.add_theme_font_size_override("font_size", 24)
	box.add_child(t)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 0)
	box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	for b in buttons:
		row.add_child(_button(b[0], b[1]))
	box.add_child(row)


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func has_modal() -> bool:
	return _modal != null
