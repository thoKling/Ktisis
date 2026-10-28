extends "res://tests/lib/test_case.gd"
## Équilibrage : chaque mission, jouée par le planificateur (tests/tools/planner.gd), se gagne à temps.

const Balance = preload("res://tests/tools/balance.gd")

const LIMITS := [24, 48, 84]


func test_each_mission_is_winnable() -> void:
	for mi in LIMITS.size():
		var r: Dictionary = Balance.play(mi, LIMITS[mi], false)
		print("    mission %d : gagnée %s en %d mois, population %d, trésor %d" % [
			mi + 1, r["won"], r["months"], r["population"], r["money"]])
		check(r["won"], "mission %d gagnée en %d mois" % [mi + 1, LIMITS[mi]])
