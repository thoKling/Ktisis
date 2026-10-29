extends SceneTree
## Lance la scène principale sans écran, démarre chaque mission et simule des clics.
##   godot --headless --path . -s res://tests/presentation/smoke.gd

const Iso = preload("res://src/presentation/view/iso.gd")

var main
var frame := 0
var mission := 0
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	var step := frame % 120
	if step == 2:
		main.start_mission(mission)
	elif step == 3:
		var g = main.game
		g.hud._close_modal()
		g.camera.position = Iso.to_screen(Vector2(12, g.city.entry.y))
	elif step == 5:
		var g = main.game
		g.set_speed(4)
		var y: int = g.city.entry.y
		# Une route tracée au glisser puis des maisons.
		g.set_tool("build", "road")
		_click(g, Vector2i(3, y), true)
		_click(g, Vector2i(20, y), false)
		g.set_tool("build", "house")
		_click(g, Vector2i(5, y + 1), true)
		_click(g, Vector2i(12, y + 2), false)
		g.set_tool("build", "fountain")
		_click(g, Vector2i(14, y + 1), true)
		_click(g, Vector2i(14, y + 1), false)
		g.toggle_overlay()
		g.set_tool("select")
		_click(g, Vector2i(5, y + 1), true)
	elif step == 100:
		var g = main.game
		if g.city.buildings.size() < 4:
			printerr("mission %d : les clics n'ont rien construit (%d bâtiments)" % [mission, g.city.buildings.size()])
			failures += 1
		if g.selected_id == -1:
			printerr("mission %d : la sélection ne marche pas" % mission)
			failures += 1
		g.save_game()
		g.back_to_menu()
		print("mission %d : %d bâtiments, %d marcheurs, tick %d" % [mission, g.city.buildings.size(), g.city.walkers.size(), g.city.tick])
		mission += 1
		if mission >= 3:
			main.load_saved()
	elif step == 110 and mission >= 3:
		if main.game == null:
			printerr("la sauvegarde ne se recharge pas")
			failures += 1
		print("smoke : %d échecs" % failures)
		quit(1 if failures > 0 else 0)
	return false


func _click(g, tile: Vector2i, press: bool) -> void:
	var world := Iso.to_screen(Vector2(tile) + Vector2(0.5, 0.5))
	var screen: Vector2 = g.get_viewport().get_canvas_transform() * world
	var mm := InputEventMouseMotion.new()
	mm.position = screen
	mm.global_position = screen
	root.push_input(mm)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = press
	ev.position = screen
	ev.global_position = screen
	root.push_input(ev)
