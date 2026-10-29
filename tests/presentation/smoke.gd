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
		# Mission en étapes avec un jugement : on saute à l'étape du choix, le jeu doit l'afficher.
		var stages: Array = g.city.mission.get("stages", [])
		for i in stages.size():
			for o in stages[i]["objectives"]:
				if o["type"] == "patron":
					g.city.stage = i
		# Sur le plateau de la colline, relevé, la souris doit viser la bonne tuile
		# (les pentes tournées vers le fond sont en partie cachées par les tuiles de devant).
		for y in g.city.grid.height:
			for x in g.city.grid.width:
				var q := Vector2i(x, y)
				var top: float = g.relief.corner(x, y)
				var plateau: bool = top > 0.0 and g.relief.corner(x + 1, y + 1) == top and g.relief.corner(x + 1, y) == top \
					and g.relief.corner(x, y + 1) == top
				if plateau and g.relief.tile_at(g.relief.to_screen(Vector2(q) + Vector2(0.5, 0.5))) != q:
					printerr("mission %d : la tuile %s de la colline est mal visée" % [mission, q])
					failures += 1
		g.camera.position = Iso.to_screen(Vector2(12, g.city.entry.y))
	elif step == 5:
		var g = main.game
		if g.city.needs_patron_choice():
			# L'écran de choix : on prend le second prétendant, par son bouton.
			if not g.hud.has_modal():
				printerr("mission %d : l'étape du choix ne s'affiche pas" % mission)
				failures += 1
			else:
				var buttons: Array = g.hud._modal.find_children("*", "Button", true, false)
				buttons[buttons.size() - 1].pressed.emit()
			if g.city.patron == "":
				printerr("mission %d : le choix du protecteur ne marche pas" % mission)
				failures += 1
		g.hud._close_modal()
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
	var world: Vector2 = g.relief.to_screen(Vector2(tile) + Vector2(0.5, 0.5))
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
