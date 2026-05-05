class_name MiniMapWidget
extends Control

var map_size := Vector2i(24, 16)
var collapse_layer := 0
var player_tile := Vector2i.ZERO
var npc_tiles: Array[Vector2i] = []
var resource_tiles: Array[Vector2i] = []
var skill_tiles: Array[Vector2i] = []

func set_state(state: Dictionary) -> void:
	map_size = state.get("map_size", map_size)
	collapse_layer = int(state.get("collapse_layer", collapse_layer))
	player_tile = state.get("player_tile", player_tile)
	npc_tiles = state.get("npc_tiles", [])
	resource_tiles = state.get("resource_tiles", [])
	skill_tiles = state.get("skill_tiles", [])
	queue_redraw()

func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x <= 4.0 or draw_size.y <= 4.0:
		return
	var target_ratio := float(map_size.x) / float(map_size.y)
	var draw_ratio := draw_size.x / draw_size.y
	if draw_ratio > target_ratio:
		draw_size.x = draw_size.y * target_ratio
	else:
		draw_size.y = draw_size.x / target_ratio
	var cell: float = min(draw_size.x / float(map_size.x), draw_size.y / float(map_size.y))
	var map_px: Vector2 = Vector2(float(map_size.x), float(map_size.y)) * cell
	var origin: Vector2 = (size - map_px) * 0.5
	draw_rect(Rect2(origin, map_px), Color(0.01, 0.05, 0.08, 0.72), true)
	_draw_grid(origin, cell)
	_draw_black_domain(origin, cell)
	_draw_safe_bounds(origin, cell)
	_draw_points(origin, cell)
	_draw_units(origin, cell)

func _draw_grid(origin: Vector2, cell: float) -> void:
	var grid_color := Color(0.0, 0.62, 0.86, 0.22)
	for x in range(map_size.x + 1):
		var px := origin.x + float(x) * cell
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + float(map_size.y) * cell), grid_color, 1.0)
	for y in range(map_size.y + 1):
		var py := origin.y + float(y) * cell
		draw_line(Vector2(origin.x, py), Vector2(origin.x + float(map_size.x) * cell, py), grid_color, 1.0)

func _draw_black_domain(origin: Vector2, cell: float) -> void:
	if collapse_layer <= 0:
		return
	var red := Color(1.0, 0.12, 0.08, 0.34)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if x < collapse_layer or y < collapse_layer or x >= map_size.x - collapse_layer or y >= map_size.y - collapse_layer:
				draw_rect(_tile_rect(Vector2i(x, y), origin, cell), red, true)

func _draw_safe_bounds(origin: Vector2, cell: float) -> void:
	var safe_pos: Vector2 = origin + Vector2(float(collapse_layer), float(collapse_layer)) * cell
	var safe_size: Vector2 = Vector2(float(map_size.x - collapse_layer * 2), float(map_size.y - collapse_layer * 2)) * cell
	draw_rect(Rect2(safe_pos, safe_size), Color(0.0, 0.78, 1.0, 0.10), true)
	draw_rect(Rect2(safe_pos, safe_size), Color(0.0, 0.86, 1.0, 0.86), false, 1.6)

func _draw_points(origin: Vector2, cell: float) -> void:
	for tile in resource_tiles:
		draw_circle(_tile_center(tile, origin, cell), max(2.0, cell * 0.30), Color(1.0, 0.78, 0.12, 0.95))
	for tile in skill_tiles:
		var center: Vector2 = _tile_center(tile, origin, cell)
		var r: float = max(2.0, cell * 0.34)
		draw_polygon(PackedVector2Array([
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		]), PackedColorArray([Color(0.78, 0.26, 1.0, 0.95)]))

func _draw_units(origin: Vector2, cell: float) -> void:
	for tile in npc_tiles:
		draw_circle(_tile_center(tile, origin, cell), max(2.0, cell * 0.28), Color(1.0, 0.32, 0.08, 0.95))
	var center: Vector2 = _tile_center(player_tile, origin, cell)
	var r: float = max(3.0, cell * 0.44)
	draw_polygon(PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, r),
		center + Vector2(-r, r)
	]), PackedColorArray([Color(0.08, 0.82, 1.0, 1.0)]))

func _tile_rect(tile: Vector2i, origin: Vector2, cell: float) -> Rect2:
	return Rect2(origin + Vector2(float(tile.x), float(tile.y)) * cell, Vector2.ONE * cell)

func _tile_center(tile: Vector2i, origin: Vector2, cell: float) -> Vector2:
	return origin + (Vector2(float(tile.x), float(tile.y)) + Vector2(0.5, 0.5)) * cell
