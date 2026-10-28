extends "res://tests/run_tests.gd"
## Capture d'écran d'une Thèbes construite automatiquement (nécessite un affichage, par ex. xvfb-run) :
##   xvfb-run godot --path . -s res://tests/screenshot.gd -- sortie.png [mois]

const Iso = preload("res://scripts/view/iso.gd")

var main
var frame := 0
var out_path := "user://capture.png"
var months := 10


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	months = int(args[1]) if args.size() > 1 else 10
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _setup() -> void:
	main.start_mission(0)
	var g = main.game
	build_thebes(g.city)
	g.city.run_months(months)
	g.hud._close_modal()
	g.set_speed(1)
	g.camera.position = Iso.to_screen(Vector2(18, g.city.entry.y))
	g.camera.zoom = Vector2(1.1, 1.1)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		_setup()
	if frame == 25:
		main.game.hud._close_modal()
	if frame == 30:
		var b = main.game.city.building_at(Vector2i(7, main.game.city.entry.y - 8))
		if b != null:
			main.game.selected_id = b.id
	if frame == 40:
		var img := root.get_texture().get_image()
		img.save_png(out_path)
		print("capture : ", out_path)
		quit(0)
	return false
