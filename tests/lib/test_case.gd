extends RefCounted
## Base des suites de tests : chaque méthode test_* est lancée par tests/run.gd.

const Fixtures = preload("res://tests/lib/fixtures.gd")

var failures := 0
var checks := 0
var current := ""


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  [%s] %s" % [current, msg])


func eq(actual, expected, msg: String) -> void:
	check(actual == expected, "%s : attendu %s, obtenu %s" % [msg, expected, actual])


## Pose un bâtiment et vérifie que la pose est acceptée.
func place_ok(c, type: String, p: Vector2i) -> void:
	var err: String = c.place(type, p)
	check(err == "", "pose de %s en %s : %s" % [type, p, err])
