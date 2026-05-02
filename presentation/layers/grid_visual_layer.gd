class_name GridVisualLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap
var tile_size := 40
var map_size := Vector2i.ZERO
var scaled_tile := Vector2(40, 40)

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map

func refresh() -> void:
	if grid_map == null:
		return
	tile_size = grid_map.tile_size
	map_size = Vector2i(grid_map.map_width, grid_map.map_height)
	scaled_tile = Vector2(tile_size * grid_map.scale.x, tile_size * grid_map.scale.y)
	z_index = -120
	queue_redraw()

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _draw() -> void:
	if grid_map == null:
		return
	var origin := grid_map.grid_to_world(Vector2i.ZERO) - scaled_tile * 0.5
	var width := float(map_size.x) * scaled_tile.x
	var height := float(map_size.y) * scaled_tile.y
	var faint := Color(0.20, 0.56, 0.72, 0.20)
	var bright := Color(0.0, 0.72, 0.92, 0.44)
	for x in range(map_size.x + 1):
		var px := origin.x + float(x) * scaled_tile.x
		var color := bright if x % 4 == 0 else faint
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + height), color, 1.0)
	for y in range(map_size.y + 1):
		var py := origin.y + float(y) * scaled_tile.y
		var color := bright if y % 4 == 0 else faint
		draw_line(Vector2(origin.x, py), Vector2(origin.x + width, py), color, 1.0)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.0, 0.84, 1.0, 0.54), false, 2.0)
