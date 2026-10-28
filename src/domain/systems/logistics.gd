extends RefCounted
## Production, stockage et livraisons : les livreurs portent la production au stockage le plus proche
## et vont chercher ce dont les ateliers, l'agora et les chantiers ont besoin.

const Rules = preload("res://src/domain/rules.gd")
const Access = preload("res://src/domain/systems/access.gd")
const Effects = preload("res://src/domain/systems/effects.gd")


# ---------------------------------------------------------------- Stockage

static func storages(c) -> Array:
	var res := []
	for b in c.buildings.values():
		if b.kind() == "storage":
			res.append(b)
	return res


static func storage_space(s, res: String) -> int:
	if not res in s.def.get("accepts", []):
		return 0
	return int(s.def["capacity"]) - s.total_stock() - s.total_incoming()


static func stored_total(c, res: String) -> int:
	var t := 0
	for s in storages(c):
		t += s.get_stock(res)
	return t


static func take_from_storage(c, res: String, n: int) -> void:
	for s in storages(c):
		var take := mini(n, s.get_stock(res))
		s.add_stock(res, -take)
		n -= take
		if n <= 0:
			return


## Les livraisons ne se décident pas à chaque pas, pour étaler le calcul des chemins.
static func is_logistics_tick(c, b) -> bool:
	return (c.tick + b.id) % Rules.LOGISTICS_PERIOD == 0


# ---------------------------------------------------------------- Production

static func update_producer(c, b) -> void:
	var d: Dictionary = b.def
	var res: String = d["produces"]
	if b.efficiency > 0.0 and b.get_stock(res) < Rules.PRODUCER_MAX_STOCK:
		b.progress += b.efficiency * Effects.production_mult(c, res)
		if b.progress >= d["cycle"]:
			b.progress -= d["cycle"]
			b.add_stock(res, d["amount"])
	if b.get_stock(res) >= mini(Rules.CART_LOAD, d["amount"]) and is_logistics_tick(c, b):
		dispatch_output(c, b, res)


static func update_processor(c, b) -> void:
	var d: Dictionary = b.def
	var inp: String = d["input"]
	var out: String = d["produces"]
	var need: int = d["input_amount"]
	if b.efficiency > 0.0 and b.get_stock(inp) >= need and b.get_stock(out) < Rules.PRODUCER_MAX_STOCK:
		b.progress += b.efficiency * Effects.production_mult(c, out)
		if b.progress >= d["cycle"]:
			b.progress -= d["cycle"]
			b.add_stock(inp, -need)
			b.add_stock(out, d["amount"])
	if is_logistics_tick(c, b):
		var have: int = b.get_stock(inp) + int(b.incoming.get(inp, 0))
		if have < need * 3 and b.efficiency > 0.0:
			request_supply(c, b, inp, need * 3 - have)
		if b.get_stock(out) >= mini(Rules.CART_LOAD, d["amount"]):
			dispatch_output(c, b, out)


## L'agora se réapprovisionne quand un de ses stocks tombe sous la moitié de ce qu'elle veut.
static func supply_agora(c, b) -> void:
	if not is_logistics_tick(c, b) or b.efficiency <= 0.0:
		return
	var wants: Dictionary = b.def["wants"]
	for res in wants:
		var have: int = b.get_stock(res) + int(b.incoming.get(res, 0))
		if have * 2 < wants[res] and request_supply(c, b, res, wants[res] - have):
			return


# ---------------------------------------------------------------- Livreurs

## Envoie un livreur porter la production vers le stockage le plus proche qui a de la place.
static func dispatch_output(c, b, res: String) -> void:
	if b.cart_id != -1:
		return
	var amt := mini(Rules.CART_LOAD, b.get_stock(res))
	var cands := []
	for s in storages(c):
		if s.efficiency > 0.0 and storage_space(s, res) >= amt:
			cands.append(s)
	if cands.is_empty():
		return
	var r := Access.nearest_by_road(c, b, cands)
	if r.is_empty():
		return
	b.add_stock(res, -amt)
	r["b"].add_incoming(res, amt)
	var path: Array = r["path"]
	var w = c.spawn_walker("cart", b.id, path[0])
	path.pop_front()
	w.path = path
	w.target = r["b"].id
	w.cargo_res = res
	w.cargo_amt = amt
	b.cart_id = w.id


## Fait venir une ressource depuis le stockage le plus proche. Renvoie true si un livreur part.
static func request_supply(c, b, res: String, amount: int) -> bool:
	if b.fetch_id != -1 or amount <= 0:
		return false
	var cands := []
	for s in storages(c):
		if s.efficiency > 0.0 and s.get_stock(res) > 0:
			cands.append(s)
	if cands.is_empty():
		return false
	var r := Access.nearest_by_road(c, b, cands)
	if r.is_empty():
		return false
	var s = r["b"]
	var take := mini(mini(amount, Rules.CART_LOAD * 4), s.get_stock(res))
	s.add_stock(res, -take)
	b.add_incoming(res, take)
	var path: Array = r["path"]
	path.reverse()
	var w = c.spawn_walker("cart", s.id, path[0])
	path.pop_front()
	w.path = path
	w.target = b.id
	w.cargo_res = res
	w.cargo_amt = take
	b.fetch_id = w.id
	return true


static func step_cart(c, w) -> void:
	if w.follow_path():
		_arrive(c, w)


static func _arrive(c, w) -> void:
	c.walkers.erase(w.id)
	var src = c.buildings.get(w.home)
	if src != null and src.cart_id == w.id:
		src.cart_id = -1
	var t = c.buildings.get(w.target)
	if t == null:
		return
	if t.fetch_id == w.id:
		t.fetch_id = -1
	t.add_incoming(w.cargo_res, -w.cargo_amt)
	var amount: int = w.cargo_amt
	if t.kind() == "storage":
		amount = mini(amount, int(t.def["capacity"]) - t.total_stock())
	if amount > 0:
		t.add_stock(w.cargo_res, amount)
