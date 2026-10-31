extends RefCounted
## Cases visibles des greniers et entrepôts : on voit ce qu'il y a dedans sans cliquer.
## Le bâtiment est découpé en cases (positions dans assets/goods/storage_bays.json, partagées avec tools/art/storage.py) ;
## chaque marchandise présente occupe une ou plusieurs cases, chacune remplie au quart, à moitié, aux trois quarts ou en entier.

const BAYS_PATH := "res://assets/goods/storage_bays.json"
const LEVELS := 4

static var _bays = null


## Centres des cases (en tuiles, depuis le coin du bâtiment) et taille d'une case, ou [] pour un autre bâtiment.
static func bays(type: String) -> Array:
	if _bays == null:
		_bays = {}
		var f := FileAccess.open(BAYS_PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				for t in data["buildings"]:
					var pts := []
					for p in data["buildings"][t]:
						pts.append(Vector2(p[0], p[1]))
					_bays[t] = pts
	return _bays.get(type, [])


## Remplissage des cases : un tableau de bay_count entrées, [] pour une case vide ou [ressource, niveau 1..4].
## Chaque marchandise présente a au moins une case ; les cases restantes vont à celles qui en demandent le plus,
## à raison d'une case pour capacity / bay_count unités. Les marchandises sont rangées dans l'ordre de accepts.
static func fill(stock: Dictionary, accepts: Array, capacity: int, bay_count: int) -> Array:
	var res := []
	res.resize(bay_count)
	for i in bay_count:
		res[i] = []
	if bay_count <= 0 or capacity <= 0:
		return res
	var per := float(capacity) / bay_count
	var present := []
	for r in accepts:
		if int(stock.get(r, 0)) > 0 and present.size() < bay_count:
			present.append(r)
	var alloc := {}
	for r in present:
		alloc[r] = 1
	var free := bay_count - present.size()
	while free > 0:
		var best := ""
		var best_gap := 0
		for r in present:
			var gap: int = ceili(int(stock[r]) / per) - int(alloc[r])
			if gap > best_gap:
				best = r
				best_gap = gap
		if best == "":
			break
		alloc[best] += 1
		free -= 1
	var i := 0
	for r in present:
		var left := float(stock[r])
		for k in alloc[r]:
			var amount := left if k == alloc[r] - 1 else minf(left, per)
			left -= amount
			res[i] = [r, clampi(ceili(amount / per * LEVELS - 0.001), 1, LEVELS)]
			i += 1
	return res
