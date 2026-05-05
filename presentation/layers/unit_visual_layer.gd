class_name UnitVisualLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	z_index = 30

func refresh() -> void:
	clear()
	if game_controller == null or grid_map == null:
		return
	_add_player_unit(game_controller.player_tile, game_controller.player_hp)
	for npc in game_controller.npcs:
		if not bool(npc.get("alive", false)):
			continue
		var npc_tile: Vector2i = npc.get("tile", Vector2i.ZERO)
		if not game_controller.gm_show_npcs and game_controller._distance(game_controller.player_tile, npc_tile) > 1:
			continue
		_add_npc_unit(npc)

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _add_player_unit(tile: Vector2i, hp: int) -> void:
	var root := Node2D.new()
	root.position = grid_map.grid_to_world(tile)
	add_child(root)
	_add_selection_glow(root, Color(0.08, 0.78, 1.0, 0.23), Color(0.0, 0.82, 1.0, 0.85))
	_add_ship_marker(root, Color(0.10, 0.78, 1.0, 0.96), Color(0.58, 0.94, 1.0, 1.0), false)
	_add_status_bar(root, "信号 玩家", hp, 3, Color(0.1, 0.82, 1.0, 1.0), Vector2(-33, -38))

func _add_npc_unit(npc: Dictionary) -> void:
	var root := Node2D.new()
	var tile: Vector2i = npc.get("tile", Vector2i.ZERO)
	root.position = grid_map.grid_to_world(tile)
	add_child(root)
	var revealed := not game_controller.gm_show_npcs
	var fill := Color(1.0, 0.36, 0.10, 0.95) if revealed else Color(1.0, 0.74, 0.14, 0.82)
	var line := Color(1.0, 0.58, 0.25, 1.0) if revealed else Color(1.0, 0.88, 0.36, 0.92)
	_add_selection_glow(root, Color(1.0, 0.28, 0.06, 0.16), line)
	_add_ship_marker(root, fill, line, true)
	if game_controller.gm_show_npcs:
		_add_status_bar(root, "%s %s" % [String(npc.get("id", "NPC")), String(npc.get("type", ""))], int(npc.get("hp", 1)), 2, line, Vector2(-42, -38))
	else:
		_add_status_bar(root, "威胁", int(npc.get("hp", 1)), 2, line, Vector2(-24, -36))

func _add_selection_glow(root: Node2D, fill_color: Color, line_color: Color) -> void:
	var plate := Polygon2D.new()
	plate.color = fill_color
	plate.polygon = PackedVector2Array([
		Vector2(0, -21),
		Vector2(21, 0),
		Vector2(0, 21),
		Vector2(-21, 0)
	])
	root.add_child(plate)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = line_color
	ring.closed = true
	ring.points = PackedVector2Array([
		Vector2(0, -22),
		Vector2(22, 0),
		Vector2(0, 22),
		Vector2(-22, 0)
	])
	root.add_child(ring)

func _add_ship_marker(root: Node2D, fill_color: Color, line_color: Color, hostile: bool) -> void:
	var body := Polygon2D.new()
	body.color = fill_color
	if hostile:
		body.polygon = PackedVector2Array([
			Vector2(0, -15),
			Vector2(14, 13),
			Vector2(0, 7),
			Vector2(-14, 13)
		])
	else:
		body.polygon = PackedVector2Array([
			Vector2(0, -17),
			Vector2(15, 12),
			Vector2(0, 6),
			Vector2(-15, 12)
		])
	root.add_child(body)
	var outline := Line2D.new()
	outline.width = 2.0
	outline.default_color = line_color
	outline.closed = true
	outline.points = body.polygon
	root.add_child(outline)
	var core := Polygon2D.new()
	core.color = Color(0.02, 0.05, 0.08, 0.76)
	core.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(6, 5),
		Vector2(0, 2),
		Vector2(-6, 5)
	])
	root.add_child(core)

func _add_status_bar(root: Node2D, text: String, hp: int, max_hp: int, color: Color, offset: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = offset
	label.size = Vector2(92, 16)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(label)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.08, 0.72)
	bg.position = offset + Vector2(0, 17)
	bg.size = Vector2(58, 4)
	root.add_child(bg)
	var fg := ColorRect.new()
	fg.color = color
	fg.position = bg.position
	fg.size = Vector2(58.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), 4)
	root.add_child(fg)
