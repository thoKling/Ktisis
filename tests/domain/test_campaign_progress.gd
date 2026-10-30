extends "res://tests/lib/test_case.gd"
## Progression de la campagne : missions ouvertes et déblocage.

const Campaign = preload("res://src/domain/campaign.gd")


func test_only_unlocked_missions_open_outside_test_phase() -> void:
	check(Campaign.is_open(0, 1, 3, false), "la première mission est toujours ouverte")
	check(not Campaign.is_open(1, 1, 3, false), "la deuxième attend la victoire")
	check(Campaign.is_open(1, 2, 3, false), "la deuxième une fois débloquée")
	check(Campaign.is_open(0, 0, 3, false), "au moins une mission ouverte")


func test_test_phase_opens_every_mission() -> void:
	for i in 3:
		check(Campaign.is_open(i, 1, 3, true), "mission %d ouverte en phase de test" % (i + 1))
	check(not Campaign.is_open(3, 1, 3, true), "pas de mission hors catalogue")
	check(not Campaign.is_open(-1, 1, 3, true), "pas d'indice négatif")


func test_winning_unlocks_the_next_mission() -> void:
	eq(Campaign.unlocked_after_win(0, 1, 3), 2, "Thèbes gagnée : Athènes débloquée")
	eq(Campaign.unlocked_after_win(2, 3, 3), 3, "la dernière ne débloque rien de plus")
	eq(Campaign.unlocked_after_win(0, 3, 3), 3, "rejouer une mission ne reverrouille rien")
