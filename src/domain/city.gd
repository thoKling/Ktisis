extends RefCounted
## Une cité en cours de partie : l'état du monde et le point d'entrée du domaine.
## La simulation avance par pas fixes (step) et ne dépend ni de Godot (nœuds, fichiers) ni de l'affichage.
## Les règles vivent dans systems/ ; cette classe les orchestre et expose commandes et requêtes.

const Rules = preload("res://src/domain/rules.gd")
const Grid = preload("res://src/domain/world/grid.gd")
const Walker = preload("res://src/domain/world/walker.gd")
const MapGenerator = preload("res://src/domain/world/map_generator.gd")
const Access = preload("res://src/domain/systems/access.gd")
const Beauty = preload("res://src/domain/systems/beauty.gd")
const Construction = preload("res://src/domain/systems/construction.gd")
const Effects = preload("res://src/domain/systems/effects.gd")
const Hazards = preload("res://src/domain/systems/hazards.gd")
const Housing = preload("res://src/domain/systems/housing.gd")
const Labor = preload("res://src/domain/systems/labor.gd")
const Logistics = preload("res://src/domain/systems/logistics.gd")
const Monuments = preload("res://src/domain/systems/monuments.gd")
const Objectives = preload("res://src/domain/systems/objectives.gd")
const Religion = preload("res://src/domain/systems/religion.gd")
const Services = preload("res://src/domain/systems/services.gd")

var catalog
var mission := {}
var grid: Grid
var entry := Vector2i.ZERO
var rng := RandomNumberGenerator.new()

var buildings := {}
var next_id := 1
var walkers := {}
var next_walker_id := 1

var money := 0
var tick := 0
var months := 0
var population := 0
var workers_available := 0
var workers_needed := 0

var beauty := PackedFloat32Array()
var beauty_dirty := true

var favor := {}
var god_cd := {}
var effects := []
var patron := ""
## Étape en cours, pour une mission en plusieurs étapes.
var stage := 0
var won := false

## Journal des événements : {"text", "kind" (info, good, warn, bad), "month"}.
var events := []
## Change à chaque modification visible de la carte (routes, bâtiments).
var map_version := 0

var access_cache := {}
var entry_warned_month := -100
var labor_warned_month := -100


## catalog : définitions du jeu ; mission : dictionnaire de mission (carte, dieux, objectifs...).
func _init(p_catalog = null, p_mission: Dictionary = {}) -> void:
	catalog = p_catalog
	if p_mission.is_empty():
		return
	mission = p_mission
	var gen := MapGenerator.generate(mission["map"])
	grid = gen["grid"]
	entry = gen["entry"]
	money = int(mission.get("start_money", 2000))
	rng.seed = int(mission["map"].get("seed", 1)) * 31 + 7
	Religion.setup(self, mission.get("gods", []))
	for x in range(0, 4):
		grid.set_road(Vector2i(x, entry.y), Grid.R_ROAD)


# ---------------------------------------------------------------- Temps

func step() -> void:
	tick += 1
	if beauty_dirty:
		Beauty.recompute(self)
	if tick % Rules.LABOR_PERIOD == 0:
		Labor.allocate(self)
	for b in buildings.values():
		_update_building(b)
	_update_walkers()
	Housing.immigration(self)
	if tick % Rules.TICKS_PER_MONTH == 0:
		_end_of_month()


func run_months(n: int) -> void:
	for i in n * Rules.TICKS_PER_MONTH:
		step()


func _update_building(b) -> void:
	var d: Dictionary = b.def
	match d["kind"]:
		"producer":
			Logistics.update_producer(self, b)
		"processor":
			Logistics.update_processor(self, b)
		"service":
			if d["service"] == "market":
				Logistics.supply_agora(self, b)
				if b.total_stock() > 0:
					Services.try_spawn(self, b, "market", "")
			else:
				Services.try_spawn(self, b, d["service"], d.get("god", ""))
		"monument":
			Monuments.update(self, b)


func _update_walkers() -> void:
	for wid in walkers.keys():
		var w = walkers.get(wid)
		if w == null:
			continue
		w.move_t += 1
		if w.move_t < Rules.WALKER_STEP_TICKS:
			continue
		w.move_t = 0
		match w.kind:
			"service":
				Services.step(self, w)
			"cart":
				Logistics.step_cart(self, w)
			"immigrant":
				Housing.step_immigrant(self, w)


func _end_of_month() -> void:
	months += 1
	Housing.monthly(self)
	Labor.allocate(self)
	Labor.warn_shortage(self)
	Hazards.monthly(self)
	Religion.monthly(self)
	Effects.monthly(self)
	Objectives.check(self)


# ---------------------------------------------------------------- Commandes du joueur

func can_place(type: String, p: Vector2i) -> String:
	return Construction.can_place(self, type, p)


func place(type: String, p: Vector2i) -> String:
	return Construction.place(self, type, p)


func place_road_path(tiles: Array) -> int:
	return Construction.place_road_path(self, tiles)


func demolish(p: Vector2i) -> bool:
	return Construction.demolish(self, p)


func festival(god: String) -> String:
	return Religion.festival(self, god)


## Mission à choix (Athènes) : désigne le dieu protecteur de la cité, quand le moment est venu.
func choose_patron(god: String) -> String:
	if not needs_patron_choice():
		return "Le moment de choisir n'est pas venu" if patron == "" else "La cité a déjà choisi son protecteur"
	var err := Religion.choose_patron(self, god)
	if err == "":
		map_version += 1
		Objectives.check(self)
	return err


# ---------------------------------------------------------------- Requêtes

func is_available(type: String) -> bool:
	if not type in mission.get("buildings", []):
		return false
	# Le temple d'un prétendant ne se bâtit que s'il a été choisi pour protecteur.
	var only_for: String = catalog.building(type).get("patron", "")
	return only_for == "" or only_for == patron


## Vrai quand le joueur doit choisir le protecteur : la mission en propose un,
## et l'étape en cours le demande (objectif « patron ») ; sans étapes, dès le début.
func needs_patron_choice() -> bool:
	if patron != "" or Religion.patron_options(self).is_empty():
		return false
	if Objectives.stages(self).is_empty():
		return true
	for o in Objectives.current(self):
		if o["type"] == "patron":
			return true
	return false


## L'étape en cours : {"index", "count", "title", "text"}, ou {} pour une mission d'un seul tenant.
func current_stage() -> Dictionary:
	var st := Objectives.stages(self)
	if st.is_empty():
		return {}
	var i := mini(stage, st.size() - 1)
	return {"index": i, "count": st.size(), "title": st[i].get("title", ""), "text": st[i].get("text", "")}


func patron_options() -> Array:
	return Religion.patron_options(self)


func rival() -> String:
	return Religion.rival(self)


func building_at(p: Vector2i):
	var bid: int = grid.occupant(p) if grid != null else -1
	return buildings.get(bid) if bid != -1 else null


func houses() -> Array:
	var res := []
	for b in buildings.values():
		if b.kind() == "house":
			res.append(b)
	return res


func has_road_access(b) -> bool:
	return Access.has_road(self, b, Rules.HOUSE_ROAD_RADIUS if b.kind() == "house" else 1)


func house_cap(b) -> int:
	return Housing.cap(self, b)


func house_beauty(b) -> float:
	return Beauty.of_building(self, b)


func beauty_at(p: Vector2i) -> float:
	return Beauty.at(self, p)


func house_need_met(b, need: String, value = null) -> bool:
	return Housing.need_met(self, b, need, value)


func house_missing_for_next(b) -> Array:
	return Housing.missing_for_next(self, b)


func stored_total(res: String) -> int:
	return Logistics.stored_total(self, res)


func objectives() -> Array:
	return Objectives.evaluate(self)


func production_mult(res: String) -> float:
	return Effects.production_mult(self, res)


func sanctuary_complete(god: String) -> bool:
	return Monuments.sanctuary_complete(self, god)


# ---------------------------------------------------------------- Outils des systèmes

func log_event(text: String, kind: String = "info") -> void:
	events.append({"text": text, "kind": kind, "month": months})


func spawn_walker(kind: String, home: int, start: Vector2i):
	var w := Walker.new()
	w.id = next_walker_id
	next_walker_id += 1
	w.kind = kind
	w.home = home
	w.pos = start
	w.prev = start
	walkers[w.id] = w
	return w


func recount_population() -> void:
	population = 0
	for b in houses():
		population += b.pop
