class_name PointVisualLayer
extends Node2D

const RESOURCE_IDLE := preload("res://assets/points/point_resource_idle.png")
const SKILL_LV1 := preload("res://assets/points/point_skill_lv1.png")
const SKILL_LV2 := preload("res://assets/points/point_skill_lv2.png")
const SKILL_LV3 := preload("res://assets/points/point_skill_lv3.png")
const SKILL_LV4 := preload("res://assets/points/point_skill_lv4.png")

var game_controller: GameController
var grid_map: DarkSignalGridMap

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
	var root := _add_root(tile)
	_add_range_plate(root, Color(1.0, 0.70, 0.12, 0.055), Color(1.0, 0.66, 0.10, 0.48))
	_add_sprite(root, RESOURCE_IDLE, 0.25, 0.82)
	_add_label(root, "资源 +%d" % energy, Vector2(15, -18), Color(1.0, 0.84, 0.36, 0.88), 10)

func _add_skill_point(tile: Vector2i, level: int) -> void:
	var root := _add_root(tile)
	_add_range_plate(root, Color(0.74, 0.22, 1.0, 0.055), Color(0.78, 0.24, 1.0, 0.50))
	_add_sprite(root, _skill_texture(level), 0.25, 0.84)
	_add_label(root, "技能 Lv.%d" % level, Vector2(15, -18), Color(0.92, 0.62, 1.0, 0.88), 10)

func _add_root(tile: Vector2i) -> Node2D:
	var root := Node2D.new()
	root.position = grid_map.grid_to_world(tile)
	add_child(root)
	return root

func _add_sprite(root: Node2D, texture: Texture2D, sprite_scale: float, alpha: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	root.add_child(sprite)

func _add_range_plate(root: Node2D, fill_color: Color, line_color: Color) -> void:
	var plate := Polygon2D.new()
	plate.color = fill_color
	plate.polygon = PackedVector2Array([
		Vector2(-14, -14),
		Vector2(14, -14),
		Vector2(14, 14),
		Vector2(-14, 14)
	])
	root.add_child(plate)

	var line := Line2D.new()
	line.width = 0.8
	line.default_color = line_color
	line.closed = true
	line.points = PackedVector2Array([
		Vector2(-14, -14),
		Vector2(14, -14),
		Vector2(14, 14),
		Vector2(-14, 14)
	])
	root.add_child(line)

func _add_label(root: Node2D, text: String, offset: Vector2, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = offset
	label.size = Vector2(72, 16)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(label)

func _skill_texture(level: int) -> Texture2D:
	if level <= 1:
		return SKILL_LV1
	if level == 2:
		return SKILL_LV2
	if level == 3:
		return SKILL_LV3
	return SKILL_LV4
