class_name PointVisualLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap
var tile_size := Vector2(40.0, 40.0)

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	z_index = 24

func refresh() -> void:
	clear()
	if grid_map == null:
		return
	for point_tile in grid_map.resource_points.keys():
		var point: Dictionary = grid_map.resource_points[point_tile]
		_add_resource_point(point_tile, int(point.get("energy", 4)))
	for point_tile in grid_map.skill_points.keys():
		var point: Dictionary = grid_map.skill_points[point_tile]
		_add_skill_point(point_tile, int(point.get("level", 1)))

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _add_resource_point(tile: Vector2i, energy: int) -> void:
	var center := grid_map.grid_to_world(tile)
	var root := Node2D.new()
	root.position = center
	add_child(root)
	_add_range_plate(root, Color(1.0, 0.70, 0.12, 0.16), Color(1.0, 0.66, 0.10, 0.82))
	_add_hex_core(root, Color(1.0, 0.77, 0.18, 0.88), Color(0.18, 0.11, 0.02, 0.92))
	_add_label(root, "资源点", Vector2(24, -26), Color(1.0, 0.86, 0.42, 1.0), 13)
	_add_label(root, "+%d 暗能" % energy, Vector2(24, -9), Color(0.78, 0.92, 1.0, 0.92), 11)

func _add_skill_point(tile: Vector2i, level: int) -> void:
	var center := grid_map.grid_to_world(tile)
	var root := Node2D.new()
	root.position = center
	add_child(root)
	_add_range_plate(root, Color(0.74, 0.22, 1.0, 0.16), Color(0.78, 0.24, 1.0, 0.82))
	_add_diamond_core(root, Color(0.80, 0.30, 1.0, 0.92), Color(0.10, 0.02, 0.18, 0.94))
	_add_label(root, "Lv.%d" % level, Vector2(22, -25), Color(0.96, 0.64, 1.0, 1.0), 12)
	_add_label(root, "技能点", Vector2(22, -8), Color(0.78, 0.92, 1.0, 0.92), 11)

func _add_range_plate(root: Node2D, fill_color: Color, line_color: Color) -> void:
	var plate := Polygon2D.new()
	plate.color = fill_color
	plate.polygon = PackedVector2Array([
		Vector2(-18, -18),
		Vector2(18, -18),
		Vector2(18, 18),
		Vector2(-18, 18)
	])
	root.add_child(plate)
	var line := Line2D.new()
	line.width = 1.8
	line.default_color = line_color
	line.closed = true
	line.points = PackedVector2Array([
		Vector2(-18, -18),
		Vector2(18, -18),
		Vector2(18, 18),
		Vector2(-18, 18)
	])
	root.add_child(line)

func _add_hex_core(root: Node2D, color: Color, shadow_color: Color) -> void:
	var shadow := Polygon2D.new()
	shadow.color = shadow_color
	shadow.polygon = PackedVector2Array([
		Vector2(0, -16),
		Vector2(13, -8),
		Vector2(13, 8),
		Vector2(0, 16),
		Vector2(-13, 8),
		Vector2(-13, -8)
	])
	root.add_child(shadow)
	var core := Polygon2D.new()
	core.color = color
	core.polygon = PackedVector2Array([
		Vector2(0, -12),
		Vector2(10, -6),
		Vector2(10, 6),
		Vector2(0, 12),
		Vector2(-10, 6),
		Vector2(-10, -6)
	])
	root.add_child(core)

func _add_diamond_core(root: Node2D, color: Color, shadow_color: Color) -> void:
	var shadow := Polygon2D.new()
	shadow.color = shadow_color
	shadow.polygon = PackedVector2Array([
		Vector2(0, -17),
		Vector2(17, 0),
		Vector2(0, 17),
		Vector2(-17, 0)
	])
	root.add_child(shadow)
	var core := Polygon2D.new()
	core.color = color
	core.polygon = PackedVector2Array([
		Vector2(0, -12),
		Vector2(12, 0),
		Vector2(0, 12),
		Vector2(-12, 0)
	])
	root.add_child(core)

func _add_label(root: Node2D, text: String, offset: Vector2, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = offset
	label.size = Vector2(70, 18)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(label)
