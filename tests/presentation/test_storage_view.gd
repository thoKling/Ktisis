extends "res://tests/lib/test_case.gd"
## Remplissage visible des cases des greniers et entrepôts.

const StorageView = preload("res://src/presentation/view/storage_view.gd")

const ACCEPTS := ["olives", "oil", "wool", "wood", "marble"]


func test_empty_storage_shows_empty_bays() -> void:
	eq(StorageView.fill({}, ACCEPTS, 300, 6), [[], [], [], [], [], []], "entrepôt vide")


func test_partial_bay_level() -> void:
	# 50 unités par case : 10 olives = un quart (arrondi au-dessus), 50 = plein.
	eq(StorageView.fill({"olives": 10}, ACCEPTS, 300, 6)[0], ["olives", 1], "un peu d'olives")
	eq(StorageView.fill({"olives": 26}, ACCEPTS, 300, 6)[0], ["olives", 3], "un peu plus de la moitié")
	eq(StorageView.fill({"olives": 50}, ACCEPTS, 300, 6), [["olives", 4], [], [], [], [], []], "une case pleine")


func test_big_stock_spreads_over_bays() -> void:
	eq(StorageView.fill({"wood": 120}, ACCEPTS, 300, 6), [["wood", 4], ["wood", 4], ["wood", 2], [], [], []], "bois sur trois cases")


func test_goods_follow_accepts_order() -> void:
	var slots := StorageView.fill({"marble": 20, "oil": 60}, ACCEPTS, 300, 6)
	eq(slots, [["oil", 4], ["oil", 1], ["marble", 2], [], [], []], "huile puis marbre")


## Chaque marchandise présente reste visible, même quand les cases manquent.
func test_every_good_gets_a_bay() -> void:
	var slots := StorageView.fill({"olives": 51, "oil": 51, "wool": 51, "wood": 51, "marble": 51}, ACCEPTS, 300, 6)
	var seen := {}
	for s in slots:
		check(not s.is_empty(), "aucune case vide quand l'entrepôt est presque plein")
		if not s.is_empty():
			seen[s[0]] = true
	eq(seen.size(), 5, "les cinq marchandises sont visibles")


func test_full_granary() -> void:
	var slots := StorageView.fill({"wheat": 300, "fish": 100}, ["wheat", "fish"], 400, 6)
	# 66 unités par case : 300 de blé = 4 cases pleines et une aux deux quarts, le poisson déborde dans la sienne.
	eq(slots, [["wheat", 4], ["wheat", 4], ["wheat", 4], ["wheat", 4], ["wheat", 2], ["fish", 4]], "grenier plein")


func test_bays_layout_is_shared_with_art() -> void:
	eq(StorageView.bays("granary").size(), 6, "six coffres au grenier")
	eq(StorageView.bays("warehouse").size(), 6, "six travées à l'entrepôt")
	eq(StorageView.bays("agora").size(), 0, "pas de cases à l'agora")
