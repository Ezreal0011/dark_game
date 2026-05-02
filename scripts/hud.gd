class_name HUD
extends CanvasLayer

signal wait_pressed
signal scan_pressed
signal attack_pressed
signal collect_pressed
signal pick_skill_pressed
signal tech_upgrade_pressed(tech_id: String)
signal skill_slot_pressed(slot_index: int)
signal skill_choice_pressed(skill_id: String)
signal end_turn_pressed
signal gm_toggled(enabled: bool)

@onready var title_label: Label = $Root/TopBar/TitleLabel
@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var energy_label: Label = $Root/TopBar/EnergyLabel
@onready var unit_label: Label = $Root/TopBar/UnitLabel
@onready var hp_label: Label = $Root/TopBar/HpLabel
@onready var collapse_label: Label = $Root/TopBar/CollapseLabel
@onready var mode_label: Label = $Root/TopBar/ModeLabel
@onready var wait_button: Button = $Root/TopBar/WaitButton
@onready var scan_button: Button = $Root/TopBar/ScanButton
@onready var attack_button: Button = $Root/TopBar/AttackButton
@onready var collect_button: Button = $Root/TopBar/CollectButton
@onready var pick_skill_button: Button = $Root/TopBar/PickSkillButton
@onready var end_turn_button: Button = $Root/TopBar/EndTurnButton
@onready var tech_summary_label: Label = $Root/TechPanel/TechBox/TechSummaryLabel
@onready var scout_tech_button: Button = $Root/TechPanel/TechBox/ScoutTechButton
@onready var move_tech_button: Button = $Root/TechPanel/TechBox/MoveTechButton
@onready var stealth_tech_button: Button = $Root/TechPanel/TechBox/StealthTechButton
@onready var gm_button: Button = $Root/TechPanel/TechBox/GMButton
@onready var skill_choice_panel: PanelContainer = $Root/SkillChoicePanel
@onready var choice_buttons: VBoxContainer = $Root/SkillChoicePanel/ChoiceBox/ChoiceButtons
@onready var skill_slot_buttons: Array[Button] = [
	$Root/BottomBar/SkillSlotRow/SkillSlot1,
	$Root/BottomBar/SkillSlotRow/SkillSlot2,
	$Root/BottomBar/SkillSlotRow/SkillSlot3
]
@onready var hover_label: Label = $Root/BottomBar/HoverLabel
@onready var action_hint_label: Label = $Root/BottomBar/ActionHintLabel
@onready var log_box: RichTextLabel = $Root/LogPanel/LogBox
@onready var center_notice: Label = $Root/CenterNotice
@onready var mini_map_label: Label = $Root/MiniMapPanel/MiniMapLabel

func _ready() -> void:
	wait_button.pressed.connect(func() -> void: wait_pressed.emit())
	scan_button.pressed.connect(func() -> void: scan_pressed.emit())
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	collect_button.pressed.connect(func() -> void: collect_pressed.emit())
	pick_skill_button.pressed.connect(func() -> void: pick_skill_pressed.emit())
	scout_tech_button.pressed.connect(func() -> void: tech_upgrade_pressed.emit("scout"))
	move_tech_button.pressed.connect(func() -> void: tech_upgrade_pressed.emit("move"))
	stealth_tech_button.pressed.connect(func() -> void: tech_upgrade_pressed.emit("stealth"))
	gm_button.toggled.connect(func(enabled: bool) -> void: gm_toggled.emit(enabled))
	for i in range(skill_slot_buttons.size()):
		var slot_index := i
		skill_slot_buttons[i].pressed.connect(func() -> void: skill_slot_pressed.emit(slot_index))
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())

func setup(title: String, turn: int, dark_energy: int, max_dark_energy: int, living_units: int) -> void:
	title_label.text = title
	set_turn(turn)
	set_dark_energy(dark_energy, max_dark_energy)
	set_living_units(living_units)
	set_mode("移动")

func set_turn(turn: int) -> void:
	turn_label.text = "回合：%d" % turn

func set_dark_energy(dark_energy: int, max_dark_energy: int) -> void:
	energy_label.text = "暗能：%d/%d" % [dark_energy, max_dark_energy]

func set_living_units(living_units: int) -> void:
	unit_label.text = "NPC：%d" % living_units

func set_player_hp(hp: int) -> void:
	hp_label.text = "HP：%d" % hp

func set_collapse(next_in: int, safe_text: String) -> void:
	collapse_label.text = "缩圈：%d" % next_in
	mini_map_label.text = "小地图\n%s\n黑域层数：%s" % [safe_text, collapse_label.text]

func set_tech_summary(text: String) -> void:
	tech_summary_label.text = "科技：" + text

func set_gm_enabled(enabled: bool) -> void:
	gm_button.set_pressed_no_signal(enabled)
	gm_button.text = "GM：开" if enabled else "GM：关"
	gm_button.disabled = false

func update_skill_slots(skills: Array[Dictionary]) -> void:
	for i in range(skill_slot_buttons.size()):
		var button := skill_slot_buttons[i]
		if i >= skills.size():
			button.text = "技能槽 %d：空" % (i + 1)
			button.disabled = false
			continue
		var skill := skills[i]
		var cooldown := int(skill.get("remaining_cooldown", 0))
		var suffix := " 冷却%d" % cooldown if cooldown > 0 else " 可用"
		button.text = "%d %s -%d%s" % [i + 1, String(skill.get("name", "未知技能")), int(skill.get("cost", 0)), suffix]
		button.disabled = cooldown > 0

func show_skill_choices(choices: Array[Dictionary]) -> void:
	for child in choice_buttons.get_children():
		child.queue_free()
	for choice in choices:
		var button := Button.new()
		var skill_id := String(choice.get("id", ""))
		button.text = "%s｜%s｜暗能%d｜冷却%d\n%s" % [
			String(choice.get("name", "未知技能")),
			String(choice.get("type", "技能")),
			int(choice.get("cost", 0)),
			int(choice.get("cooldown", 0)),
			String(choice.get("description", ""))
		]
		button.custom_minimum_size = Vector2(460, 54)
		button.pressed.connect(func() -> void: skill_choice_pressed.emit(skill_id))
		choice_buttons.add_child(button)
	skill_choice_panel.visible = true

func hide_skill_choices() -> void:
	skill_choice_panel.visible = false

func set_mode(mode_name: String) -> void:
	mode_label.text = "模式：%s" % mode_name

func set_hover_text(text: String) -> void:
	hover_label.text = text

func set_action_hint(text: String) -> void:
	action_hint_label.text = text

func show_feedback_hint(text: String) -> void:
	action_hint_label.text = text
	action_hint_label.modulate = Color(1.0, 0.78, 0.36, 1.0)
	var tween := create_tween()
	tween.tween_property(action_hint_label, "modulate", Color.WHITE, 0.28)

func add_log(text: String) -> void:
	log_box.append_text(text + "\n")

func show_center_notice(text: String) -> void:
	center_notice.text = text
	center_notice.visible = true

func hide_center_notice() -> void:
	center_notice.visible = false

func set_buttons_enabled(enabled: bool) -> void:
	wait_button.disabled = not enabled
	scan_button.disabled = not enabled
	attack_button.disabled = not enabled
	collect_button.disabled = not enabled
	pick_skill_button.disabled = not enabled
	end_turn_button.disabled = not enabled
	scout_tech_button.disabled = not enabled
	move_tech_button.disabled = not enabled
	stealth_tech_button.disabled = not enabled
	gm_button.disabled = false
	for button in skill_slot_buttons:
		button.disabled = not enabled

func set_action_buttons_state(can_wait: bool, can_scan: bool, can_attack: bool, can_collect: bool, can_pick_skill: bool, can_end_turn: bool) -> void:
	wait_button.disabled = not can_wait
	scan_button.disabled = not can_scan
	attack_button.disabled = not can_attack
	collect_button.disabled = not can_collect
	pick_skill_button.disabled = not can_pick_skill
	end_turn_button.disabled = not can_end_turn
	gm_button.disabled = false
	if not can_wait:
		for button in skill_slot_buttons:
			button.disabled = true

func set_tech_buttons_state(can_scout: bool, can_move: bool, can_stealth: bool) -> void:
	scout_tech_button.disabled = not can_scout
	move_tech_button.disabled = not can_move
	stealth_tech_button.disabled = not can_stealth
	gm_button.disabled = false

func is_screen_point_over_hud(screen_point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var in_top := screen_point.y < 64.0
	var in_bottom := screen_point.y > viewport_size.y - 132.0
	var in_log := screen_point.x > viewport_size.x - 360.0 and screen_point.y < 390.0
	var in_tech := screen_point.x < 310.0 and screen_point.y > 64.0 and screen_point.y < 280.0
	var in_choice := skill_choice_panel.visible and screen_point.x > viewport_size.x * 0.5 - 270.0 and screen_point.x < viewport_size.x * 0.5 + 270.0 and screen_point.y > viewport_size.y * 0.5 - 140.0 and screen_point.y < viewport_size.y * 0.5 + 150.0
	return in_top or in_bottom or in_log or in_tech or in_choice
