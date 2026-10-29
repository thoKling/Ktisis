extends Node
## Menu principal et passage d'une mission à l'autre.

const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")
const FileStore = preload("res://src/infrastructure/file_store.gd")
const Game = preload("res://src/presentation/game.gd")
const Art = preload("res://src/presentation/view/art.gd")

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
	var bg := ColorRect.new()
	bg.color = Color("#1e2430")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "KTISIS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Art.MARBLE)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "La fondation des cités, sous le regard des dieux"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Art.OCHRE)
	box.add_child(sub)
	box.add_child(HSeparator.new())
	var missions: Array = CatalogLoader.load_catalog().missions
	var open := FileStore.unlocked_missions()
	for i in missions.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, missions[i]["title"]]
		b.disabled = i >= open
		b.pressed.connect(func(): start_mission(i))
		box.add_child(b)
	var load_b := Button.new()
	load_b.text = "Reprendre la partie sauvegardée"
	load_b.disabled = not FileStore.has_save()
	load_b.pressed.connect(load_saved)
	box.add_child(load_b)
	var quit_b := Button.new()
	quit_b.text = "Quitter"
	quit_b.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_b)


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
