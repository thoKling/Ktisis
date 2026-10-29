extends RefCounted
## Lit les définitions du jeu dans res://data (JSON) et construit le catalogue du domaine.

const Catalog = preload("res://src/domain/catalog.gd")

const DATA_DIR := "res://data"

static var _cache = null


## Catalogue du jeu, lu une seule fois.
static func load_catalog():
	if _cache == null:
		_cache = read(DATA_DIR)
	return _cache


static func read(dir: String):
	var data = read_json(dir + "/buildings.json")
	var gods = read_json(dir + "/gods.json")
	var index = read_json(dir + "/missions/index.json")
	var missions := []
	for f in index["missions"]:
		missions.append(read_json(dir + "/missions/" + f))
	return Catalog.new().fill(data, gods["gods"], missions)


static func read_json(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Fichier de données introuvable ou vide : %s" % path)
		return null
	var data = JSON.parse_string(text)
	if data == null:
		push_error("JSON invalide : %s" % path)
	return data
