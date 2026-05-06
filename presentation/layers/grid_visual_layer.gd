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
	z_index = -120
	queue_redraw()

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _draw() -> void:
	if grid_map == null:
		return
	var faint := Color(0.20, 0.56, 0.72, 0.20)
	var bright := Color(0.0, 0.72, 0.92, 0.44)
	for x in range(map_size.x + 1):
		var color := bright if x % 4 == 0 else faint
		draw_line(
			grid_map.grid_corner_to_world(Vector2(float(x), 0.0)),
			grid_map.grid_corner_to_world(Vector2(float(x), float(map_size.y))),
			color,
			1.0
		)
	for y in range(map_size.y + 1):
		var color := bright if y % 4 == 0 else faint
		draw_line(
			grid_map.grid_corner_to_world(Vector2(0.0, float(y))),
			grid_map.grid_corner_to_world(Vector2(float(map_size.x), float(y))),
			color,
			1.0
		)
	_draw_polyline(grid_map.grid_rect_corners_world(Vector2i.ZERO, map_size), Color(0.0, 0.84, 1.0, 0.54), 2.0)

func _draw_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width)
