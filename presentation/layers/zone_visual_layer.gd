class_name ZoneVisualLayer
extends Node2D

const ZONE_STYLE := "res://presentation/resources/zone_style.json"

var game_controller: GameController
var grid_map: DarkSignalGridMap
var styles: Dictionary = {}
var tile_size := 40
var scaled_tile := Vector2(40, 40)

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	styles = _load_json(ZONE_STYLE)

func refresh() -> void:
	if grid_map == null:
		return
	tile_size = grid_map.tile_size
	scaled_tile = Vector2(tile_size * grid_map.scale.x, tile_size * grid_map.scale.y)
	z_index = -90
	queue_redraw()

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _draw() -> void:
	if grid_map == null:
		return
	_draw_safe_bounds()
	for y in range(grid_map.map_height):
		for x in range(grid_map.map_width):
			var tile := Vector2i(x, y)
			var zone := grid_map.get_zone_type(tile)
			if zone == "silent":
				_draw_zone_cell(tile, "silent")
			elif zone == "echo":
				_draw_zone_cell(tile, "echo")
			elif zone == "black_domain":
				_draw_zone_cell(tile, "black")

func _draw_safe_bounds() -> void:
	var layer := grid_map.get_collapse_layer()
	var start := Vector2i(layer, layer)
	var end := Vector2i(grid_map.map_width - layer, grid_map.map_height - layer)
	if end.x <= start.x or end.y <= start.y:
		return
	var origin := _tile_top_left(start)
	var size := Vector2(float(end.x - start.x) * scaled_tile.x, float(end.y - start.y) * scaled_tile.y)
	var style: Dictionary = styles.get("safe", {})
	draw_rect(Rect2(origin, size), _style_color(style, "fill", Color(0.0, 0.5, 0.8, 0.08)), true)
	draw_rect(Rect2(origin, size), _style_color(style, "border", Color(0.0, 0.82, 1.0, 0.8)), false, 2.0)

func _draw_zone_cell(tile: Vector2i, style_key: String) -> void:
	var style: Dictionary = styles.get(style_key, {})
	var rect := Rect2(_tile_top_left(tile), scaled_tile)
	draw_rect(rect, _style_color(style, "fill", Color(1.0, 1.0, 1.0, 0.12)), true)
	draw_rect(rect, _style_color(style, "border", Color(1.0, 1.0, 1.0, 0.6)), false, 1.5)

func _tile_top_left(tile: Vector2i) -> Vector2:
	return grid_map.grid_to_world(tile) - scaled_tile * 0.5

func _style_color(style: Dictionary, key: String, fallback: Color) -> Color:
	var text := String(style.get(key, ""))
	if text == "":
		return fallback
	return Color.html(text)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
