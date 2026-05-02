extends SceneTree

func _init() -> void:
	var failed := false
	failed = failed or not _test_project_web_settings()
	failed = failed or not _test_export_preset_exists()
	failed = failed or not _test_game_config_balance_floor()
	failed = failed or not _test_skill_and_tech_config_integrity()
	if failed:
		quit(1)
	else:
		print("M8 最终自检通过")
		quit(0)

func _test_project_web_settings() -> bool:
	var passed := true
	var renderer := String(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var mobile_renderer := String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if renderer != "gl_compatibility":
		passed = _fail("M8 Web 约束要求桌面渲染器为 gl_compatibility")
	elif mobile_renderer != "gl_compatibility":
		passed = _fail("M8 Web 约束要求移动渲染器为 gl_compatibility")
	elif main_scene != "res://scenes/Main.tscn":
		passed = _fail("主场景必须指向 Main.tscn")
	return passed

func _test_export_preset_exists() -> bool:
	var path := "res://export_presets.cfg"
	if not FileAccess.file_exists(path):
		return _fail("缺少 Web 导出预设 export_presets.cfg")
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	if not text.contains("platform=\"Web\""):
		return _fail("导出预设必须包含 Web 平台")
	if not text.contains("export_path=\"build/web/index.html\""):
		return _fail("Web 导出路径必须固定为 build/web/index.html")
	return true

func _test_game_config_balance_floor() -> bool:
	var config := _load_json("res://configs/game_config.json")
	var passed := true
	if int(config.get("map_width", 0)) < 16 or int(config.get("map_height", 0)) < 10:
		passed = _fail("地图尺寸过小，不满足第一版验收")
	elif int(config.get("initial_dark_energy", 0)) < int(config.get("move_cost", 1)) + int(config.get("scan_cost", 1)):
		passed = _fail("初始暗能至少应支持一次移动和一次扫描的规划空间")
	elif int(config.get("attack_range", 0)) < int(config.get("scan_range", 0)):
		passed = _fail("攻击范围不应小于基础扫描范围")
	elif int(config.get("collapse_start_turn", 0)) < 3:
		passed = _fail("黑域不应过早收缩，第一版至少给玩家 3 回合适应")
	elif not config.has("resource_points") or not config.has("skill_points"):
		passed = _fail("配置必须包含资源点和技能点")
	return passed

func _test_skill_and_tech_config_integrity() -> bool:
	var skill_config := _load_json("res://configs/skill_config.json")
	var tech_config := _load_json("res://configs/tech_config.json")
	var passed := true
	var skills: Array = skill_config.get("skills", [])
	var pools: Dictionary = skill_config.get("skill_pools", {})
	if int(skill_config.get("skill_slots", 0)) != 3:
		passed = _fail("第一版技能槽数量应为 3")
	elif skills.size() < 8:
		passed = _fail("技能配置数量不足，无法覆盖技能点验收")
	for pool_id in pools.keys():
		var pool: Array = pools[pool_id]
		if passed and pool.size() != 3:
			passed = _fail("每个技能点等级必须提供 3 个候选技能")
	if passed:
		var techs: Dictionary = tech_config.get("techs", {})
		for tech_id in ["scout", "move", "stealth"]:
			if not techs.has(tech_id):
				passed = _fail("缺少科技配置：" + tech_id)
			else:
				var tech: Dictionary = techs[tech_id]
				var levels: Array = tech.get("levels", [])
				if levels.size() < 3:
					passed = _fail("科技至少需要 3 个等级：" + tech_id)
	return passed

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("缺少配置文件：" + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("配置文件不是 Dictionary：" + path)
		return {}
	return parsed

func _fail(message: String) -> bool:
	push_error(message)
	return false
