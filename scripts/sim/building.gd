extends RefCounted
## Un bâtiment posé sur la grille. Simple conteneur de données : la logique est dans city.gd.

var id := 0
var type := ""
var pos := Vector2i.ZERO
var size := 1
var def := {}

var workers := 0
var efficiency := 0.0
var progress := 0.0
var stock := {}
var incoming := {}
var walker_id := -1
var cart_id := -1
var fetch_id := -1
var cooldown := 0
var risk := 0.0

# Maison
var level := 0
var pop := 0
var incoming_pop := 0
var water_until := 0
var sanctuary_until := 0
var religion := {}
var tax_due := 0.0
var fail_months := 0

# Monument
var stage := 0
var complete := false


func kind() -> String:
	return def.get("kind", "")


func center() -> Vector2:
	return Vector2(pos) + Vector2(size, size) * 0.5


func contains(p: Vector2i) -> bool:
	return p.x >= pos.x and p.y >= pos.y and p.x < pos.x + size and p.y < pos.y + size


func total_stock() -> int:
	var t := 0
	for r in stock:
		t += int(stock[r])
	return t


func total_incoming() -> int:
	var t := 0
	for r in incoming:
		t += int(incoming[r])
	return t


func get_stock(res: String) -> int:
	return int(stock.get(res, 0))


func add_stock(res: String, amount: int) -> void:
	stock[res] = get_stock(res) + amount
	if stock[res] <= 0:
		stock.erase(res)


func add_incoming(res: String, amount: int) -> void:
	incoming[res] = int(incoming.get(res, 0)) + amount
	if incoming[res] <= 0:
		incoming.erase(res)


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "x": pos.x, "y": pos.y,
		"progress": progress, "stock": stock.duplicate(), "risk": risk, "cooldown": cooldown,
		"level": level, "pop": pop, "water_until": water_until, "sanctuary_until": sanctuary_until,
		"religion": religion.duplicate(), "tax_due": tax_due, "fail_months": fail_months,
		"stage": stage, "complete": complete,
	}


func load_dict(d: Dictionary) -> void:
	progress = float(d.get("progress", 0.0))
	risk = float(d.get("risk", 0.0))
	cooldown = int(d.get("cooldown", 0))
	for r in d.get("stock", {}):
		stock[r] = int(d["stock"][r])
	level = int(d.get("level", 0))
	pop = int(d.get("pop", 0))
	water_until = int(d.get("water_until", 0))
	sanctuary_until = int(d.get("sanctuary_until", 0))
	for g in d.get("religion", {}):
		religion[g] = int(d["religion"][g])
	tax_due = float(d.get("tax_due", 0.0))
	fail_months = int(d.get("fail_months", 0))
	stage = int(d.get("stage", 0))
	complete = bool(d.get("complete", false))
