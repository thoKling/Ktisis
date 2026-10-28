extends SceneTree
## Joue une mission avec le planificateur et affiche son évolution :
##   godot --headless --path . -s res://tests/tools/balance.gd -- <mission 0-2> [mois max]

const City = preload("res://src/domain/city.gd")
const CatalogLoader = preload("res://src/infrastructure/catalog_loader.gd")
const BuildingInfo = preload("res://src/presentation/building_info.gd")
const Planner = preload("res://tests/tools/planner.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mi := int(args[0]) if args.size() > 0 else 0
	var max_months := int(args[1]) if args.size() > 1 else 120
	var res := play(mi, max_months, true)
	print("Résultat : ", res)
	quit()


static func play(mi: int, max_months: int, verbose: bool, embellish: bool = true) -> Dictionary:
	var catalog = CatalogLoader.load_catalog()
	var c := City.new(catalog, catalog.missions[mi])
	var builders := [Planner.build_thebes, Planner.build_athenes, Planner.build_iolcos]
	var ok: bool = builders[mi].call(c)
	if verbose:
		print("construit : %s, %d bâtiments, trésor %d" % [ok, c.buildings.size(), c.money])
	var favorite: String = c.mission["gods"][0]
	for m in max_months:
		c.run_months(1)
		c.festival(favorite)
		Planner.develop(c)
		if embellish and m % 3 == 2 and Planner.wishlist(c.mission["id"]).is_empty() or m > 36:
			Planner.embellish(c)
		if verbose and (c.months % 6 == 0 or c.won):
			var lv := [0, 0, 0, 0, 0]
			var cov := {"food": 0, "water": 0, "religion": 0, "beauty8": 0, "inhabited": 0}
			for h in c.houses():
				lv[h.level] += 1
				if h.pop > 0:
					cov["inhabited"] += 1
				if c.house_need_met(h, "food", null): cov["food"] += 1
				if c.house_need_met(h, "water", null): cov["water"] += 1
				if c.house_need_met(h, "religion", null): cov["religion"] += 1
				if c.house_need_met(h, "beauty", 8): cov["beauty8"] += 1
			var objs := []
			for o in c.objectives():
				objs.append(o["text"])
			print("m%d pop %d niveaux %s trésor %d mo %d/%d | %s" % [
				c.months, c.population, lv, c.money, c.workers_available, c.workers_needed, " ; ".join(objs)])
			print("     couverture %s faveur %s" % [cov, c.favor])
		if c.won:
			break
	if verbose:
		for b in c.buildings.values():
			if b.kind() in ["monument", "storage"]:
				print("  ", BuildingInfo.lines(c, b))
		for e in c.events:
			if e["kind"] != "info":
				print("  ", e["month"], " ", e["text"])
	return {"won": c.won, "months": c.months, "population": c.population, "money": c.money}
