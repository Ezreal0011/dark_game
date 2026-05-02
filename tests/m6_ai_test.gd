extends SceneTree

const NpcAIScript := preload("res://scripts/npc_ai_controller.gd")

func _init() -> void:
	var failed := false
	failed = failed or not _test_escape_black_domain_first()
	failed = failed or not _test_track_visible_signal_without_player_position()
	failed = failed or not _test_seek_map_point_when_no_signal()
	if failed:
		quit(1)
	else:
		print("M6 AI 测试通过")
		quit(0)

func _test_escape_black_domain_first() -> bool:
	var ai := NpcAIScript.new()
	ai.setup(_config())
	var decision := ai.choose_action(_npc("猎手", Vector2i(0, 0)), _context([], [Vector2i(0, 0)], [Vector2i(1, 0), Vector2i(0, 1)], []))
	var passed := true
	if String(decision.get("action", "")) != "move":
		passed = _fail("NPC 在黑域内应优先移动脱离")
	elif decision.get("target", Vector2i.ZERO) == Vector2i(0, 0):
		passed = _fail("NPC 脱离黑域时不应原地等待")
	ai.free()
	return passed

func _test_track_visible_signal_without_player_position() -> bool:
	var ai := NpcAIScript.new()
	ai.setup(_config())
	var signals := [{"type": "move", "tile": Vector2i(5, 5), "strength": 4, "remaining": 2, "public": false}]
	var decision := ai.choose_action(_npc("侦察者", Vector2i(3, 5)), _context(signals, [], [Vector2i(4, 5), Vector2i(3, 6)], []))
	var passed := true
	if String(decision.get("reason", "")) != "追踪可见信号":
		passed = _fail("NPC 应基于可见信号决策，而不是玩家真实位置")
	elif decision.get("target", Vector2i.ZERO) != Vector2i(4, 5):
		passed = _fail("NPC 应朝强信号方向移动")
	ai.free()
	return passed

func _test_seek_map_point_when_no_signal() -> bool:
	var ai := NpcAIScript.new()
	ai.setup(_config())
	var decision := ai.choose_action(_npc("潜伏者", Vector2i(2, 2)), _context([], [], [Vector2i(3, 2), Vector2i(2, 3)], [Vector2i(5, 2)]))
	var passed := true
	if String(decision.get("reason", "")) != "争夺地图点":
		passed = _fail("没有信号时 NPC 应能争夺资源点或技能点")
	elif decision.get("target", Vector2i.ZERO) != Vector2i(3, 2):
		passed = _fail("NPC 应向最近地图点靠近")
	ai.free()
	return passed

func _npc(npc_type: String, tile: Vector2i) -> Dictionary:
	return {"id": "测试NPC", "type": npc_type, "tile": tile, "alive": true}

func _context(signals: Array, black_tiles: Array[Vector2i], move_options: Array[Vector2i], map_points: Array[Vector2i]) -> Dictionary:
	return {
		"visible_signals": signals,
		"black_tiles": black_tiles,
		"move_options": move_options,
		"map_points": map_points
	}

func _config() -> Dictionary:
	return {
		"npc_types": {
			"侦察者": {"signal_weight": 4, "map_point_weight": 2},
			"猎手": {"signal_weight": 5, "map_point_weight": 1},
			"潜伏者": {"signal_weight": 2, "map_point_weight": 4},
			"干扰者": {"signal_weight": 3, "map_point_weight": 3}
		}
	}

func _fail(message: String) -> bool:
	push_error(message)
	return false
