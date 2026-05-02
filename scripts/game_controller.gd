class_name GameController
extends Node2D

@onready var config_loader: ConfigLoader = $ConfigLoader
@onready var turn_manager: TurnManager = $TurnManager
@onready var signal_manager: SignalManager = $SignalManager
@onready var grid_map: DarkSignalGridMap = $GridMap
@onready var move_options_layer: Node2D = $GridMap/MoveOptions
@onready var signal_layer: Node2D = $GridMap/SignalLayer
@onready var scan_range_layer: Node2D = $GridMap/ScanRangeLayer
@onready var move_preview: Polygon2D = $GridMap/MovePreview
@onready var player: Polygon2D = $GridMap/Player
@onready var npc_layer: Node2D = $GridMap/NPCs
@onready var hud: HUD = $HUD

var player_tile := Vector2i(2, 2)
var hovered_tile := Vector2i(-1, -1)
var npcs: Array[Dictionary] = []
var player_has_acted := false
var resolving_npc_turn := false
var action_mode := "move"
var scan_range := 3
var attack_range := 4

func _ready() -> void:
	var config := config_loader.load_game_config()
	turn_manager.setup(config)
	signal_manager.setup(config)
	grid_map.setup(config)
	scan_range = int(config.get("scan_range", scan_range))
	attack_range = int(config.get("attack_range", attack_range))
	player_tile = Vector2i(
		int(config.get("player_start_x", player_tile.x)),
		int(config.get("player_start_y", player_tile.y))
	)
	_spawn_basic_npcs(int(config.get("npc_count", 3)))
	_update_player_position()
	_update_npc_markers()
	_redraw_signals()
	hud.setup(String(config.get("game_title", "暗林信号")), turn_manager.current_turn, turn_manager.dark_energy, turn_manager.max_dark_energy, _living_npc_count())
	hud.wait_pressed.connect(_on_wait_pressed)
	hud.scan_pressed.connect(_on_scan_pressed)
	hud.attack_pressed.connect(_on_attack_pressed)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.set_hover_text("悬停格：无")
	hud.set_action_hint("M3：NPC 默认不可见。观察移动、扫描、攻击信号来推理位置。")
	hud.add_log("M3 验证局开始：NPC 默认隐藏，只显示信号。")
	_refresh_move_options()
	await _show_player_turn_notice()

func _process(_delta: float) -> void:
	if resolving_npc_turn:
		return
	var tile := grid_map.world_to_grid(get_global_mouse_position())
	if tile != hovered_tile:
		hovered_tile = tile
		_update_hover(tile)

func _input(event: InputEvent) -> void:
	if player_has_acted or resolving_npc_turn:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hud.is_screen_point_over_hud(event.position):
			return
		_handle_tile_click(grid_map.world_to_grid(get_global_mouse_position()))

func _handle_tile_click(target_tile: Vector2i) -> void:
	if action_mode == "attack":
		_try_attack(target_tile)
	else:
		_try_move_to(target_tile)

func _try_move_to(target_tile: Vector2i) -> void:
	if not grid_map.is_inside(target_tile):
		hud.set_action_hint("目标不在地图内。")
		return
	if not grid_map.is_adjacent(player_tile, target_tile):
		hud.set_action_hint("只能移动到上下左右相邻格。")
		return
	if not grid_map.is_passable(target_tile):
		hud.set_action_hint("该格不可通行。")
		return
	if not turn_manager.try_spend_dark_energy(turn_manager.move_cost):
		hud.set_action_hint("暗能不足，无法移动。")
		return
	player_tile = target_tile
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_move_signal(player_tile)
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	_update_player_position()
	_redraw_signals()
	_refresh_hud()
	hud.set_action_hint("已移动到 %s，留下移动轨迹。点击“结束回合”结算 NPC。" % _tile_text(player_tile))
	hud.add_log("玩家移动到 %s，暗能 -%d，生成移动信号。" % [_tile_text(player_tile), turn_manager.move_cost])

func _try_scan(_target_tile: Vector2i) -> void:
	if not turn_manager.try_spend_dark_energy(turn_manager.scan_cost):
		hud.set_action_hint("暗能不足，无法扫描。")
		return
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_scan_signal(player_tile)
	move_preview.visible = false
	_clear_move_options()
	_show_scan_range()
	_play_scan_pulse()
	_redraw_signals()
	_refresh_hud()
	hud.set_mode("移动")
	hud.set_action_hint("扫描完成，扫描源产生紫色信号。点击“结束回合”结算 NPC。")
	hud.add_log("玩家扫描，暗能 -%d，生成扫描信号。" % turn_manager.scan_cost)

func _try_attack(target_tile: Vector2i) -> void:
	if not grid_map.is_inside(target_tile):
		hud.set_action_hint("攻击目标不在地图内。")
		return
	if _distance(player_tile, target_tile) > attack_range:
		hud.set_action_hint("攻击目标超出范围。")
		return
	if not turn_manager.try_spend_dark_energy(turn_manager.attack_cost):
		hud.set_action_hint("暗能不足，无法攻击。")
		return
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_attack_signal(player_tile)
	var hit := false
	for npc in npcs:
		if bool(npc["alive"]) and npc["tile"] == target_tile:
			hit = true
			npc["alive"] = false
			signal_manager.add_signal("death", target_tile, 5, 4, true)
			hud.add_log("攻击命中 %s，目标被清除。" % String(npc["id"]))
	if not hit:
		hud.add_log("攻击 %s 未命中。" % _tile_text(target_tile))
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	_update_npc_markers()
	_redraw_signals()
	_refresh_hud()
	hud.set_mode("移动")
	hud.set_action_hint("攻击完成，攻击源产生红色信号。点击“结束回合”结算 NPC。")

func _on_wait_pressed() -> void:
	if resolving_npc_turn:
		return
	if player_has_acted:
		hud.set_action_hint("本回合已经行动，不能再次等待。")
		return
	var gained := turn_manager.apply_wait_bonus()
	player_has_acted = true
	action_mode = "move"
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	_refresh_hud()
	hud.set_mode("移动")
	hud.set_action_hint("等待完成，额外恢复 %d 暗能。点击“结束回合”结算 NPC。" % gained)
	hud.add_log("玩家等待，暗能 +%d。" % gained)

func _on_scan_pressed() -> void:
	if player_has_acted or resolving_npc_turn:
		return
	_try_scan(player_tile)

func _on_attack_pressed() -> void:
	if player_has_acted or resolving_npc_turn:
		return
	action_mode = "attack"
	_clear_scan_range()
	hud.set_mode("攻击")
	hud.set_action_hint("攻击模式：点击你预测的 NPC 格子。范围 %d，消耗 %d 暗能。" % [attack_range, turn_manager.attack_cost])

func _on_end_turn_pressed() -> void:
	if resolving_npc_turn:
		return
	await _resolve_npc_turn_sequence()
	signal_manager.decay_signals()
	var gained := turn_manager.start_new_turn()
	player_has_acted = false
	resolving_npc_turn = false
	action_mode = "move"
	_clear_scan_range()
	hud.set_buttons_enabled(true)
	hud.set_mode("移动")
	_refresh_hud()
	_refresh_move_options()
	_redraw_signals()
	hud.set_action_hint("新回合开始，暗能 +%d。观察信号后选择移动、扫描或攻击。" % gained)
	hud.add_log("进入第 %d 回合，暗能 +%d，旧信号衰减。" % [turn_manager.current_turn, gained])
	_update_hover(hovered_tile)
	await _show_player_turn_notice()

func _resolve_npc_turn_sequence() -> void:
	resolving_npc_turn = true
	hud.set_buttons_enabled(false)
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	for npc in npcs:
		if not bool(npc["alive"]):
			continue
		var npc_id := String(npc["id"])
		hud.show_center_notice("%s 的回合" % npc_id)
		hud.set_action_hint("%s 正在行动。" % npc_id)
		await get_tree().create_timer(0.45).timeout
		_resolve_single_npc(npc)
		_update_npc_markers()
		_redraw_signals()
		await get_tree().create_timer(0.35).timeout
	hud.hide_center_notice()

func _resolve_single_npc(npc: Dictionary) -> void:
	var from_tile: Vector2i = npc["tile"]
	var target_tile := _choose_random_npc_tile(from_tile)
	if target_tile == from_tile:
		hud.add_log("%s 原地等待。" % String(npc["id"]))
	else:
		npc["tile"] = target_tile
		signal_manager.add_move_signal(target_tile)
		hud.add_log("%s 移动并留下轨迹。" % String(npc["id"]))

func _choose_random_npc_tile(from_tile: Vector2i) -> Vector2i:
	var options := [from_tile, from_tile + Vector2i.RIGHT, from_tile + Vector2i.LEFT, from_tile + Vector2i.DOWN, from_tile + Vector2i.UP]
	options.shuffle()
	for option in options:
		if option == from_tile:
			return option
		if grid_map.is_passable(option) and option != player_tile and not _is_npc_at(option):
			return option
	return from_tile

func _spawn_basic_npcs(count: int) -> void:
	var starts := [Vector2i(21, 13), Vector2i(19, 3), Vector2i(5, 12), Vector2i(16, 10)]
	for i in range(min(count, starts.size())):
		npcs.append({"id": "NPC-%d" % (i + 1), "tile": starts[i], "alive": true})

func _update_player_position() -> void:
	player.position = grid_map.grid_to_local_center(player_tile)

func _update_npc_markers() -> void:
	for child in npc_layer.get_children():
		child.queue_free()
	for npc in npcs:
		if not bool(npc["alive"]):
			continue
		var npc_tile: Vector2i = npc["tile"]
		if _distance(player_tile, npc_tile) > 1:
			continue
		var marker := Polygon2D.new()
		marker.color = Color(1.0, 0.35, 0.12, 1.0)
		marker.polygon = PackedVector2Array([Vector2(0, -13), Vector2(13, 13), Vector2(-13, 13)])
		marker.position = grid_map.grid_to_local_center(npc_tile)
		npc_layer.add_child(marker)

func _redraw_signals() -> void:
	for child in signal_layer.get_children():
		child.queue_free()
	for signal_record in signal_manager.get_visible_signals(player_tile, scan_range):
		var tile: Vector2i = signal_record["tile"]
		var strength := int(signal_record["strength"])
		var marker := Polygon2D.new()
		marker.color = signal_manager.get_signal_color(String(signal_record["type"]))
		var half := 10 + strength * 3
		marker.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
		marker.position = grid_map.grid_to_local_center(tile)
		signal_layer.add_child(marker)

func _show_scan_range() -> void:
	_clear_scan_range()
	for tile in _get_scan_range_tiles():
		var marker := Polygon2D.new()
		marker.color = Color(0.62, 0.28, 1.0, 0.20)
		marker.polygon = PackedVector2Array([Vector2(-19, -19), Vector2(19, -19), Vector2(19, 19), Vector2(-19, 19)])
		marker.position = grid_map.grid_to_local_center(tile)
		scan_range_layer.add_child(marker)

func _play_scan_pulse() -> void:
	var pulse := Polygon2D.new()
	pulse.color = Color(0.72, 0.35, 1.0, 0.42)
	pulse.polygon = PackedVector2Array([Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)])
	pulse.position = grid_map.grid_to_local_center(player_tile)
	scan_range_layer.add_child(pulse)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector2.ONE * float(scan_range * 2 + 1), 0.35)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.35)
	tween.tween_callback(pulse.queue_free)

func _clear_scan_range() -> void:
	for child in scan_range_layer.get_children():
		child.queue_free()

func _get_scan_range_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(player_tile.y - scan_range, player_tile.y + scan_range + 1):
		for x in range(player_tile.x - scan_range, player_tile.x + scan_range + 1):
			var tile := Vector2i(x, y)
			if grid_map.is_inside(tile) and _distance(player_tile, tile) <= scan_range:
				tiles.append(tile)
	return tiles

func _refresh_move_options() -> void:
	_clear_move_options()
	if player_has_acted or resolving_npc_turn:
		return
	if not turn_manager.can_spend_dark_energy(turn_manager.move_cost):
		return
	for tile in _get_player_move_options():
		var marker := Polygon2D.new()
		marker.color = Color(0.1, 0.9, 0.65, 0.32)
		marker.polygon = PackedVector2Array([Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18)])
		marker.position = grid_map.grid_to_local_center(tile)
		move_options_layer.add_child(marker)

func _clear_move_options() -> void:
	for child in move_options_layer.get_children():
		child.queue_free()

func _get_player_move_options() -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for tile in [player_tile + Vector2i.RIGHT, player_tile + Vector2i.LEFT, player_tile + Vector2i.DOWN, player_tile + Vector2i.UP]:
		if grid_map.is_passable(tile):
			options.append(tile)
	return options

func _update_hover(tile: Vector2i) -> void:
	if player_has_acted or resolving_npc_turn:
		move_preview.visible = false
		return
	if not grid_map.is_inside(tile):
		move_preview.visible = false
		hud.set_hover_text("悬停格：地图外")
		return
	var tile_info := grid_map.get_tile_info(tile)
	var passable_text := "可通行" if bool(tile_info["passable"]) else "不可通行"
	hud.set_hover_text("悬停格：%s 类型：%s %s" % [_tile_text(tile), _tile_type_name(String(tile_info["type"])), passable_text])
	var can_preview := action_mode == "move" and grid_map.is_adjacent(player_tile, tile) and grid_map.is_passable(tile) and turn_manager.can_spend_dark_energy(turn_manager.move_cost)
	move_preview.visible = can_preview
	if can_preview:
		move_preview.position = grid_map.grid_to_local_center(tile)
		hud.set_action_hint("移动预览：目标 %s，消耗 %d 暗能。" % [_tile_text(tile), turn_manager.move_cost])

func _show_player_turn_notice() -> void:
	hud.show_center_notice("你的回合")
	await get_tree().create_timer(0.8).timeout
	hud.hide_center_notice()

func _refresh_hud() -> void:
	hud.set_turn(turn_manager.current_turn)
	hud.set_dark_energy(turn_manager.dark_energy, turn_manager.max_dark_energy)
	hud.set_living_units(_living_npc_count())

func _living_npc_count() -> int:
	var count := 0
	for npc in npcs:
		if bool(npc["alive"]):
			count += 1
	return count

func _is_npc_at(tile: Vector2i) -> bool:
	for npc in npcs:
		if bool(npc["alive"]) and npc["tile"] == tile:
			return true
	return false

func _distance(a: Vector2i, b: Vector2i) -> int:
	var delta := (a - b).abs()
	return delta.x + delta.y

func _tile_text(tile: Vector2i) -> String:
	return "(%d,%d)" % [tile.x, tile.y]

func _tile_type_name(tile_type: String) -> String:
	if tile_type == "obstacle":
		return "障碍"
	return "深空"
