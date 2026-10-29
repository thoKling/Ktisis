extends RefCounted
## Données de test écrites à la main : les tests du domaine ne dépendent pas de l'équilibrage de res://data.
## Les nombres sont choisis pour rendre les règles faciles à vérifier.

const Catalog = preload("res://src/domain/catalog.gd")
const City = preload("res://src/domain/city.gd")
const Grid = preload("res://src/domain/world/grid.gd")

const RESOURCES := {
	"wheat": {"name": "Blé"}, "fish": {"name": "Poisson"}, "olives": {"name": "Olives"},
	"oil": {"name": "Huile"}, "wool": {"name": "Laine"}, "wood": {"name": "Bois"}, "marble": {"name": "Marbre"},
}

const BUILDINGS := [
	{"id": "road", "name": "Route", "kind": "road", "cost": 2},
	{"id": "roadblock", "name": "Barrage", "kind": "roadblock", "cost": 4},
	{"id": "house", "name": "Maison", "kind": "house", "size": 2, "cost": 10, "risk": 4, "levels": [
		{"name": "Hutte", "cap": 5, "tax": 0.2, "needs": {}},
		{"name": "Maison simple", "cap": 9, "tax": 0.3, "needs": {"food": true}},
		{"name": "Maison de famille", "cap": 14, "tax": 0.45, "needs": {"food": true, "water": true}},
		{"name": "Maison de notable", "cap": 20, "tax": 0.65, "needs": {"food": true, "water": true, "religion": true, "beauty": 8}},
		{"name": "Villa", "cap": 28, "tax": 1.0, "needs": {"food": true, "water": true, "religion": true, "beauty": 20,
			"oil": true, "wool": true, "sanctuary": true}},
	]},
	{"id": "farm", "name": "Ferme", "kind": "producer", "size": 3, "cost": 40, "workers": 8, "produces": "wheat",
		"amount": 20, "cycle": 200, "on": "meadow"},
	{"id": "fishery", "name": "Quai", "kind": "producer", "size": 2, "cost": 50, "workers": 6, "produces": "fish",
		"amount": 14, "cycle": 200, "coast": true},
	{"id": "olive_grove", "name": "Oliveraie", "kind": "producer", "size": 3, "cost": 40, "workers": 8,
		"produces": "olives", "amount": 12, "cycle": 200, "on": "meadow"},
	{"id": "quarry", "name": "Carrière", "kind": "producer", "size": 2, "cost": 60, "workers": 8, "produces": "marble",
		"amount": 8, "cycle": 200, "near": "rock", "near_radius": 2, "beauty": -8, "beauty_radius": 3},
	{"id": "press", "name": "Pressoir", "kind": "processor", "size": 2, "cost": 50, "workers": 6, "input": "olives",
		"input_amount": 4, "produces": "oil", "amount": 4, "cycle": 100},
	{"id": "granary", "name": "Grenier", "kind": "storage", "size": 3, "cost": 60, "workers": 6,
		"accepts": ["wheat", "fish"], "capacity": 400},
	{"id": "warehouse", "name": "Entrepôt", "kind": "storage", "size": 3, "cost": 50, "workers": 5,
		"accepts": ["olives", "oil", "wool", "wood", "marble"], "capacity": 300},
	{"id": "agora", "name": "Agora", "kind": "service", "service": "market", "size": 3, "cost": 60, "workers": 5,
		"range": 32, "wants": {"wheat": 60, "fish": 60, "oil": 20, "wool": 20}},
	{"id": "fountain", "name": "Fontaine", "kind": "service", "service": "water", "cost": 20, "workers": 2, "range": 26},
	{"id": "tax_office", "name": "Percepteur", "kind": "service", "service": "tax", "size": 2, "cost": 40, "workers": 4,
		"range": 32},
	{"id": "guard_post", "name": "Vigie", "kind": "service", "service": "guard", "cost": 25, "workers": 3, "range": 30},
	{"id": "altar_demeter", "name": "Autel de Déméter", "kind": "service", "service": "priest", "god": "demeter",
		"size": 2, "cost": 40, "workers": 3, "range": 28},
	{"id": "altar_athena", "name": "Autel d'Athéna", "kind": "service", "service": "priest", "god": "athena",
		"size": 2, "cost": 40, "workers": 3, "range": 28},
	{"id": "garden", "name": "Jardin", "kind": "deco", "cost": 12, "beauty": 6, "beauty_radius": 3},
	{"id": "plaza", "name": "Place", "kind": "deco", "size": 2, "cost": 30, "beauty": 8, "beauty_radius": 4},
	{"id": "statue", "name": "Statue", "kind": "deco", "cost": 30, "cost_res": {"marble": 4}, "beauty": 12,
		"beauty_radius": 4},
	{"id": "sanctuary_demeter", "name": "Sanctuaire", "kind": "monument", "god": "demeter", "size": 4, "cost": 250,
		"workers": 12, "stages": [{"marble": 20, "wood": 10}, {"marble": 30}, {"marble": 30, "oil": 10}],
		"stage_ticks": 300, "service": "sanctuary", "range": 40},
	# L'Acropole : monuments de la colline sacrée, dont un temple par prétendant.
	{"id": "gate", "name": "Porte", "kind": "monument", "size": 2, "cost": 100, "workers": 4, "on": "hill",
		"stages": [{"marble": 10}], "stage_ticks": 100},
	{"id": "temple_athena", "name": "Temple d'Athéna", "kind": "monument", "god": "athena", "patron": "athena",
		"size": 3, "cost": 100, "workers": 4, "on": "hill", "stages": [{"marble": 10}], "stage_ticks": 100,
		"service": "sanctuary", "range": 40},
	{"id": "temple_poseidon", "name": "Temple de Poséidon", "kind": "monument", "god": "poseidon", "patron": "poseidon",
		"size": 3, "cost": 100, "workers": 4, "on": "hill", "stages": [{"marble": 10}], "stage_ticks": 100,
		"service": "sanctuary", "range": 40},
	{"id": "olive_gift", "name": "Olivier sacré", "kind": "deco", "size": 2, "on": "hill", "sacred": true, "beauty": 10,
		"beauty_radius": 3},
	{"id": "spring_gift", "name": "Source", "kind": "deco", "size": 2, "on": "hill", "sacred": true, "beauty": 10,
		"beauty_radius": 3},
]

## Choix du protecteur façon Athènes : la colline va de (20, 5) à (29, 12), les présents apparaissent en (26, 6).
const HILL_FROM := Vector2i(20, 5)
const HILL_TO := Vector2i(29, 12)
const PATRON_CHOICE := {
	"gift_at": [26, 6], "patron_favor": 60, "rival_favor": 25, "rival_jealousy": 1.0,
	"options": [
		{"god": "athena", "gift": "olive_gift", "pitch": "Olivier", "effects": [
			{"type": "production_mult", "resources": ["olives"], "mult": 1.5, "months": -1, "text": "Olivier sacré"}]},
		{"god": "poseidon", "gift": "spring_gift", "pitch": "Source", "effects": [
			{"type": "production_mult", "resources": ["fish"], "mult": 1.5, "months": -1, "text": "Poissons"},
			{"type": "service_range_mult", "service": "water", "mult": 1.5, "months": -1, "text": "Source"}]},
	],
}

const GODS := [
	{"id": "demeter", "female": true, "name": "Déméter",
		"blessing": {"type": "production_mult", "resources": ["wheat"], "mult": 2.0, "months": 6, "text": "Bénédiction"},
		"wrath": {"type": "production_mult", "resources": ["wheat"], "mult": 0.0, "months": 3, "text": "Colère"}},
	{"id": "athena", "female": true, "name": "Athéna",
		"blessing": {"type": "production_mult", "resources": ["olives"], "mult": 2.0, "months": 6, "text": "Bénédiction"},
		"wrath": {"type": "lose_population", "fraction": 0.2, "text": "Colère"}},
	{"id": "poseidon", "name": "Poséidon",
		"blessing": {"type": "production_mult", "resources": ["fish"], "mult": 2.0, "months": 6, "text": "Bénédiction"},
		"wrath": {"type": "destroy_random", "count": 2, "text": "Colère"}},
]


static func catalog():
	var data := {"resources": RESOURCES, "categories": [], "buildings": BUILDINGS.duplicate(true)}
	return Catalog.new().fill(data, GODS.duplicate(true), [mission()])


## Mission de test : carte plate de 40 x 40, tout est disponible, aucun dieu (donc aucune colère).
static func mission(extra: Dictionary = {}) -> Dictionary:
	var ids := []
	for b in BUILDINGS:
		ids.append(b["id"])
	var m := {
		"id": "test", "title": "Test",
		"map": {"width": 40, "height": 40, "seed": 5, "coast": "", "lakes": 0, "meadows": 0, "forests": 0, "rocks": 0},
		"start_money": 100000, "gods": [], "buildings": ids,
		"objectives": [{"type": "population", "value": 50}],
	}
	m.merge(extra, true)
	return m


static func flat_city(extra: Dictionary = {}) -> City:
	return City.new(catalog(), mission(extra))


## Cité où Athéna et Poséidon se disputent le patronage, avec sa colline sacrée.
static func contested_city(extra: Dictionary = {}) -> City:
	var m := {"gods": ["athena", "poseidon"], "patron_choice": PATRON_CHOICE.duplicate(true)}
	m.merge(extra, true)
	var c := flat_city(m)
	set_terrain(c, HILL_FROM, HILL_TO, Grid.T_HILL)
	return c


static func set_terrain(c: City, from: Vector2i, to: Vector2i, t: int) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			c.grid.set_terrain(Vector2i(x, y), t)


## Route horizontale depuis l'entrée jusqu'à x_end.
static func main_road(c: City, x_end: int) -> void:
	c.place_road_path(Grid.l_path(Vector2i(0, c.entry.y), Vector2i(x_end, c.entry.y)))
