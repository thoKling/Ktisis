extends Node
## Menu principal et passage d'une mission à l'autre.

const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")
const FileStore = preload("res://src/infrastructure/file_store.gd")
const Game = preload("res://src/presentation/game.gd")
const UiTheme = preload("res://src/presentation/view/ui_theme.gd")

var game
var menu: CanvasLayer


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	if game != null:
		game.queue_free()
		game = null
	if menu != null:
		menu.queue_free()
	menu = CanvasLayer.new()
	add_child(menu)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	# Sans mipmaps : le marbre tuilé ne montre pas de joints.
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	menu.add_child(root)
	# Fond : une Thèbes construite, voilée pour faire ressortir la stèle.
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0.16, 0.11, 0.06, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(UiTheme.frieze())
	var title := Label.new()
	title.text = "Ktisis"
	title.theme_type_variation = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "La fondation des cités, sous le regard des dieux"
	sub.theme_type_variation = "Muted"
	sub.add_theme_font_size_override("font_size", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UiTheme.frieze())
	var missions: Array = CatalogLoader.load_catalog().missions
	var open := FileStore.unlocked_missions()
	for i in missions.size():
		var b := _menu_button("%d. %s" % [i + 1, missions[i]["title"]], func(): start_mission(i))
		b.disabled = i >= open
		if b.disabled:
			b.tooltip_text = "Terminez la mission précédente pour la débloquer."
		box.add_child(b)
	var load_b := _menu_button("Reprendre la partie sauvegardée", load_saved)
	load_b.icon = UiTheme.icon("scroll")
	load_b.disabled = not FileStore.has_save()
	box.add_child(load_b)
	box.add_child(_menu_button("Quitter", func(): get_tree().quit()))


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func start_mission(index: int, loaded_city = null) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	game = Game.new()
	game.setup(index, loaded_city)
	game.quit_to_menu.connect(show_menu)
	game.mission_won.connect(_on_won)
	add_child(game)


func load_saved() -> void:
	var c = FileStore.load_city(CatalogLoader.load_catalog())
	if c == null:
		return
	start_mission(CatalogLoader.load_catalog().mission_index(c.mission["id"]), c)


func _on_won(index: int) -> void:
	if index + 2 > FileStore.unlocked_missions():
		FileStore.set_unlocked_missions(mini(index + 2, CatalogLoader.load_catalog().missions.size()))
