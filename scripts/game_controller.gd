class_name GameController
extends Node2D

@onready var config_loader: ConfigLoader = $ConfigLoader
@onready var turn_manager: TurnManager = $TurnManager
@onready var signal_manager: SignalManager = $SignalManager
@onready var skill_manager: Node = $SkillManager
@onready var npc_ai_controller: Node = $NpcAIController
@onready var grid_map: DarkSignalGridMap = $GridMap
@onready var move_options_layer: Node2D = $GridMap/MoveOptions
@onready var signal_layer: Node2D = $GridMap/SignalLayer
@onready var scan_range_layer: Node2D = $GridMap/ScanRangeLayer
@onready var point_layer: Node2D = $GridMap/PointLayer
@onready var attack_feedback_layer: Node2D = $GridMap/AttackFeedbackLayer
@onready var skill_preview_layer: Node2D = $GridMap/SkillPreviewLayer
@onready var move_preview: Polygon2D = $GridMap/MovePreview
@onready var player: Polygon2D = $GridMap/Player
@onready var npc_layer: Node2D = $GridMap/NPCs
@onready var hud: HUD = $HUD

var player_tile := Vector2i(2, 2)
var hovered_tile := Vector2i(-1, -1)
var npcs: Array[Dictionary] = []
var player_has_acted := false
var resolving_npc_turn := false
var game_over := false
var action_mode := "move"
var scan_range := 3
var base_scan_range := 3
var attack_range := 4
var base_move_range := 1
var current_move_range := 1
var player_hp := 3
var npc_initial_hp := 2
var npc_initial_dark_energy := 4
var npc_scan_range := 5
var collapse_start_turn := 4
var collapse_interval_turns := 3
var selected_skill_id := ""
var gm_show_npcs := false

func _ready() -> void:
	var config := config_loader.load_game_config()
	turn_manager.setup(config)
	signal_manager.setup(config)
	skill_manager.setup(_load_json_config("res://configs/skill_config.json"), _load_json_config("res://configs/tech_config.json"))
	npc_ai_controller.setup(config)
	grid_map.setup(config)
	scan_range = int(config.get("scan_range", scan_range))
	base_scan_range = scan_range
	attack_range = int(config.get("attack_range", attack_range))
	player_hp = int(config.get("initial_player_hp", player_hp))
	npc_initial_hp = int(config.get("initial_npc_hp", npc_initial_hp))
	npc_initial_dark_energy = int(config.get("initial_npc_dark_energy", npc_initial_dark_energy))
	npc_scan_range = int(config.get("npc_scan_range", npc_scan_range))
	collapse_start_turn = int(config.get("collapse_start_turn", collapse_start_turn))
	collapse_interval_turns = int(config.get("collapse_interval_turns", collapse_interval_turns))
	player_tile = Vector2i(
		int(config.get("player_start_x", player_tile.x)),
		int(config.get("player_start_y", player_tile.y))
	)
	_spawn_basic_npcs(int(config.get("npc_count", 3)))
	_update_player_position()
	_update_npc_markers()
	_redraw_map_points()
	_redraw_signals()
	hud.setup(String(config.get("game_title", "暗林信号")), turn_manager.current_turn, turn_manager.dark_energy, turn_manager.max_dark_energy, _living_npc_count())
	hud.wait_pressed.connect(_on_wait_pressed)
	hud.scan_pressed.connect(_on_scan_pressed)
	hud.attack_pressed.connect(_on_attack_pressed)
	hud.collect_pressed.connect(_on_collect_pressed)
	hud.pick_skill_pressed.connect(_on_pick_skill_pressed)
	hud.tech_upgrade_pressed.connect(_on_tech_upgrade_pressed)
	hud.skill_slot_pressed.connect(_on_skill_slot_pressed)
	hud.skill_choice_pressed.connect(_on_skill_choice_pressed)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.gm_toggled.connect(_on_gm_toggled)
	hud.set_gm_enabled(gm_show_npcs)
	hud.set_player_hp(player_hp)
	_update_collapse_hud()
	hud.set_hover_text("悬停格：无")
	hud.set_action_hint("M6：NPC AI 已启用。NPC 会基于信号、地图点和黑域行动。")
	hud.add_log("M6 验证局开始：NPC 类型 AI 已启用，不读取玩家真实位置。")
	_refresh_m5_state_from_tech()
	_refresh_hud()
	_refresh_skill_hud()
	_refresh_move_options()
	await _show_player_turn_notice()

func _process(_delta: float) -> void:
	if game_over or resolving_npc_turn:
		return
	var tile := grid_map.world_to_grid(get_global_mouse_position())
	if tile != hovered_tile:
		hovered_tile = tile
		_update_hover(tile)

func _input(event: InputEvent) -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hud.is_screen_point_over_hud(event.position):
			return
		_handle_tile_click(grid_map.world_to_grid(get_global_mouse_position()))

func _handle_tile_click(target_tile: Vector2i) -> void:
	if action_mode == "attack":
		_try_attack(target_tile)
	elif action_mode == "skill":
		_try_use_selected_skill(target_tile)
	else:
		_try_move_to(target_tile)

func _try_move_to(target_tile: Vector2i) -> void:
	if not grid_map.is_inside(target_tile):
		hud.set_action_hint("目标不在地图内。")
		return
	var move_distance := _distance(player_tile, target_tile)
	if move_distance < 1 or move_distance > current_move_range:
		hud.set_action_hint("当前移动科技允许移动 %d 格。" % current_move_range)
		return
	if not grid_map.is_passable(target_tile):
		hud.set_action_hint("该格不可通行。")
		return
	var move_cost := move_distance * turn_manager.move_cost
	if not turn_manager.try_spend_dark_energy(move_cost):
		hud.set_action_hint("暗能不足，无法移动。")
		return
	player_tile = target_tile
	player_has_acted = true
	action_mode = "move"
	_add_move_signal_for_tile(player_tile)
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	_clear_skill_preview()
	_update_player_position()
	_redraw_signals()
	_refresh_hud()
	hud.set_action_hint("已移动到 %s。%s 点击“结束回合”结算 NPC。" % [_tile_text(player_tile), _zone_action_text(player_tile)])
	hud.add_log("玩家移动到 %s，暗能 -%d，%s" % [_tile_text(player_tile), move_cost, _zone_log_text(player_tile)])

func _try_scan(_target_tile: Vector2i) -> void:
	if not turn_manager.try_spend_dark_energy(turn_manager.scan_cost):
		hud.set_action_hint("暗能不足，无法扫描。")
		return
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_scan_signal(player_tile)
	_add_echo_broadcast_if_needed(player_tile, "扫描")
	move_preview.visible = false
	_clear_move_options()
	_clear_skill_preview()
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
	_add_echo_broadcast_if_needed(player_tile, "攻击")
	var hit := false
	for npc in npcs:
		if bool(npc["alive"]) and npc["tile"] == target_tile:
			hit = true
			npc["alive"] = false
			signal_manager.add_signal("death", target_tile, 5, 4, true)
			hud.add_log("攻击命中 %s，目标被清除。" % String(npc["id"]))
	if not hit:
		hud.add_log("攻击 %s 未命中。" % _tile_text(target_tile))
	_play_attack_feedback(target_tile, hit)
	move_preview.visible = false
	_clear_scan_range()
	_clear_move_options()
	_clear_skill_preview()
	_update_npc_markers()
	_redraw_signals()
	_refresh_hud()
	if _check_game_result():
		return
	hud.set_mode("移动")
	hud.set_action_hint("攻击完成，攻击源产生红色信号。点击“结束回合”结算 NPC。")

func _on_gm_toggled(enabled: bool) -> void:
	gm_show_npcs = enabled
	hud.set_gm_enabled(gm_show_npcs)
	_update_npc_markers()
	if gm_show_npcs:
		hud.set_action_hint("GM 显示已开启：所有存活 NPC 会持续显示，仅用于验收，不影响 AI。")
		hud.add_log("GM 显示 NPC：开启。")
	else:
		hud.set_action_hint("GM 显示已关闭：只显示玩家附近已暴露的 NPC。")
		hud.add_log("GM 显示 NPC：关闭。")

func _on_wait_pressed() -> void:
	if game_over or resolving_npc_turn:
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
	_clear_skill_preview()
	_refresh_hud()
	hud.set_mode("移动")
	hud.set_action_hint("等待完成，额外恢复 %d 暗能。点击“结束回合”结算 NPC。" % gained)
	hud.add_log("玩家等待，暗能 +%d。" % gained)

func _on_scan_pressed() -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	_try_scan(player_tile)

func _on_attack_pressed() -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	action_mode = "attack"
	selected_skill_id = ""
	_clear_scan_range()
	_clear_skill_preview()
	_show_attack_range()
	hud.set_mode("攻击")
	hud.set_action_hint("攻击模式：点击你预测的 NPC 格子。范围 %d，消耗 %d 暗能。" % [attack_range, turn_manager.attack_cost])

func _on_collect_pressed() -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	if not grid_map.has_resource_point(player_tile):
		hud.set_action_hint("当前位置没有资源点。")
		return
	var point := grid_map.collect_resource_point(player_tile)
	var gained := turn_manager.add_dark_energy(int(point.get("energy", 4)))
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_collect_signal(player_tile, grid_map.is_echo_zone(player_tile))
	_redraw_map_points()
	_redraw_signals()
	_clear_scan_range()
	_clear_move_options()
	_clear_skill_preview()
	_refresh_hud()
	hud.set_mode("移动")
	hud.set_action_hint("采集完成，暗能 +%d，并产生黄色采集信号。" % gained)
	hud.add_log("玩家采集资源点，暗能 +%d，资源点熄灭。" % gained)

func _on_pick_skill_pressed() -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	if not grid_map.has_skill_point(player_tile):
		hud.set_action_hint("当前位置没有技能点。")
		return
	if not turn_manager.try_spend_dark_energy(turn_manager.skill_pick_cost):
		hud.set_action_hint("暗能不足，无法拾取技能点。")
		return
	var point := grid_map.pick_skill_point(player_tile)
	var level := int(point.get("level", 1))
	player_has_acted = true
	action_mode = "move"
	signal_manager.add_skill_pick_signal(player_tile, level, grid_map.is_echo_zone(player_tile))
	_redraw_map_points()
	_redraw_signals()
	_clear_scan_range()
	_clear_move_options()
	_clear_skill_preview()
	_refresh_hud()
	hud.show_skill_choices(skill_manager.get_skill_choices(level))
	hud.set_mode("移动")
	hud.set_action_hint("拾取 Lv.%d 技能点完成，请在弹出的 3 张技能卡中选择一个。" % level)
	hud.add_log("玩家拾取 Lv.%d 技能点，暗能 -%d，产生技能波动并打开三选一。" % [level, turn_manager.skill_pick_cost])

func _on_skill_choice_pressed(skill_id: String) -> void:
	var learned: Dictionary = skill_manager.learn_skill(skill_id)
	hud.hide_skill_choices()
	_refresh_skill_hud()
	if learned.is_empty():
		hud.set_action_hint("技能选择失败：配置中找不到该技能。")
		return
	hud.show_center_notice("获得技能：%s" % String(learned.get("name", "未知技能")))
	hud.add_log("获得技能：%s。技能已放入技能槽。" % String(learned.get("name", "未知技能")))
	_auto_hide_notice()

func _on_skill_slot_pressed(slot_index: int) -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	var skills: Array[Dictionary] = skill_manager.get_owned_skills()
	if slot_index >= skills.size():
		hud.set_action_hint("该技能槽为空。")
		return
	var skill: Dictionary = skills[slot_index]
	var skill_id := String(skill.get("id", ""))
	if not skill_manager.can_use_skill(skill_id, turn_manager.dark_energy):
		hud.set_action_hint("%s 暂不可用：暗能不足或仍在冷却。" % String(skill.get("name", "技能")))
		return
	selected_skill_id = skill_id
	action_mode = "skill"
	hud.set_mode("技能")
	_show_skill_cast_range(skill)
	if String(skill.get("shape", "point")) == "self":
		_try_use_selected_skill(player_tile)
	else:
		hud.set_action_hint("技能模式：%s。点击范围内目标格释放，区域/直线范围已显示。" % String(skill.get("name", "技能")))

func _on_tech_upgrade_pressed(tech_id: String) -> void:
	if game_over or player_has_acted or resolving_npc_turn:
		return
	if not skill_manager.can_upgrade_tech(tech_id, turn_manager.dark_energy):
		hud.set_action_hint("暗能不足或该科技已满级。")
		return
	var data: Dictionary = skill_manager.upgrade_tech(tech_id)
	var cost := int(data.get("cost", 0))
	if not turn_manager.try_spend_dark_energy(cost):
		return
	player_has_acted = true
	action_mode = "move"
	selected_skill_id = ""
	_clear_skill_preview()
	_refresh_m5_state_from_tech()
	_refresh_hud()
	_refresh_skill_hud()
	hud.show_center_notice("科技升级")
	hud.set_action_hint("%s 升级到 Lv.%d，暗能 -%d。" % [_tech_name(tech_id), skill_manager.get_tech_level(tech_id), cost])
	hud.add_log("%s 科技升级到 Lv.%d，暗能 -%d。" % [_tech_name(tech_id), skill_manager.get_tech_level(tech_id), cost])
	_auto_hide_notice()

func _on_end_turn_pressed() -> void:
	if game_over or resolving_npc_turn:
		return
	await _resolve_npc_turn_sequence()
	signal_manager.decay_signals()
	skill_manager.advance_cooldowns()
	var gained := turn_manager.start_new_turn()
	var black_domain_report := _apply_collapse_for_current_turn()
	player_has_acted = false
	resolving_npc_turn = false
	action_mode = "move"
	_clear_scan_range()
	hud.set_mode("移动")
	selected_skill_id = ""
	_clear_skill_preview()
	_refresh_hud()
	_refresh_skill_hud()
	_update_collapse_hud()
	if _check_game_result():
		return
	hud.set_buttons_enabled(true)
	_refresh_action_states()
	_refresh_skill_hud()
	_refresh_move_options()
	_redraw_signals()
	var black_loss := int(black_domain_report.get("energy_loss", 0))
	var hp_loss := int(black_domain_report.get("hp_loss", 0))
	if black_loss > 0 or hp_loss > 0:
		hud.set_action_hint("新回合开始，暗能 +%d；黑域腐蚀暗能 -%d，HP -%d。" % [gained, black_loss, hp_loss])
	else:
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
		if game_over:
			break
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
	var decision: Dictionary = npc_ai_controller.choose_action(npc, _build_npc_ai_context(npc))
	var target_tile: Vector2i = decision.get("target", from_tile)
	if target_tile == from_tile:
		hud.add_log("%s（%s）原地等待：%s。" % [String(npc["id"]), String(npc.get("type", "NPC")), String(decision.get("reason", "等待"))])
	else:
		npc["tile"] = target_tile
		_play_npc_move_feedback(from_tile, target_tile)
		if grid_map.should_leave_move_signal(target_tile):
			signal_manager.add_move_signal(target_tile, grid_map.is_echo_zone(target_tile))
			hud.add_log("%s（%s）%s，移动并留下轨迹。" % [String(npc["id"]), String(npc.get("type", "NPC")), String(decision.get("reason", "行动"))])
		else:
			hud.add_log("%s（%s）%s，进入静默区，未留下轨迹。" % [String(npc["id"]), String(npc.get("type", "NPC")), String(decision.get("reason", "行动"))])

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
	var types := ["侦察者", "猎手", "潜伏者", "干扰者"]
	for i in range(min(count, starts.size())):
		npcs.append({
			"id": "NPC-%d" % (i + 1),
			"type": types[i % types.size()],
			"tile": starts[i],
			"alive": true,
			"hp": npc_initial_hp,
			"dark_energy": npc_initial_dark_energy
		})

func _build_npc_ai_context(npc: Dictionary) -> Dictionary:
	var npc_tile: Vector2i = npc["tile"]
	return {
		"visible_signals": _get_npc_visible_signals(npc_tile),
		"black_tiles": _get_black_domain_tiles(),
		"move_options": _get_npc_move_options(npc_tile),
		"map_points": _get_map_point_tiles()
	}

func _get_npc_visible_signals(npc_tile: Vector2i) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for signal_record in signal_manager.signals:
		var record: Dictionary = signal_record
		var tile: Vector2i = record.get("tile", Vector2i.ZERO)
		if bool(record.get("public", false)) or _distance(npc_tile, tile) <= npc_scan_range:
			visible.append(record)
	return visible

func _get_npc_move_options(from_tile: Vector2i) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for tile in [from_tile, from_tile + Vector2i.RIGHT, from_tile + Vector2i.LEFT, from_tile + Vector2i.DOWN, from_tile + Vector2i.UP]:
		if tile == from_tile:
			options.append(tile)
		elif grid_map.is_passable(tile) and not _is_npc_at(tile):
			options.append(tile)
	return options

func _get_map_point_tiles() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for tile in grid_map.resource_points.keys():
		points.append(tile)
	for tile in grid_map.skill_points.keys():
		points.append(tile)
	return points

func _get_black_domain_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(grid_map.map_height):
		for x in range(grid_map.map_width):
			var tile := Vector2i(x, y)
			if grid_map.is_black_domain(tile):
				tiles.append(tile)
	return tiles

func _update_player_position() -> void:
	player.position = grid_map.grid_to_local_center(player_tile)

func _update_npc_markers() -> void:
	for child in npc_layer.get_children():
		child.queue_free()
	for npc in npcs:
		if not bool(npc["alive"]):
			continue
		var npc_tile: Vector2i = npc["tile"]
		if not gm_show_npcs and _distance(player_tile, npc_tile) > 1:
			continue
		var marker := Polygon2D.new()
		marker.color = Color(1.0, 0.35, 0.12, 1.0) if not gm_show_npcs else Color(1.0, 0.78, 0.16, 0.95)
		marker.polygon = PackedVector2Array([Vector2(0, -13), Vector2(13, 13), Vector2(-13, 13)])
		marker.position = grid_map.grid_to_local_center(npc_tile)
		npc_layer.add_child(marker)
		if gm_show_npcs:
			var label := Label.new()
			label.text = "%s\n%s" % [String(npc["id"]), String(npc.get("type", "NPC"))]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
			label.position = marker.position + Vector2(-32, 14)
			label.size = Vector2(64, 34)
			npc_layer.add_child(label)

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

func _try_use_selected_skill(target_tile: Vector2i) -> void:
	if selected_skill_id == "":
		hud.set_action_hint("未选择技能。")
		return
	var skill: Dictionary = skill_manager.get_skill(selected_skill_id)
	if skill.is_empty():
		hud.set_action_hint("技能配置不存在。")
		return
	if not skill_manager.can_use_skill(selected_skill_id, turn_manager.dark_energy):
		hud.set_action_hint("%s 暂不可用：暗能不足或仍在冷却。" % String(skill.get("name", "技能")))
		return
	var shape := String(skill.get("shape", "point"))
	if shape != "self":
		if not grid_map.is_inside(target_tile):
			hud.set_action_hint("技能目标不在地图内。")
			return
		if _distance(player_tile, target_tile) > int(skill.get("range", 0)):
			hud.set_action_hint("技能目标超出范围。")
			return
	var cost := int(skill.get("cost", 0))
	if not turn_manager.try_spend_dark_energy(cost):
		hud.set_action_hint("暗能不足，无法释放技能。")
		return
	var affected_tiles := _get_skill_affected_tiles(skill, target_tile)
	var skill_name := String(skill.get("name", "技能"))
	var hit_count := _apply_skill_effect(skill, target_tile, affected_tiles)
	var signal_strength: int = max(1, int(skill.get("signal_strength", 2)) - int(skill_manager.get_tech_bonus("stealth", "signal_reduction")))
	var signal_duration: int = int(skill.get("signal_duration", 2))
	for tile in affected_tiles:
		signal_manager.add_signal("skill", tile, signal_strength, signal_duration, grid_map.is_echo_zone(player_tile))
	_play_skill_feedback(affected_tiles, String(skill.get("type", "技能")))
	skill_manager.mark_skill_used(selected_skill_id)
	player_has_acted = true
	action_mode = "move"
	selected_skill_id = ""
	move_preview.visible = false
	_clear_skill_preview()
	_clear_move_options()
	_update_player_position()
	_update_npc_markers()
	_redraw_signals()
	_refresh_hud()
	_refresh_skill_hud()
	if hit_count > 0:
		hud.add_log("释放 %s，命中 %d 个目标，暗能 -%d。" % [skill_name, hit_count, cost])
	else:
		hud.add_log("释放 %s，暗能 -%d，产生战术信号。" % [skill_name, cost])
	hud.show_center_notice(skill_name)
	_auto_hide_notice()
	if _check_game_result():
		return
	hud.set_mode("移动")
	hud.set_action_hint("%s 已释放并进入冷却。点击“结束回合”结算 NPC。" % skill_name)

func _apply_skill_effect(skill: Dictionary, target_tile: Vector2i, affected_tiles: Array[Vector2i]) -> int:
	var skill_type := String(skill.get("type", "技能"))
	var skill_id := String(skill.get("id", ""))
	if skill_id == "short_blink" and grid_map.is_passable(target_tile):
		player_tile = target_tile
		return 0
	if skill_id == "short_backstep":
		var back_tile := player_tile + Vector2i.LEFT
		if grid_map.is_passable(back_tile):
			player_tile = back_tile
		return 0
	if skill_type != "攻击":
		return 0
	var hit_count := 0
	for npc in npcs:
		if not bool(npc["alive"]):
			continue
		var npc_tile: Vector2i = npc["tile"]
		if affected_tiles.has(npc_tile):
			npc["alive"] = false
			hit_count += 1
			signal_manager.add_signal("death", npc_tile, 5, 4, true)
	return hit_count

func _show_attack_range() -> void:
	_clear_skill_preview()
	for tile in _get_tiles_in_range(player_tile, attack_range):
		_add_skill_preview_marker(tile, Color(1.0, 0.28, 0.12, 0.18))

func _show_attack_target_preview(target_tile: Vector2i) -> void:
	_show_attack_range()
	if not grid_map.is_inside(target_tile):
		return
	if _distance(player_tile, target_tile) <= attack_range:
		_add_skill_preview_marker(target_tile, Color(1.0, 0.18, 0.05, 0.48))

func _show_skill_cast_range(skill: Dictionary) -> void:
	_clear_skill_preview()
	for tile in _get_tiles_in_range(player_tile, int(skill.get("range", 0))):
		_add_skill_preview_marker(tile, Color(0.84, 0.24, 1.0, 0.20))

func _show_skill_target_preview(skill: Dictionary, target_tile: Vector2i) -> void:
	_show_skill_cast_range(skill)
	if not grid_map.is_inside(target_tile):
		return
	var affected_tiles := _get_skill_affected_tiles(skill, target_tile)
	for tile in affected_tiles:
		_add_skill_preview_marker(tile, Color(1.0, 0.25, 0.55, 0.42))

func _clear_skill_preview() -> void:
	for child in skill_preview_layer.get_children():
		child.queue_free()

func _add_skill_preview_marker(tile: Vector2i, color: Color) -> void:
	var marker := Polygon2D.new()
	marker.color = color
	marker.polygon = PackedVector2Array([Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18)])
	marker.position = grid_map.grid_to_local_center(tile)
	skill_preview_layer.add_child(marker)

func _play_skill_feedback(tiles: Array[Vector2i], skill_type: String) -> void:
	for tile in tiles:
		var pulse := Polygon2D.new()
		pulse.color = Color(1.0, 0.24, 0.48, 0.58) if skill_type == "攻击" else Color(0.58, 0.28, 1.0, 0.50)
		pulse.polygon = PackedVector2Array([Vector2(0, -20), Vector2(20, 0), Vector2(0, 20), Vector2(-20, 0)])
		pulse.position = grid_map.grid_to_local_center(tile)
		attack_feedback_layer.add_child(pulse)
		var tween := create_tween()
		tween.tween_property(pulse, "scale", Vector2.ONE * 1.6, 0.32)
		tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.32)
		tween.tween_callback(pulse.queue_free)

func _play_npc_move_feedback(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var from_pos := grid_map.grid_to_local_center(from_tile)
	var to_pos := grid_map.grid_to_local_center(to_tile)
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.78, 0.16, 0.70)
	line.add_point(from_pos)
	line.add_point(to_pos)
	attack_feedback_layer.add_child(line)
	var pulse := Polygon2D.new()
	pulse.color = Color(1.0, 0.78, 0.16, 0.55)
	pulse.polygon = PackedVector2Array([Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)])
	pulse.position = to_pos
	attack_feedback_layer.add_child(pulse)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.45)
	tween.parallel().tween_property(pulse, "scale", Vector2.ONE * 1.5, 0.45)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.45)
	tween.tween_callback(line.queue_free)
	tween.tween_callback(pulse.queue_free)

func _get_skill_affected_tiles(skill: Dictionary, target_tile: Vector2i) -> Array[Vector2i]:
	var shape := String(skill.get("shape", "point"))
	if shape == "self":
		return [player_tile]
	if shape == "area":
		return _get_tiles_in_range(target_tile, int(skill.get("radius", 1)))
	if shape == "line":
		return _get_line_tiles(player_tile, target_tile, int(skill.get("range", 1)))
	return [target_tile] if grid_map.is_inside(target_tile) else []

func _get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var tile := Vector2i(x, y)
			if grid_map.is_inside(tile) and _distance(center, tile) <= radius:
				tiles.append(tile)
	return tiles

func _get_line_tiles(from_tile: Vector2i, target_tile: Vector2i, max_range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var delta := target_tile - from_tile
	var step := Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		step.x = signi(delta.x)
	else:
		step.y = signi(delta.y)
	if step == Vector2i.ZERO:
		return [from_tile]
	var current := from_tile
	for i in range(max_range):
		current += step
		if not grid_map.is_inside(current):
			break
		tiles.append(current)
		if current == target_tile:
			break
	return tiles

func _refresh_m5_state_from_tech() -> void:
	scan_range = base_scan_range + int(skill_manager.get_tech_bonus("scout", "scan_range_bonus"))
	current_move_range = base_move_range + int(skill_manager.get_tech_bonus("move", "move_range_bonus"))

func _tech_name(tech_id: String) -> String:
	if tech_id == "scout":
		return "侦察"
	if tech_id == "move":
		return "移动"
	if tech_id == "stealth":
		return "隐匿"
	return tech_id

func _load_json_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("缺少配置表：" + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("配置表格式错误：" + path)
		return {}
	return parsed

func _redraw_map_points() -> void:
	for child in point_layer.get_children():
		child.queue_free()
	for point_tile in grid_map.resource_points.keys():
		_add_point_marker(point_tile, Color(1.0, 0.82, 0.15, 0.92), "R")
	for point_tile in grid_map.skill_points.keys():
		var point: Dictionary = grid_map.skill_points[point_tile]
		var level := int(point.get("level", 1))
		_add_point_marker(point_tile, Color(0.78, 0.22, 1.0, 0.92), "Lv.%d" % level)

func _add_point_marker(tile: Vector2i, color: Color, label_text: String) -> void:
	var marker := Polygon2D.new()
	marker.color = color
	marker.polygon = PackedVector2Array([Vector2(0, -14), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)])
	marker.position = grid_map.grid_to_local_center(tile)
	point_layer.add_child(marker)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.1, 1.0))
	label.position = marker.position - Vector2(20, 10)
	label.size = Vector2(40, 20)
	point_layer.add_child(label)

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
	for y in range(player_tile.y - current_move_range, player_tile.y + current_move_range + 1):
		for x in range(player_tile.x - current_move_range, player_tile.x + current_move_range + 1):
			var tile := Vector2i(x, y)
			var move_distance := _distance(player_tile, tile)
			if move_distance < 1 or move_distance > current_move_range:
				continue
			if not grid_map.is_passable(tile):
				continue
			if not turn_manager.can_spend_dark_energy(move_distance * turn_manager.move_cost):
				continue
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
	hud.set_hover_text("悬停格：%s 类型：%s %s %s" % [_tile_text(tile), _tile_type_name(String(tile_info["type"])), passable_text, _point_hover_text(tile)])
	var can_preview := action_mode == "move" and grid_map.is_adjacent(player_tile, tile) and grid_map.is_passable(tile) and turn_manager.can_spend_dark_energy(turn_manager.move_cost)
	if action_mode == "move":
		can_preview = _distance(player_tile, tile) >= 1 and _distance(player_tile, tile) <= current_move_range and grid_map.is_passable(tile) and turn_manager.can_spend_dark_energy(_distance(player_tile, tile) * turn_manager.move_cost)
	move_preview.visible = can_preview
	if can_preview:
		move_preview.position = grid_map.grid_to_local_center(tile)
		hud.set_action_hint("移动预览：目标 %s，消耗 %d 暗能。" % [_tile_text(tile), _distance(player_tile, tile) * turn_manager.move_cost])
	if action_mode == "skill" and selected_skill_id != "":
		_show_skill_target_preview(skill_manager.get_skill(selected_skill_id), tile)
	if action_mode == "attack":
		_show_attack_target_preview(tile)
	if action_mode == "move" and tile == player_tile and not player_has_acted:
		_update_current_tile_action_hint()

func _show_player_turn_notice() -> void:
	hud.show_center_notice("你的回合")
	await get_tree().create_timer(0.8).timeout
	hud.hide_center_notice()

func _refresh_hud() -> void:
	hud.set_turn(turn_manager.current_turn)
	hud.set_dark_energy(turn_manager.dark_energy, turn_manager.max_dark_energy)
	hud.set_living_units(_living_npc_count())
	hud.set_player_hp(player_hp)
	_refresh_action_states()

func _refresh_action_states() -> void:
	var can_use_action := not game_over and not resolving_npc_turn and not player_has_acted
	var can_end_turn := not game_over and not resolving_npc_turn
	hud.set_action_buttons_state(
		can_use_action,
		can_use_action and turn_manager.can_spend_dark_energy(turn_manager.scan_cost),
		can_use_action and turn_manager.can_spend_dark_energy(turn_manager.attack_cost),
		can_use_action and grid_map.has_resource_point(player_tile),
		can_use_action and grid_map.has_skill_point(player_tile) and turn_manager.can_spend_dark_energy(turn_manager.skill_pick_cost),
		can_end_turn
	)
	hud.set_tech_buttons_state(
		can_use_action and skill_manager.can_upgrade_tech("scout", turn_manager.dark_energy),
		can_use_action and skill_manager.can_upgrade_tech("move", turn_manager.dark_energy),
		can_use_action and skill_manager.can_upgrade_tech("stealth", turn_manager.dark_energy)
	)

func _refresh_skill_hud() -> void:
	hud.update_skill_slots(skill_manager.get_owned_skills())
	hud.set_tech_summary(skill_manager.get_tech_summary())

func _check_game_result() -> bool:
	if game_over:
		return true
	if player_hp <= 0:
		game_over = true
		player_has_acted = true
		resolving_npc_turn = false
		move_preview.visible = false
		_clear_scan_range()
		_clear_move_options()
		hud.set_buttons_enabled(false)
		hud.show_center_notice("失败")
		hud.set_action_hint("玩家被黑域吞没，本局结束。")
		hud.add_log("结算：玩家信号湮灭，本局失败。")
		return true
	if _living_npc_count() <= 0:
		game_over = true
		player_has_acted = true
		resolving_npc_turn = false
		move_preview.visible = false
		_clear_scan_range()
		_clear_move_options()
		_refresh_hud()
		hud.set_buttons_enabled(false)
		hud.show_center_notice("胜利")
		hud.set_action_hint("所有 NPC 已被清除，你在暗林中存活下来。")
		hud.add_log("结算：所有 NPC 已被清除，玩家胜利。")
		return true
	return false

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
	if tile_type == "silent_zone":
		return "静默区"
	if tile_type == "echo_zone":
		return "回声区"
	if tile_type == "black_domain":
		return "黑域"
	return "深空"

func _point_hover_text(tile: Vector2i) -> String:
	if grid_map.has_resource_point(tile):
		var point := grid_map.get_resource_point(tile)
		return "资源点：+%d 暗能" % int(point.get("energy", 4))
	if grid_map.has_skill_point(tile):
		var point := grid_map.get_skill_point(tile)
		return "技能点：Lv.%d" % int(point.get("level", 1))
	return ""

func _update_current_tile_action_hint() -> void:
	if grid_map.has_resource_point(player_tile):
		var resource := grid_map.get_resource_point(player_tile)
		hud.set_action_hint("当前位置有资源点，点击“采集”获得 +%d 暗能。" % int(resource.get("energy", 4)))
	elif grid_map.has_skill_point(player_tile):
		var skill_point := grid_map.get_skill_point(player_tile)
		hud.set_action_hint("当前位置有 Lv.%d 技能点，点击“拾取”打开三选一技能。" % int(skill_point.get("level", 1)))

func _add_move_signal_for_tile(tile: Vector2i) -> void:
	if grid_map.should_leave_move_signal(tile):
		signal_manager.add_move_signal(tile, grid_map.is_echo_zone(tile))

func _add_echo_broadcast_if_needed(tile: Vector2i, action_name: String) -> void:
	if grid_map.is_echo_zone(tile):
		signal_manager.add_signal("echo", tile, 5, 2, true)
		hud.add_log("%s 触发回声区广播，当前位置产生公开信号。" % action_name)

func _auto_hide_notice(duration: float = 0.85) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(duration).timeout.connect(func() -> void:
		if not game_over:
			hud.hide_center_notice()
	)

func _zone_action_text(tile: Vector2i) -> String:
	if grid_map.is_silent_zone(tile):
		return "静默区：本次移动不留轨迹。"
	if grid_map.is_echo_zone(tile):
		return "回声区：行动会公开广播。"
	if grid_map.is_black_domain(tile):
		return "黑域：回合推进时会腐蚀暗能或 HP。"
	return "已留下移动轨迹。"

func _zone_log_text(tile: Vector2i) -> String:
	if grid_map.is_silent_zone(tile):
		return "静默区未生成移动信号。"
	if grid_map.is_echo_zone(tile):
		return "回声区生成公开移动信号。"
	return "生成移动信号。"

func _turns_until_collapse() -> int:
	if turn_manager.current_turn < collapse_start_turn:
		return collapse_start_turn - turn_manager.current_turn
	var elapsed := turn_manager.current_turn - collapse_start_turn
	return collapse_interval_turns - (elapsed % collapse_interval_turns)

func _should_collapse_now() -> bool:
	if turn_manager.current_turn < collapse_start_turn:
		return false
	return (turn_manager.current_turn - collapse_start_turn) % collapse_interval_turns == 0

func _apply_collapse_for_current_turn() -> Dictionary:
	var before_energy := turn_manager.dark_energy
	var before_hp := player_hp
	if _should_collapse_now() and grid_map.advance_collapse():
		hud.add_log("黑域收缩一层：%s。" % grid_map.get_safe_bounds_text())
	var stage := grid_map.get_collapse_layer()
	if stage > 0:
		_apply_black_domain_to_npcs(stage)
	if grid_map.is_black_domain(player_tile):
		var penalty := turn_manager.get_black_domain_penalty(stage)
		player_hp = turn_manager.apply_black_domain_penalty(player_hp, stage)
		hud.add_log("玩家位于黑域第 %d 阶段，腐蚀强度 %d，暗能 %d -> %d，HP %d -> %d。" % [stage, penalty, before_energy, turn_manager.dark_energy, before_hp, player_hp])
		if player_hp <= 0:
			_check_game_result()
	return {
		"energy_loss": before_energy - turn_manager.dark_energy,
		"hp_loss": before_hp - player_hp
	}

func _update_collapse_hud() -> void:
	hud.set_collapse(_turns_until_collapse(), grid_map.get_safe_bounds_text())

func _apply_black_domain_to_npcs(stage: int) -> void:
	var penalty: int = turn_manager.get_black_domain_penalty(stage)
	for npc in npcs:
		if not bool(npc["alive"]):
			continue
		var npc_tile: Vector2i = npc["tile"]
		if not grid_map.is_black_domain(npc_tile):
			continue
		var before_energy: int = int(npc.get("dark_energy", 0))
		var before_hp: int = int(npc.get("hp", 1))
		var remaining: int = penalty
		var energy_loss: int = min(before_energy, remaining)
		npc["dark_energy"] = before_energy - energy_loss
		remaining -= energy_loss
		npc["hp"] = max(0, before_hp - remaining)
		hud.add_log("%s 位于黑域第 %d 阶段，腐蚀强度 %d，暗能 %d -> %d，HP %d -> %d。" % [
			String(npc["id"]),
			stage,
			penalty,
			before_energy,
			int(npc["dark_energy"]),
			before_hp,
			int(npc["hp"])
		])
		if int(npc["hp"]) <= 0:
			npc["alive"] = false
			signal_manager.add_signal("death", npc_tile, 5, 4, true)
			hud.add_log("%s 被黑域吞没，已消灭。" % String(npc["id"]))
	_refresh_hud()
	_update_npc_markers()

func _play_attack_feedback(target_tile: Vector2i, hit: bool) -> void:
	for child in attack_feedback_layer.get_children():
		child.queue_free()
	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.08, 0.02, 0.72) if hit else Color(1.0, 0.55, 0.16, 0.56)
	flash.polygon = PackedVector2Array([Vector2(0, -22), Vector2(7, -7), Vector2(22, 0), Vector2(7, 7), Vector2(0, 22), Vector2(-7, 7), Vector2(-22, 0), Vector2(-7, -7)])
	flash.position = grid_map.grid_to_local_center(target_tile)
	attack_feedback_layer.add_child(flash)
	var ring := Polygon2D.new()
	ring.color = Color(1.0, 0.18, 0.08, 0.34)
	ring.polygon = PackedVector2Array([Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)])
	ring.position = grid_map.grid_to_local_center(player_tile)
	attack_feedback_layer.add_child(ring)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.7, 0.28)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(ring, "scale", Vector2.ONE * 2.3, 0.28)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tween.tween_callback(flash.queue_free)
	tween.tween_callback(ring.queue_free)
