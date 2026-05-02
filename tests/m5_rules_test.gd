extends SceneTree

const SkillManagerScript := preload("res://scripts/skill_manager.gd")

func _init() -> void:
	var failed := false
	failed = failed or not _test_skill_config_and_pick_choices()
	failed = failed or not _test_skill_slots_and_cooldowns()
	failed = failed or not _test_tech_upgrade_rules()
	failed = failed or not _test_move_range_tiles()
	if failed:
		quit(1)
	else:
		print("M5 规则测试通过")
		quit(0)

func _test_skill_config_and_pick_choices() -> bool:
	var manager := SkillManagerScript.new()
	manager.setup(_skill_config(), _tech_config())
	var choices := manager.get_skill_choices(2)
	var passed := true
	if choices.size() != 3:
		passed = _fail("技能点应提供 3 个候选技能")
	elif String(choices[0].get("name", "")) == "":
		passed = _fail("候选技能应包含中文名称")
	manager.free()
	return passed

func _test_skill_slots_and_cooldowns() -> bool:
	var manager := SkillManagerScript.new()
	manager.setup(_skill_config(), _tech_config())
	var passed := true
	manager.learn_skill("fake_step")
	manager.learn_skill("line_snipe")
	manager.learn_skill("signal_shield")
	manager.learn_skill("short_blink")
	if manager.get_owned_skills().size() != 3:
		passed = _fail("技能槽最多应保留 3 个技能")
	if passed and not manager.can_use_skill("line_snipe", 10):
		passed = _fail("暗能足够且未冷却时应能释放技能")
	manager.mark_skill_used("line_snipe")
	if passed and manager.can_use_skill("line_snipe", 10):
		passed = _fail("技能释放后应进入冷却")
	manager.advance_cooldowns()
	manager.advance_cooldowns()
	if passed and not manager.can_use_skill("line_snipe", 10):
		passed = _fail("冷却推进后应能再次释放技能")
	manager.free()
	return passed

func _test_tech_upgrade_rules() -> bool:
	var manager := SkillManagerScript.new()
	manager.setup(_skill_config(), _tech_config())
	var passed := true
	if not manager.can_upgrade_tech("scout", 5):
		passed = _fail("暗能足够时应能升级侦察科技")
	var result := manager.upgrade_tech("scout")
	if int(result.get("cost", 0)) != 5:
		passed = _fail("侦察 Lv.2 升级消耗应为 5")
	if passed and manager.get_tech_level("scout") != 2:
		passed = _fail("科技升级后等级应增加")
	if passed and int(manager.get_tech_bonus("scout", "scan_range_bonus")) != 1:
		passed = _fail("侦察科技应提供扫描范围加成")
	manager.free()
	return passed

func _test_move_range_tiles() -> bool:
	var center := Vector2i(5, 5)
	var tiles := _range_tiles(center, 2)
	var passed := true
	if not tiles.has(Vector2i(7, 5)):
		passed = _fail("移动 Lv.2 后应显示 2 格外的可移动格")
	elif tiles.has(Vector2i(8, 5)):
		passed = _fail("移动范围不应显示超过当前移动力的格子")
	return passed

func _range_tiles(center: Vector2i, move_range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(center.y - move_range, center.y + move_range + 1):
		for x in range(center.x - move_range, center.x + move_range + 1):
			var tile := Vector2i(x, y)
			var distance: int = abs(tile.x - center.x) + abs(tile.y - center.y)
			if distance >= 1 and distance <= move_range:
				tiles.append(tile)
	return tiles

func _skill_config() -> Dictionary:
	return {
		"skill_slots": 3,
		"skill_pools": {
			"1": ["fake_step", "signal_decoy", "short_backstep"],
			"2": ["line_snipe", "signal_shield", "smoke_escape"],
			"3": ["shock_blast", "short_blink", "reverse_trace"],
			"4": ["delay_mine", "jam_cloud", "heavy_decoy"]
		},
		"skills": [
			{"id": "fake_step", "name": "假脚步", "type": "干扰", "cost": 2, "cooldown": 2, "range": 4, "shape": "point", "signal_strength": 2, "signal_duration": 2},
			{"id": "signal_decoy", "name": "信号诱饵", "type": "干扰", "cost": 2, "cooldown": 2, "range": 4, "shape": "area", "radius": 1, "signal_strength": 2, "signal_duration": 2},
			{"id": "short_backstep", "name": "短距后撤", "type": "逃生", "cost": 2, "cooldown": 2, "range": 1, "shape": "self", "signal_strength": 2, "signal_duration": 2},
			{"id": "line_snipe", "name": "直线狙击", "type": "攻击", "cost": 4, "cooldown": 2, "range": 6, "shape": "line", "signal_strength": 4, "signal_duration": 2},
			{"id": "signal_shield", "name": "信号护盾", "type": "防御", "cost": 3, "cooldown": 3, "range": 0, "shape": "self", "signal_strength": 2, "signal_duration": 2},
			{"id": "smoke_escape", "name": "烟幕脱离", "type": "逃生", "cost": 3, "cooldown": 3, "range": 2, "shape": "area", "radius": 1, "signal_strength": 3, "signal_duration": 2},
			{"id": "shock_blast", "name": "震荡爆破", "type": "攻击", "cost": 4, "cooldown": 3, "range": 4, "shape": "area", "radius": 1, "signal_strength": 4, "signal_duration": 2},
			{"id": "short_blink", "name": "短距跃迁", "type": "逃生", "cost": 3, "cooldown": 3, "range": 3, "shape": "point", "signal_strength": 4, "signal_duration": 2},
			{"id": "reverse_trace", "name": "轨迹反转", "type": "干扰", "cost": 3, "cooldown": 3, "range": 4, "shape": "area", "radius": 1, "signal_strength": 3, "signal_duration": 2},
			{"id": "delay_mine", "name": "延迟地雷", "type": "攻击", "cost": 5, "cooldown": 4, "range": 4, "shape": "point", "signal_strength": 4, "signal_duration": 3},
			{"id": "jam_cloud", "name": "干扰云", "type": "干扰", "cost": 4, "cooldown": 4, "range": 4, "shape": "area", "radius": 2, "signal_strength": 4, "signal_duration": 3},
			{"id": "heavy_decoy", "name": "大型诱饵", "type": "干扰", "cost": 4, "cooldown": 4, "range": 5, "shape": "area", "radius": 2, "signal_strength": 5, "signal_duration": 3}
		]
	}

func _tech_config() -> Dictionary:
	return {
		"techs": {
			"scout": {"name": "侦察", "levels": [{"level": 1, "cost": 0}, {"level": 2, "cost": 5, "scan_range_bonus": 1}, {"level": 3, "cost": 8, "scan_range_bonus": 2}]},
			"move": {"name": "移动", "levels": [{"level": 1, "cost": 0}, {"level": 2, "cost": 5, "move_range_bonus": 1}, {"level": 3, "cost": 8, "move_range_bonus": 2}]},
			"stealth": {"name": "隐匿", "levels": [{"level": 1, "cost": 0}, {"level": 2, "cost": 5, "signal_reduction": 1}, {"level": 3, "cost": 8, "signal_reduction": 2}]}
		}
	}

func _fail(message: String) -> bool:
	push_error(message)
	return false
