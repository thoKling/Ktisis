extends RefCounted
## Définitions du jeu : bâtiments, ressources, catégories, dieux et missions.
## Construit à partir de dictionnaires (lus en JSON par l'infrastructure, ou écrits à la main dans les tests).
## Les nombres JSON arrivent en flottants : on les convertit ici une fois pour toutes.

const INT_KEYS := ["size", "cost", "workers", "amount", "cycle", "capacity", "range", "input_amount",
	"near_radius", "beauty_radius", "stage_ticks", "risk"]

var buildings := {}
var building_order := []
var categories := []
var resources := {}
var gods := {}
var missions := []


## data : {"resources", "categories", "buildings"} ; gods : liste ; missions : liste.
## Usage : Catalog.new().fill(data, gods, missions).
func fill(data: Dictionary, gods_list: Array, missions_list: Array):
	resources = data.get("resources", {})
	categories = data.get("categories", [])
	for b in data.get("buildings", []):
		var d: Dictionary = b.duplicate(true)
		_normalize_building(d)
		buildings[d["id"]] = d
		building_order.append(d["id"])
	for g in gods_list:
		gods[g["id"]] = g
	missions = missions_list
	return self


static func _normalize_building(b: Dictionary) -> void:
	for k in INT_KEYS:
		if b.has(k):
			b[k] = int(b[k])
	for k in ["size"]:
		if not b.has(k):
			b[k] = 1
	for k in ["cost", "workers", "beauty", "beauty_radius", "risk"]:
		if not b.has(k):
			b[k] = 0
	b["beauty"] = float(b["beauty"])
	if not b.has("category"):
		b["category"] = ""
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


func house_levels() -> Array:
	return building("house").get("levels", [])


func resource_name(id: String) -> String:
	if resources.has(id):
		return resources[id]["name"]
	return id


func god_name(id: String) -> String:
	return gods[id]["name"] if gods.has(id) else id


## « d'Athéna », « de Poséidon ».
func god_of(id: String) -> String:
	var n := god_name(id)
	return ("d'" if n.left(1) in ["A", "E", "É", "H", "I", "O", "U"] else "de ") + n


## Accord au féminin : agree(id, "offensé", "offensée").
func agree(id: String, masculine: String, feminine: String) -> String:
	return feminine if gods.get(id, {}).get("female", false) else masculine


func mission(id: String) -> Dictionary:
	for m in missions:
		if m["id"] == id:
			return m
	return {}


func mission_index(id: String) -> int:
	for i in missions.size():
		if missions[i]["id"] == id:
			return i
	return -1
