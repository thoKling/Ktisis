extends "res://tests/run_tests.gd"

func _initialize() -> void:
	var c := City.new(Defs.get_defs().missions[0])
	build_thebes(c)
	for m in 48:
		c.run_months(1)
		if m % 4 == 3:
			var lv := [0,0,0,0,0]
			var food := 0
			var water := 0
			var rel := 0
			for h in c.houses():
				lv[h.level] += 1
				if h.get_stock("food") > 0: food += 1
				if h.water_until > c.tick: water += 1
				if c.house_need_met(h, "religion", null): rel += 1
			print("m%d pop %d lv %s food %d water %d rel %d workers %d/%d grain %d money %d walkers %d" % [c.months, c.population, lv, food, water, rel, c.workers_available, c.workers_needed, c.stored_total("wheat"), c.money, c.walkers.size()])
	for b in c.buildings.values():
		if b.kind() != "house":
			print(b.type, " ", b.pos, " eff ", b.efficiency, " ", c.building_info(b))
	for e in c.events: print(e)
	quit()
