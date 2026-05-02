class_name SkillManager
extends Node

var skill_slots := 3
var skills_by_id: Dictionary = {}
var skill_pools: Dictionary = {}
var owned_skill_ids: Array[String] = []
var cooldowns: Dictionary = {}
var techs: Dictionary = {}
var tech_levels: Dictionary = {
	"scout": 1,
	"move": 1,
	"stealth": 1
}

func setup(skill_config: Dictionary, tech_config: Dictionary) -> void:
	skill_slots = int(skill_config.get("skill_slots", skill_slots))
	skill_pools = skill_config.get("skill_pools", {})
	skills_by_id.clear()
	for skill in skill_config.get("skills", []):
		var skill_data: Dictionary = skill
		skills_by_id[String(skill_data.get("id", ""))] = skill_data
	techs = tech_config.get("techs", {})
	for tech_id in techs.keys():
		if not tech_levels.has(String(tech_id)):
			tech_levels[String(tech_id)] = 1

func get_skill_choices(level: int) -> Array[Dictionary]:
	var pool_key := str(clampi(level, 1, 4))
	var ids: Array = skill_pools.get(pool_key, [])
	var choices: Array[Dictionary] = []
	for skill_id in ids:
		if skills_by_id.has(String(skill_id)):
			choices.append(skills_by_id[String(skill_id)])
		if choices.size() >= 3:
			break
	if choices.size() < 3:
		for fallback_id in skills_by_id.keys():
			if choices.size() >= 3:
				break
			var fallback_skill: Dictionary = skills_by_id[fallback_id]
			if not choices.has(fallback_skill):
				choices.append(fallback_skill)
	return choices

func learn_skill(skill_id: String, replace_index: int = -1) -> Dictionary:
	if not skills_by_id.has(skill_id):
		return {}
	if owned_skill_ids.has(skill_id):
		return skills_by_id[skill_id]
	if replace_index >= 0 and replace_index < owned_skill_ids.size():
		owned_skill_ids[replace_index] = skill_id
	elif owned_skill_ids.size() < skill_slots:
		owned_skill_ids.append(skill_id)
	else:
		owned_skill_ids[0] = skill_id
	if not cooldowns.has(skill_id):
		cooldowns[skill_id] = 0
	return skills_by_id[skill_id]

func get_owned_skills() -> Array[Dictionary]:
	var owned: Array[Dictionary] = []
	for skill_id in owned_skill_ids:
		if skills_by_id.has(skill_id):
			var skill: Dictionary = skills_by_id[skill_id].duplicate(true)
			skill["remaining_cooldown"] = int(cooldowns.get(skill_id, 0))
			owned.append(skill)
	return owned

func get_skill(skill_id: String) -> Dictionary:
	return skills_by_id.get(skill_id, {})

func can_use_skill(skill_id: String, dark_energy: int) -> bool:
	if not owned_skill_ids.has(skill_id):
		return false
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return false
	if int(cooldowns.get(skill_id, 0)) > 0:
		return false
	return dark_energy >= int(skill.get("cost", 0))

func mark_skill_used(skill_id: String) -> void:
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return
	cooldowns[skill_id] = int(skill.get("cooldown", 0))

func advance_cooldowns() -> void:
	for skill_id in cooldowns.keys():
		cooldowns[skill_id] = max(0, int(cooldowns[skill_id]) - 1)

func get_tech_level(tech_id: String) -> int:
	return int(tech_levels.get(tech_id, 1))

func can_upgrade_tech(tech_id: String, dark_energy: int) -> bool:
	var next_level := get_tech_level(tech_id) + 1
	var level_data := _get_tech_level_data(tech_id, next_level)
	if level_data.is_empty():
		return false
	return dark_energy >= int(level_data.get("cost", 0))

func upgrade_tech(tech_id: String) -> Dictionary:
	var next_level := get_tech_level(tech_id) + 1
	var level_data := _get_tech_level_data(tech_id, next_level)
	if level_data.is_empty():
		return {}
	tech_levels[tech_id] = next_level
	return level_data

func get_tech_bonus(tech_id: String, bonus_key: String) -> Variant:
	var level_data := _get_tech_level_data(tech_id, get_tech_level(tech_id))
	return level_data.get(bonus_key, 0)

func get_tech_summary() -> String:
	return "侦察 Lv.%d  移动 Lv.%d  隐匿 Lv.%d" % [
		get_tech_level("scout"),
		get_tech_level("move"),
		get_tech_level("stealth")
	]

func _get_tech_level_data(tech_id: String, level: int) -> Dictionary:
	if not techs.has(tech_id):
		return {}
	var tech: Dictionary = techs[tech_id]
	for level_data in tech.get("levels", []):
		var data: Dictionary = level_data
		if int(data.get("level", 0)) == level:
			return data
	return {}
