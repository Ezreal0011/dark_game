class_name ActionPreviewLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	z_index = 22

func refresh() -> void:
	pass

func clear() -> void:
	for child in get_children():
		child.queue_free()

func show_range(tiles: Array[Vector2i], fill_color: Color, line_color: Color, label_text: String = "") -> void:
	clear()
	for tile in tiles:
		_add_tile_plate(tile, fill_color, line_color)
	if label_text != "" and game_controller != null:
		_add_floating_label(grid_map.grid_to_world(game_controller.player_tile) + Vector2(22, -32), label_text, line_color)

func show_target_path(from_tile: Vector2i, target_tile: Vector2i, color: Color, label_text: String = "") -> void:
	if grid_map == null:
		return
	var from_pos := grid_map.grid_to_world(from_tile)
	var to_pos := grid_map.grid_to_world(target_tile)
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.add_point(from_pos)
	line.add_point(to_pos)
	add_child(line)
	_add_target_bracket(target_tile, color)
	if label_text != "":
		_add_floating_label(to_pos + Vector2(20, -24), label_text, color)

func show_move_path(from_tile: Vector2i, target_tile: Vector2i, cost: int) -> void:
	clear()
	if grid_map == null:
		return
	var from_pos := grid_map.grid_to_world(from_tile)
	var to_pos := grid_map.grid_to_world(target_tile)
	_add_dashed_line(from_pos, to_pos, Color(0.12, 0.82, 1.0, 0.92))
	_add_target_bracket(target_tile, Color(0.12, 0.82, 1.0, 0.92))
	_add_floating_label(to_pos + Vector2(18, -28), "移动预览\n消耗 %d 暗能" % cost, Color(0.70, 0.95, 1.0, 1.0))

func show_attack_prediction(from_tile: Vector2i, target_tile: Vector2i, hit_rate: int, in_range: bool) -> void:
	clear()
	if grid_map == null:
		return
	var color := Color(1.0, 0.36, 0.10, 0.92) if in_range else Color(1.0, 0.08, 0.04, 0.88)
	show_target_path(from_tile, target_tile, color, "预测攻击\n%d%% 命中" % hit_rate if in_range else "目标超出范围")

func add_affected_tiles(tiles: Array[Vector2i], fill_color: Color, line_color: Color) -> void:
	for tile in tiles:
		_add_tile_plate(tile, fill_color, line_color)

func _add_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var delta := to_pos - from_pos
	var length := delta.length()
	if length <= 1.0:
		return
	var dir := delta / length
	var dash := 12.0
	var gap := 7.0
	var cursor := 0.0
	while cursor < length:
		var start: Vector2 = from_pos + dir * cursor
		var end_pos: Vector2 = from_pos + dir * min(cursor + dash, length)
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = color
		line.add_point(start)
		line.add_point(end_pos)
		add_child(line)
		cursor += dash + gap

func _add_tile_plate(tile: Vector2i, fill_color: Color, line_color: Color) -> void:
	if grid_map == null:
		return
	var center := grid_map.grid_to_world(tile)
	var half := 15.5
	var plate := Polygon2D.new()
	plate.color = fill_color
	plate.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	plate.position = center
	add_child(plate)
	var border := Line2D.new()
	border.width = 1.4
	border.default_color = line_color
	border.closed = true
	border.points = PackedVector2Array([
		center + Vector2(-half, -half),
		center + Vector2(half, -half),
		center + Vector2(half, half),
		center + Vector2(-half, half)
	])
	add_child(border)

func _add_target_bracket(tile: Vector2i, color: Color) -> void:
	var center := grid_map.grid_to_world(tile)
	var bracket := Line2D.new()
	bracket.width = 2.2
	bracket.default_color = color
	bracket.points = PackedVector2Array([
		center + Vector2(-18, -10),
		center + Vector2(-18, -18),
		center + Vector2(-10, -18),
		center + Vector2(10, -18),
		center + Vector2(18, -18),
		center + Vector2(18, -10),
		center + Vector2(18, 10),
		center + Vector2(18, 18),
		center + Vector2(10, 18),
		center + Vector2(-10, 18),
		center + Vector2(-18, 18),
		center + Vector2(-18, 10)
	])
	add_child(bracket)

func _add_floating_label(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(140, 22)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
