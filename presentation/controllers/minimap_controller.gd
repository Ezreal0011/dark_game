class_name MiniMapController
extends Node

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map

func refresh() -> void:
	if game_controller == null or grid_map == null or game_controller.hud == null:
		return
	var npc_tiles: Array[Vector2i] = []
	for npc in game_controller.npcs:
		if not bool(npc.get("alive", false)):
			continue
		var tile: Vector2i = npc.get("tile", Vector2i.ZERO)
		if game_controller.gm_show_npcs or game_controller._distance(game_controller.player_tile, tile) <= 1:
			npc_tiles.append(tile)
	var resource_tiles: Array[Vector2i] = []
	for tile in grid_map.resource_points.keys():
		resource_tiles.append(tile)
	var skill_tiles: Array[Vector2i] = []
	for tile in grid_map.skill_points.keys():
		skill_tiles.append(tile)
	game_controller.hud.set_minimap_state({
		"map_size": Vector2i(grid_map.map_width, grid_map.map_height),
		"collapse_layer": grid_map.get_collapse_layer(),
		"safe_text": grid_map.get_safe_bounds_text(),
		"player_tile": game_controller.player_tile,
		"npc_tiles": npc_tiles,
		"resource_tiles": resource_tiles,
		"skill_tiles": skill_tiles
	})
