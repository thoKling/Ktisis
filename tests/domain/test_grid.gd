extends "res://tests/lib/test_case.gd"
## La carte : routes, formes des routes, chemins.

const Grid = preload("res://src/domain/world/grid.gd")


func _grid() -> Grid:
	var t := PackedByteArray()
	t.resize(20 * 20)
	return Grid.new(20, 20, t)


func test_l_path_goes_horizontal_then_vertical() -> void:
	var p := Grid.l_path(Vector2i(1, 1), Vector2i(3, 3))
	eq(p, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)], "chemin en L")


func test_road_mask_follows_neighbours() -> void:
	var g := _grid()
	for p in Grid.l_path(Vector2i(5, 5), Vector2i(10, 8)):
		g.set_road(p, Grid.R_ROAD)
	eq(g.road_mask(Vector2i(7, 5)), 3, "droite est-ouest")
	eq(g.road_mask(Vector2i(10, 5)), 2 | 4, "virage")
	for p in Grid.l_path(Vector2i(10, 5), Vector2i(10, 2)):
		g.set_road(p, Grid.R_ROAD)
	eq(g.road_mask(Vector2i(10, 5)), 2 | 4 | 8, "jonction en T")


func test_find_path_is_shortest_and_respects_roadblocks() -> void:
	var g := _grid()
	for p in Grid.l_path(Vector2i(5, 5), Vector2i(10, 8)):
		g.set_road(p, Grid.R_ROAD)
	var goal := {Vector2i(10, 8): true}
	eq(g.find_path([Vector2i(5, 5)], goal, false).size(), 9, "plus court chemin")
	g.set_road(Vector2i(8, 5), Grid.R_BLOCK)
	check(g.find_path([Vector2i(5, 5)], goal, false).is_empty(), "le barrage arrête les services")
	check(not g.find_path([Vector2i(5, 5)], goal, true).is_empty(), "le barrage laisse passer les livreurs")


func test_roads_version_changes_with_roads() -> void:
	var g := _grid()
	var v := g.roads_version
	g.set_road(Vector2i(1, 1), Grid.R_ROAD)
	check(g.roads_version != v, "la version des routes change")


func test_touches_terrain() -> void:
	var g := _grid()
	g.set_terrain(Vector2i(6, 6), Grid.T_WATER)
	check(g.touches_terrain(Vector2i(4, 4), 2, Grid.T_WATER, 1), "un 2x2 en (4,4) touche l'eau en (6,6)")
	check(not g.touches_terrain(Vector2i(1, 1), 2, Grid.T_WATER, 1), "loin de l'eau")
	check(not g.is_buildable(Vector2i(6, 6)), "on ne bâtit pas sur l'eau")
