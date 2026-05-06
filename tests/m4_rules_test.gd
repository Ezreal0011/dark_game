extends SceneTree

const GridMapScript := preload("res://scripts/grid_map.gd")
const SignalManagerScript := preload("res://scripts/signal_manager.gd")
const TurnManagerScript := preload("res://scripts/turn_manager.gd")

func _init() -> void:
	var failed := false
	failed = failed or not _test_zone_rules()
	failed = failed or not _test_point_rules()
	failed = failed or not _test_black_domain_damage()
	failed = failed or not _test_black_domain_after_turn_income()
	failed = failed or not _test_black_domain_stage_scaling()
	failed = failed or not _test_delayed_move_signal_visibility()
	failed = failed or not _test_npc_move_signal_public_after_delay()
	if failed:
		quit(1)
	else:
		print("M4 规则测试通过")
		quit(0)

func _test_zone_rules() -> bool:
	var grid := GridMapScript.new()
	grid.setup(_config())
	var signal_manager := SignalManagerScript.new()
	signal_manager.setup(_config())
	var passed := true

	var silent_tile := Vector2i(4, 4)
	var echo_tile := Vector2i(7, 4)
	if grid.get_zone_type(silent_tile) != "silent":
		passed = _fail("静默区格子类型应为 silent")
	elif grid.should_leave_move_signal(silent_tile):
		passed = _fail("静默区移动不应留下移动轨迹")
	elif grid.get_zone_type(echo_tile) != "echo":
		passed = _fail("回声区格子类型应为 echo")

	signal_manager.add_move_signal(Vector2i(6, 4), echo_tile, grid.is_echo_zone(echo_tile))
	for i in range(3):
		signal_manager.decay_signals()
	var records := signal_manager.get_visible_signals(Vector2i(0, 0), 1)
	if passed and (records.size() != 1 or not bool(records[0]["public"])):
		passed = _fail("回声区移动轨迹应在延迟后生成全图公开信号")
	grid.free()
	signal_manager.free()
	return passed

func _test_point_rules() -> bool:
	var grid := GridMapScript.new()
	grid.setup(_config())
	var passed := true

	var resource_result: Dictionary = grid.collect_resource_point(Vector2i(3, 3))
	if int(resource_result.get("energy", 0)) != 4:
		passed = _fail("普通资源点采集应获得 4 暗能")
	elif grid.has_resource_point(Vector2i(3, 3)):
		passed = _fail("资源点采集后应消失")

	var skill_result: Dictionary = grid.pick_skill_point(Vector2i(6, 6))
	if passed and int(skill_result.get("level", 0)) != 2:
		passed = _fail("技能点拾取应返回等级")
	elif passed and grid.has_skill_point(Vector2i(6, 6)):
		passed = _fail("技能点拾取后应消失")
	grid.free()
	return passed

func _test_black_domain_damage() -> bool:
	var grid := GridMapScript.new()
	grid.setup(_config())
	var passed := true
	grid.advance_collapse()
	if not grid.is_black_domain(Vector2i(0, 0)):
		passed = _fail("缩圈推进后外圈应变为黑域")

	var turn := TurnManagerScript.new()
	turn.setup(_config())
	turn.dark_energy = 1
	var hp := 3
	hp = turn.apply_black_domain_penalty(hp, 1)
	if passed and (turn.dark_energy != 0 or hp != 2):
		passed = _fail("黑域第 1 阶段应先扣暗能，暗能不足时扣 HP")
	grid.free()
	turn.free()
	return passed

func _test_black_domain_after_turn_income() -> bool:
	var turn := TurnManagerScript.new()
	turn.setup(_config())
	turn.dark_energy = 4
	var gained := turn.start_new_turn()
	var hp := turn.apply_black_domain_penalty(3, 1)
	var passed := true
	if gained != 2:
		passed = _fail("新回合应先获得暗能收入")
	elif turn.dark_energy != 4 or hp != 3:
		passed = _fail("黑域腐蚀应在回合收入后扣除暗能")
	turn.free()
	return passed

func _test_black_domain_stage_scaling() -> bool:
	var turn := TurnManagerScript.new()
	turn.setup(_config())
	var passed := true
	if turn.get_black_domain_penalty(1) != 2:
		passed = _fail("黑域第 1 阶段腐蚀强度应为 2")
	elif turn.get_black_domain_penalty(3) != 4:
		passed = _fail("黑域第 3 阶段腐蚀强度应为 4")
	turn.dark_energy = 1
	var hp := turn.apply_black_domain_penalty(5, 3)
	if passed and (turn.dark_energy != 0 or hp != 2):
		passed = _fail("黑域后期应造成更高 HP 损失")
	turn.free()
	return passed

func _test_delayed_move_signal_visibility() -> bool:
	var signal_manager := SignalManagerScript.new()
	signal_manager.setup(_config())
	var tile := Vector2i(2, 2)
	var from_tile := Vector2i(1, 2)
	var passed := true
	signal_manager.add_move_signal(from_tile, tile, true)
	if signal_manager.get_visible_signals(Vector2i.ZERO, 10).size() != 0:
		passed = _fail("移动轨迹不应在产生回合立刻显示")
	signal_manager.decay_signals()
	if passed and signal_manager.get_visible_signals(Vector2i.ZERO, 10).size() != 0:
		passed = _fail("移动轨迹不应在下一回合立刻显示")
	signal_manager.decay_signals()
	if passed and signal_manager.get_visible_signals(Vector2i.ZERO, 10).size() != 0:
		passed = _fail("移动轨迹不应在第二回合显示")
	signal_manager.decay_signals()
	var visible := signal_manager.get_visible_signals(Vector2i.ZERO, 10)
	if passed and (visible.size() != 1 or visible[0].get("tile", Vector2i.ZERO) != tile):
		passed = _fail("移动轨迹应在第三回合显示")
	elif passed and (visible[0].get("from_tile", Vector2i.ZERO) != from_tile or visible[0].get("to_tile", Vector2i.ZERO) != tile):
		passed = _fail("移动轨迹应保存起点和终点")
	for i in range(2):
		signal_manager.decay_signals()
	if passed and signal_manager.get_visible_signals(Vector2i.ZERO, 10).size() != 0:
		passed = _fail("移动轨迹应在 5 回合后消失")
	signal_manager.free()
	return passed

func _test_npc_move_signal_public_after_delay() -> bool:
	var signal_manager := SignalManagerScript.new()
	signal_manager.setup(_config())
	var from_tile := Vector2i(8, 7)
	var to_tile := Vector2i(9, 7)
	var passed := true
	signal_manager.add_move_signal(from_tile, to_tile, true)
	for i in range(3):
		signal_manager.decay_signals()
	var visible := signal_manager.get_visible_signals(Vector2i(0, 0), 1)
	if visible.size() != 1:
		passed = _fail("NPC 移动轨迹应在第三回合显示在公共地图上")
	elif not bool(visible[0].get("public", false)):
		passed = _fail("NPC 移动轨迹应为公共轨迹")
	signal_manager.free()
	return passed

func _config() -> Dictionary:
	return {
		"map_width": 10,
		"map_height": 8,
		"tile_size": 40,
		"use_authored_map": false,
		"resource_points": [{"x": 3, "y": 3, "energy": 4}],
		"skill_points": [{"x": 6, "y": 6, "level": 2}],
		"silent_zones": [{"x": 4, "y": 4}, {"x": 4, "y": 5}],
		"echo_zones": [{"x": 7, "y": 4}, {"x": 7, "y": 5}],
		"collapse_start_turn": 1,
		"collapse_interval_turns": 1,
		"black_domain_base_penalty": 2,
		"black_domain_penalty_per_stage": 1
	}

func _fail(message: String) -> bool:
	push_error(message)
	return false
