class_name ZoneVisualLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap
var tile_size := 40
var scaled_tile := Vector2(40, 40)
var label_layer: Node2D

const SAFE_FILL := Color(0.00, 0.66, 1.00, 0.025)
const SAFE_BORDER := Color(0.00, 0.86, 1.00, 0.42)
const SILENT_FILL := Color(0.00, 0.50, 1.00, 0.16)
const SILENT_BORDER := Color(0.08, 0.82, 1.00, 0.62)
const ECHO_FILL := Color(1.00, 0.38, 0.02, 0.18)
const ECHO_BORDER := Color(1.00, 0.58, 0.08, 0.66)
const BLACK_FILL := Color(1.00, 0.04, 0.02, 0.16)
const BLACK_BORDER := Color(1.00, 0.16, 0.08, 0.58)

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	top_level = true
	z_as_relative = false
	z_index = 18
	if label_layer == null:
		label_layer = Node2D.new()
		label_layer.name = "ZoneLabelLayer"
		label_layer.top_level = true
		label_layer.z_as_relative = false
		label_layer.z_index = 90
		add_child(label_layer)

func refresh() -> void:
	if grid_map == null:
		return
	tile_size = grid_map.tile_size
	z_index = 18
	_clear_labels()
	queue_redraw()
	call_deferred("_rebuild_labels")

func clear() -> void:
	_clear_labels()

func _draw() -> void:
	if grid_map == null:
		return
	_draw_safe_bounds()
	_draw_zone_cells("silent", SILENT_FILL, SILENT_BORDER)
	_draw_zone_cells("echo", ECHO_FILL, ECHO_BORDER)
	_draw_zone_cells("black_domain", BLACK_FILL, BLACK_BORDER)
	_draw_black_warning_border()

func _draw_safe_bounds() -> void:
	var layer := grid_map.get_collapse_layer()
	var start := Vector2i(layer, layer)
	var end := Vector2i(grid_map.map_width - layer, grid_map.map_height - layer)
	if end.x <= start.x or end.y <= start.y:
		return
	_draw_polygon(grid_map.grid_rect_corners_world(start, end), SAFE_FILL, SAFE_BORDER, 0.8)

func _draw_zone_cells(zone_type: String, fill: Color, border: Color) -> void:
	for y in range(grid_map.map_height):
		for x in range(grid_map.map_width):
			var tile := Vector2i(x, y)
			if grid_map.get_zone_type(tile) != zone_type:
				continue
			_draw_polygon(grid_map.grid_cell_corners_world(tile), fill, border, 0.8)

func _draw_black_warning_border() -> void:
	var layer := grid_map.get_collapse_layer()
	if layer <= 0:
		return
	var start := Vector2i(layer, layer)
	var end := Vector2i(grid_map.map_width - layer, grid_map.map_height - layer)
	if end.x <= start.x or end.y <= start.y:
		return
	_draw_polygon(grid_map.grid_rect_corners_world(start, end), Color(1.0, 0.10, 0.04, 0.035), BLACK_BORDER, 0.9)

func _draw_polygon(points: PackedVector2Array, fill: Color, border: Color, width: float) -> void:
	draw_colored_polygon(points, fill)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, border, width)

func _rebuild_labels() -> void:
	if grid_map == null or label_layer == null:
		return
	_clear_labels()
	_add_zone_label(_safe_center(), "安全区", SAFE_BORDER)
	if grid_map.get_collapse_layer() > 0:
		_add_zone_label(_black_label_position(), "黑域", BLACK_BORDER)
	_add_zone_label(_zone_center("silent"), "静默区", SILENT_BORDER)
	_add_zone_label(_zone_center("echo"), "回声区", ECHO_BORDER)

func _add_zone_label(pos: Vector2, title: String, color: Color) -> void:
	if pos == Vector2.INF:
		return
	var title_label := Label.new()
	title_label.text = title
	title_label.position = pos - Vector2(32, 9)
	title_label.size = Vector2(64, 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", color)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	label_layer.add_child(title_label)

func _safe_center() -> Vector2:
	return grid_map.grid_to_world(Vector2i(grid_map.map_width / 2, grid_map.map_height / 2)) + Vector2(0, -12)

func _black_label_position() -> Vector2:
	var layer := clampi(grid_map.get_collapse_layer(), 0, grid_map.map_width - 1)
	return grid_map.grid_to_world(Vector2i(layer, grid_map.map_height / 2))

func _zone_center(zone_type: String) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for y in range(grid_map.map_height):
		for x in range(grid_map.map_width):
			var tile := Vector2i(x, y)
			if grid_map.get_zone_type(tile) == zone_type:
				sum += grid_map.grid_to_world(tile)
				count += 1
	if count == 0:
		return Vector2.INF
	return sum / float(count)

func _clear_labels() -> void:
	if label_layer == null:
		return
	for child in label_layer.get_children():
		child.queue_free()
