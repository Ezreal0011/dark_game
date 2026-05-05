class_name FxLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	z_index = 40

func refresh() -> void:
	pass

func clear() -> void:
	for child in get_children():
		child.queue_free()

func play_scan(center_tile: Vector2i, radius: int) -> void:
	if grid_map == null:
		return
	var center := grid_map.grid_to_world(center_tile)
	_add_ring(center, Color(0.70, 0.26, 1.0, 0.52), float(radius) * 31.0, 0.45)
	_add_ring(center, Color(0.18, 0.86, 1.0, 0.38), float(radius) * 23.0, 0.36)
	_add_flash_label(center + Vector2(22, -34), "扫描脉冲", Color(0.82, 0.58, 1.0, 1.0))

func play_attack(from_tile: Vector2i, target_tile: Vector2i, hit: bool) -> void:
	if grid_map == null:
		return
	var from_pos := grid_map.grid_to_world(from_tile)
	var to_pos := grid_map.grid_to_world(target_tile)
	var color := Color(1.0, 0.16, 0.05, 0.95) if hit else Color(1.0, 0.62, 0.16, 0.86)
	_add_beam(from_pos, to_pos, color, 0.34)
	_add_burst(to_pos, color, 0.36)
	_add_flash_label(to_pos + Vector2(18, -30), "命中" if hit else "未命中", color)

func play_collect(tile: Vector2i, amount: int) -> void:
	if grid_map == null:
		return
	var center := grid_map.grid_to_world(tile)
	_add_ring(center, Color(1.0, 0.78, 0.16, 0.46), 34.0, 0.36)
	_add_burst(center, Color(1.0, 0.76, 0.20, 0.72), 0.42)
	_add_flash_label(center + Vector2(20, -34), "+%d 暗能" % amount, Color(1.0, 0.86, 0.38, 1.0))

func play_skill_pick(tile: Vector2i, level: int) -> void:
	if grid_map == null:
		return
	var center := grid_map.grid_to_world(tile)
	_add_ring(center, Color(0.76, 0.24, 1.0, 0.48), 38.0, 0.42)
	_add_burst(center, Color(0.84, 0.34, 1.0, 0.70), 0.46)
	_add_flash_label(center + Vector2(20, -34), "获得 Lv.%d 技能" % level, Color(0.96, 0.66, 1.0, 1.0))

func play_skill(tiles: Array[Vector2i], skill_type: String) -> void:
	var color := Color(1.0, 0.24, 0.48, 0.68) if skill_type == "攻击" else Color(0.66, 0.28, 1.0, 0.62)
	for tile in tiles:
		_add_burst(grid_map.grid_to_world(tile), color, 0.34)

func play_npc_move(from_tile: Vector2i, to_tile: Vector2i) -> void:
	if grid_map == null:
		return
	var from_pos := grid_map.grid_to_world(from_tile)
	var to_pos := grid_map.grid_to_world(to_tile)
	_add_beam(from_pos, to_pos, Color(1.0, 0.74, 0.12, 0.66), 0.42)
	_add_burst(to_pos, Color(1.0, 0.74, 0.12, 0.48), 0.42)

func _add_beam(from_pos: Vector2, to_pos: Vector2, color: Color, duration: float) -> void:
	var beam := Line2D.new()
	beam.width = 4.0
	beam.default_color = color
	beam.add_point(from_pos)
	beam.add_point(to_pos)
	add_child(beam)
	var head := Polygon2D.new()
	head.color = color
	head.polygon = PackedVector2Array([
		Vector2(0, -9),
		Vector2(13, 0),
		Vector2(0, 9),
		Vector2(4, 0)
	])
	head.position = to_pos
	head.rotation = (to_pos - from_pos).angle()
	add_child(head)
	var tween := create_tween()
	tween.tween_property(beam, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(head, "modulate:a", 0.0, duration)
	tween.tween_callback(beam.queue_free)
	tween.tween_callback(head.queue_free)

func _add_ring(center: Vector2, color: Color, target_radius: float, duration: float) -> void:
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = color
	ring.closed = true
	var points := PackedVector2Array()
	for i in range(36):
		var angle := TAU * float(i) / 36.0
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	ring.points = points
	ring.position = center
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * (target_radius / 10.0), duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

func _add_burst(center: Vector2, color: Color, duration: float) -> void:
	var burst := Polygon2D.new()
	burst.color = color
	burst.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(6, -6),
		Vector2(20, 0),
		Vector2(6, 6),
		Vector2(0, 20),
		Vector2(-6, 6),
		Vector2(-20, 0),
		Vector2(-6, -6)
	])
	burst.position = center
	add_child(burst)
	var tween := create_tween()
	tween.tween_property(burst, "scale", Vector2.ONE * 1.75, duration)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, duration)
	tween.tween_callback(burst.queue_free)

func _add_flash_label(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(130, 22)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -16), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)
