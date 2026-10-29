extends "res://tests/lib/test_case.gd"
## Règles d'architecture : le domaine ne connaît ni Godot (nœuds, fichiers, entrées) ni les autres couches ;
## l'infrastructure ne connaît pas la présentation.

const FORBIDDEN_IN_DOMAIN := ["FileAccess", "DirAccess", "extends Node", "Input.", "DisplayServer", "user://",
	"res://data", "res://assets", "res://src/infrastructure", "res://src/presentation", "get_tree("]


func _files(dir: String) -> Array:
	var res := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			res.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		res += _files(dir + "/" + d)
	return res


func test_domain_is_pure() -> void:
	var load_call := RegEx.create_from_string("(?<!pre)load\\(")
	var files := _files("res://src/domain")
	check(files.size() > 10, "fichiers du domaine trouvés")
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		for word in FORBIDDEN_IN_DOMAIN:
			check(not word in text, "%s utilise %s" % [f, word])
		check(load_call.search(text) == null, "%s charge une ressource à l'exécution" % f)


func test_infrastructure_ignores_presentation() -> void:
	for f in _files("res://src/infrastructure"):
		check(not "res://src/presentation" in FileAccess.get_file_as_string(f), "%s dépend de la présentation" % f)
