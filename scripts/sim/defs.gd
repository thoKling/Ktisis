extends RefCounted
## Données du jeu (bâtiments, ressources, dieux, missions), lues depuis res://data.
## Les nombres JSON arrivent en flottants : on les convertit ici une fois pour toutes.

const T_GRASS := 0
const T_WATER := 1
const T_FOREST := 2
const T_ROCK := 3
const T_MEADOW := 4

const TERRAIN_NAMES := {"grass": T_GRASS, "water": T_WATER, "forest": T_FOREST, "rock": T_ROCK, "meadow": T_MEADOW}

const INT_KEYS := ["size", "cost", "workers", "amount", "cycle", "capacity", "range", "input_amount",
	"near_radius", "beauty_radius", "stage_ticks", "risk"]

static var _cache = null

var buildings := {}
var building_order := []
var categories := []
var resources := {}
var gods := {}
var missions := []


static func get_defs():
	if _cache == null:
		_cache = load("res://scripts/sim/defs.gd").new()
		_cache.load_all()
	return _cache


static func read_json(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Fichier de données introuvable ou vide : %s" % path)
		return null
	var data = JSON.parse_string(text)
	if data == null:
		push_error("JSON invalide : %s" % path)
	return data


func load_all() -> void:
	var data = read_json("res://data/buildings.json")
	resources = data["resources"]
	categories = data["categories"]
	for b in data["buildings"]:
		_normalize_building(b)
		buildings[b["id"]] = b
		building_order.append(b["id"])
	var g = read_json("res://data/gods.json")
	for god in g["gods"]:
		gods[god["id"]] = god
	var index = read_json("res://data/missions/index.json")
	for f in index["missions"]:
		missions.append(read_json("res://data/missions/" + f))


func _normalize_building(b: Dictionary) -> void:
	for k in INT_KEYS:
		if b.has(k):
			b[k] = int(b[k])
	if not b.has("size"):
		b["size"] = 1
	for k in ["cost", "workers", "beauty", "beauty_radius", "risk"]:
		if not b.has(k):
			b[k] = 0
	b["beauty"] = float(b["beauty"])
	for k in ["wants", "cost_res"]:
		if b.has(k):
			for r in b[k].keys():
				b[k][r] = int(b[k][r])
	if b.has("stages"):
		for st in b["stages"]:
			for r in st.keys():
				st[r] = int(st[r])
	if b.has("levels"):
		for lv in b["levels"]:
			lv["cap"] = int(lv["cap"])
			lv["tax"] = float(lv["tax"])
			if lv["needs"].has("beauty"):
				lv["needs"]["beauty"] = float(lv["needs"]["beauty"])


func building(id: String) -> Dictionary:
	return buildings.get(id, {})


func resource_name(id: String) -> String:
	if resources.has(id):
		return resources[id]["name"]
	return id


func is_food(res: String) -> bool:
	return resources.has(res) and resources[res]["kind"] == "food"


func mission_index(id: String) -> int:
	for i in missions.size():
		if missions[i]["id"] == id:
			return i
	return -1
