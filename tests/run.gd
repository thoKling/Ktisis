extends SceneTree
## Lance les suites de tests sans écran :
##   godot --headless --path . -s res://tests/run.gd                  (domaine puis contenu)
##   godot --headless --path . -s res://tests/run.gd -- domain        (un seul dossier)
##   godot --headless --path . -s res://tests/run.gd -- domain grid   (suites dont le nom contient « grid »)

const DIRS := ["domain", "content"]

var failures := 0
var checks := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dirs: Array = [args[0]] if args.size() > 0 else DIRS
	var filter: String = args[1] if args.size() > 1 else ""
	for dir in dirs:
		for file in _suites("res://tests/%s" % dir):
			if filter == "" or filter in file:
				_run_suite("res://tests/%s/%s" % [dir, file])
	print("%d vérifications, %d échecs" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _suites(dir: String) -> Array:
	var res := []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			res.append(f)
	res.sort()
	return res


func _run_suite(path: String) -> void:
	var suite = load(path).new()
	print("— %s" % path.get_file().get_basename())
	for m in suite.get_script().get_script_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		suite.current = name
		var before: int = suite.failures
		suite.call(name)
		print("  %s %s" % ["OK   " if suite.failures == before else "ÉCHEC", name])
	failures += suite.failures
	checks += suite.checks
