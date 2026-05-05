class_name HUD
extends CanvasLayer

const ICON_MANIFEST := "res://presentation/resources/icon_manifest.json"
const MINIMAP_WIDGET_SCRIPT := preload("res://presentation/ui/widgets/minimap_widget.gd")

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

@onready var root: Control = $Root
@onready var top_bar: HBoxContainer = $Root/TopBar
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
@onready var tech_panel: PanelContainer = $Root/TechPanel
@onready var tech_box: VBoxContainer = $Root/TechPanel/TechBox
@onready var tech_summary_label: Label = $Root/TechPanel/TechBox/TechSummaryLabel
@onready var scout_tech_button: Button = $Root/TechPanel/TechBox/ScoutTechButton
@onready var move_tech_button: Button = $Root/TechPanel/TechBox/MoveTechButton
@onready var stealth_tech_button: Button = $Root/TechPanel/TechBox/StealthTechButton
@onready var gm_button: Button = $Root/TechPanel/TechBox/GMButton
@onready var skill_choice_panel: PanelContainer = $Root/SkillChoicePanel
@onready var choice_buttons: VBoxContainer = $Root/SkillChoicePanel/ChoiceBox/ChoiceButtons
@onready var bottom_bar: VBoxContainer = $Root/BottomBar
@onready var skill_slot_buttons: Array[Button] = [
	$Root/BottomBar/SkillSlotRow/SkillSlot1,
	$Root/BottomBar/SkillSlotRow/SkillSlot2,
	$Root/BottomBar/SkillSlotRow/SkillSlot3
]
@onready var hover_label: Label = $Root/BottomBar/HoverLabel
@onready var action_hint_label: Label = $Root/BottomBar/ActionHintLabel
@onready var log_box: RichTextLabel = $Root/LogPanel/LogBox
@onready var center_notice: Label = $Root/CenterNotice
@onready var minimap_panel: PanelContainer = $Root/MiniMapPanel
@onready var mini_map_label: Label = $Root/MiniMapPanel/MiniMapLabel

var top_bar_frame: PanelContainer
var top_status_row: HBoxContainer
var top_status_label: Label
var action_button_row: HBoxContainer
var left_info_panel: PanelContainer
var left_info_label: Label
var minimap_box: VBoxContainer
var minimap_widget: MiniMapWidget
var icon_manifest: Dictionary = {}
var tech_levels := {"scout": 1, "move": 1, "stealth": 1}
var tech_upgrade_enabled := {"scout": false, "move": false, "stealth": false}
var status_title := "暗林信号"
var status_turn := 1
var status_energy := 0
var status_max_energy := 10
var status_npc := 0
var status_hp := 3
var status_collapse := 0
var status_mode := "移动"

func _ready() -> void:
	icon_manifest = _load_json(ICON_MANIFEST)
	_apply_m8_2_layout()
	_apply_m8_2_theme()
	_apply_m8_2_icons()
	_connect_buttons()

func setup(title: String, turn: int, dark_energy: int, max_dark_energy: int, living_units: int) -> void:
	status_title = title
	title_label.text = title
	set_turn(turn)
	set_dark_energy(dark_energy, max_dark_energy)
	set_living_units(living_units)
	set_mode("移动")

func set_turn(turn: int) -> void:
	status_turn = turn
	turn_label.text = "回合：%d" % turn
	_refresh_top_status_text()

func set_dark_energy(dark_energy: int, max_dark_energy: int) -> void:
	status_energy = dark_energy
	status_max_energy = max_dark_energy
	energy_label.text = "暗能：%d/%d" % [dark_energy, max_dark_energy]
	_refresh_top_status_text()

func set_living_units(living_units: int) -> void:
	status_npc = living_units
	unit_label.text = "NPC：%d" % living_units
	_refresh_top_status_text()

func set_player_hp(hp: int) -> void:
	status_hp = hp
	hp_label.text = "HP：%d" % hp
	_refresh_top_status_text()

func set_collapse(next_in: int, _safe_text: String) -> void:
	status_collapse = next_in
	collapse_label.text = "缩圈：%d" % next_in
	_refresh_top_status_text()

func set_tech_summary(_text: String) -> void:
	tech_summary_label.text = "科技树"

func set_tech_cards(scout_level: int, move_level: int, stealth_level: int) -> void:
	tech_levels["scout"] = scout_level
	tech_levels["move"] = move_level
	tech_levels["stealth"] = stealth_level
	_refresh_tech_button_texts()

func set_minimap_state(state: Dictionary) -> void:
	if minimap_widget != null:
		minimap_widget.set_state(state)
	var safe_text := String(state.get("safe_text", "安全区：未知"))
	mini_map_label.text = "小地图\n%s" % safe_text

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
		button.text = "%s｜%s｜暗能 %d｜冷却 %d\n%s" % [
			String(choice.get("name", "未知技能")),
			String(choice.get("type", "技能")),
			int(choice.get("cost", 0)),
			int(choice.get("cooldown", 0)),
			String(choice.get("description", ""))
		]
		button.custom_minimum_size = Vector2(460, 56)
		button.pressed.connect(func() -> void: skill_choice_pressed.emit(skill_id))
		choice_buttons.add_child(button)
	skill_choice_panel.visible = true

func hide_skill_choices() -> void:
	skill_choice_panel.visible = false

func set_mode(mode_name: String) -> void:
	status_mode = mode_name
	mode_label.text = "模式：%s" % mode_name
	_refresh_top_status_text()

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
	center_notice.modulate = Color(0.75, 0.96, 1.0, 0.0)
	center_notice.scale = Vector2.ONE * 0.92
	var tween := create_tween()
	tween.tween_property(center_notice, "modulate", Color(0.92, 0.98, 1.0, 1.0), 0.12)
	tween.parallel().tween_property(center_notice, "scale", Vector2.ONE, 0.12)

func hide_center_notice() -> void:
	center_notice.visible = false

func set_buttons_enabled(enabled: bool) -> void:
	for button in [wait_button, scan_button, attack_button, collect_button, pick_skill_button, end_turn_button, scout_tech_button, move_tech_button, stealth_tech_button]:
		button.disabled = not enabled
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
	tech_upgrade_enabled["scout"] = can_scout
	tech_upgrade_enabled["move"] = can_move
	tech_upgrade_enabled["stealth"] = can_stealth
	_refresh_tech_button_texts()

func is_screen_point_over_hud(screen_point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var in_top := screen_point.y < 58.0
	var in_bottom := screen_point.x > 330.0 and screen_point.x < viewport_size.x - 330.0 and screen_point.y > viewport_size.y - 120.0
	var in_left := screen_point.x < 170.0 and screen_point.y > 68.0 and screen_point.y < 230.0
	var in_tech := screen_point.x > viewport_size.x - 226.0 and screen_point.y > 60.0 and screen_point.y < 330.0
	var in_minimap := screen_point.x > viewport_size.x - 230.0 and screen_point.y > viewport_size.y - 180.0
	var in_choice := skill_choice_panel.visible and screen_point.x > viewport_size.x * 0.5 - 270.0 and screen_point.x < viewport_size.x * 0.5 + 270.0 and screen_point.y > viewport_size.y * 0.5 - 140.0 and screen_point.y < viewport_size.y * 0.5 + 150.0
	return in_top or in_bottom or in_left or in_tech or in_minimap or in_choice

func _connect_buttons() -> void:
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

func _apply_m8_2_layout() -> void:
	_rebuild_left_info_panel()
	_layout_top_bar()
	_layout_bottom_action_bar()
	_layout_right_tech_panel()
	_layout_minimap()
	$Root/LogPanel.visible = false

func _rebuild_left_info_panel() -> void:
	left_info_panel = PanelContainer.new()
	left_info_panel.name = "LeftInfoPanel"
	left_info_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	left_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_info_panel.offset_left = 16.0
	left_info_panel.offset_top = 72.0
	left_info_panel.offset_right = 156.0
	left_info_panel.offset_bottom = 188.0
	root.add_child(left_info_panel)

	left_info_label = Label.new()
	left_info_label.text = "存活至最后\n玩家 1\nTab 背包\nL 科技"
	left_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_info_label.add_theme_font_size_override("font_size", 15)
	left_info_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	left_info_panel.add_child(left_info_label)

func _layout_top_bar() -> void:
	if top_bar_frame == null:
		top_bar_frame = PanelContainer.new()
		top_bar_frame.name = "TopBarFrame"
		top_bar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_bar_frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
		root.add_child(top_bar_frame)
		root.move_child(top_bar_frame, 0)
	if top_status_row == null:
		top_status_row = HBoxContainer.new()
		top_status_row.name = "TopStatusRow"
		top_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_status_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		top_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
		top_status_row.add_theme_constant_override("separation", 18)
		top_status_row.z_index = 100
		root.add_child(top_status_row)
	if top_status_label == null:
		top_status_label = Label.new()
		top_status_label.name = "TopStatusLabel"
		top_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top_status_label.add_theme_font_size_override("font_size", 18)
		top_status_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
		top_status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		top_status_label.add_theme_constant_override("shadow_offset_x", 1)
		top_status_label.add_theme_constant_override("shadow_offset_y", 1)
		top_status_label.z_index = 101
		top_status_row.add_child(top_status_label)
	top_bar.visible = false
	top_bar_frame.offset_left = 292.0
	top_bar_frame.offset_top = 4.0
	top_bar_frame.offset_right = -292.0
	top_bar_frame.offset_bottom = 54.0
	top_status_row.offset_left = 312.0
	top_status_row.offset_top = 12.0
	top_status_row.offset_right = -312.0
	top_status_row.offset_bottom = 48.0

	for label in [title_label, turn_label, energy_label, unit_label, hp_label, collapse_label, mode_label]:
		label.visible = false
	top_status_label.custom_minimum_size = Vector2(640, 34)
	top_status_label.visible = true
	title_label.add_theme_font_size_override("font_size", 22)
	for label in [turn_label, energy_label, unit_label, hp_label, collapse_label, mode_label]:
		label.add_theme_font_size_override("font_size", 17)
	_refresh_top_status_text()

func _layout_bottom_action_bar() -> void:
	bottom_bar.offset_left = 340.0
	bottom_bar.offset_top = -116.0
	bottom_bar.offset_right = -340.0
	bottom_bar.offset_bottom = -8.0
	bottom_bar.add_theme_constant_override("separation", 6)
	if action_button_row == null:
		action_button_row = HBoxContainer.new()
		action_button_row.name = "ActionButtonRow"
		action_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
		action_button_row.add_theme_constant_override("separation", 12)
		bottom_bar.add_child(action_button_row)
		bottom_bar.move_child(action_button_row, 0)
	for button in [wait_button, scan_button, attack_button, collect_button, pick_skill_button, end_turn_button]:
		if button.get_parent() != action_button_row:
			button.get_parent().remove_child(button)
			action_button_row.add_child(button)
		button.visible = true
		button.custom_minimum_size = Vector2(74, 34)
		button.expand_icon = false
		button.icon = null
	wait_button.text = "待机 +1"
	scan_button.text = "扫描 -2"
	attack_button.text = "攻击 -3"
	collect_button.text = "采集"
	pick_skill_button.text = "技能"
	end_turn_button.text = "结束"
	for button in skill_slot_buttons:
		button.custom_minimum_size = Vector2(148, 30)

func _layout_right_tech_panel() -> void:
	tech_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tech_panel.offset_left = -214.0
	tech_panel.offset_top = 60.0
	tech_panel.offset_right = -16.0
	tech_panel.offset_bottom = 320.0
	tech_box.add_theme_constant_override("separation", 8)
	tech_summary_label.text = "科技树"
	tech_summary_label.custom_minimum_size = Vector2(170, 26)
	tech_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for button in [gm_button, scout_tech_button, move_tech_button, stealth_tech_button]:
		button.custom_minimum_size = Vector2(172, 46)
		button.expand_icon = false
	for button in [scout_tech_button, move_tech_button, stealth_tech_button]:
		button.icon = null
	_refresh_tech_button_texts()

func _layout_minimap() -> void:
	minimap_panel.offset_left = -220.0
	minimap_panel.offset_top = -176.0
	minimap_panel.offset_right = -16.0
	minimap_panel.offset_bottom = -24.0
	if minimap_box == null:
		minimap_box = VBoxContainer.new()
		minimap_box.name = "MiniMapBox"
		minimap_box.add_theme_constant_override("separation", 4)
		minimap_panel.add_child(minimap_box)
	if mini_map_label.get_parent() != minimap_box:
		mini_map_label.get_parent().remove_child(mini_map_label)
		minimap_box.add_child(mini_map_label)
		minimap_box.move_child(mini_map_label, 0)
	if minimap_widget == null:
		minimap_widget = MINIMAP_WIDGET_SCRIPT.new() as MiniMapWidget
		minimap_widget.custom_minimum_size = Vector2(180, 104)
		minimap_box.add_child(minimap_widget)
	mini_map_label.custom_minimum_size = Vector2(180, 34)
	mini_map_label.add_theme_font_size_override("font_size", 13)

func _apply_m8_2_theme() -> void:
	for panel in [tech_panel, minimap_panel, skill_choice_panel, left_info_panel, top_bar_frame]:
		_style_panel(panel)
	for button in [wait_button, scan_button, attack_button, collect_button, pick_skill_button, end_turn_button, gm_button, scout_tech_button, move_tech_button, stealth_tech_button]:
		_style_button(button, Color(0.0, 0.78, 1.0, 1.0))
	for button in skill_slot_buttons:
		_style_button(button, Color(0.72, 0.35, 1.0, 1.0))
	_style_status_labels()

func _style_panel(panel: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.06, 0.10, 0.84)
	style.border_color = Color(0.0, 0.78, 1.0, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _button_style(Color(0.01, 0.06, 0.10, 0.88), accent, 0.62))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.02, 0.12, 0.18, 0.92), accent, 1.0))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.18, 0.24, 0.96), accent, 1.0))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.015, 0.025, 0.035, 0.58), Color(0.22, 0.32, 0.38, 1.0), 0.40))
	button.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.68, 0.82, 0.88, 1.0))
	button.add_theme_font_size_override("font_size", 14)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _button_style(bg: Color, border: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(border.r, border.g, border.b, alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _style_status_labels() -> void:
	for label in [title_label, turn_label, energy_label, unit_label, hp_label, collapse_label, mode_label, hover_label, action_hint_label, mini_map_label, tech_summary_label]:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0, 1.0))
	collapse_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.52, 1.0))
	mode_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55, 1.0))
	center_notice.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
	center_notice.add_theme_constant_override("shadow_offset_x", 2)
	center_notice.add_theme_constant_override("shadow_offset_y", 2)

func _apply_m8_2_icons() -> void:
	for button in [wait_button, scan_button, attack_button, collect_button, pick_skill_button, end_turn_button, scout_tech_button, move_tech_button, stealth_tech_button]:
		button.icon = null

func _set_button_icon(button: Button, path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	button.icon = load(path)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _refresh_tech_button_texts() -> void:
	_set_tech_button_text(scout_tech_button, "侦察", "scout")
	_set_tech_button_text(move_tech_button, "移动", "move")
	_set_tech_button_text(stealth_tech_button, "隐匿", "stealth")

func _set_tech_button_text(button: Button, display_name: String, tech_id: String) -> void:
	var level := int(tech_levels.get(tech_id, 1))
	var state_text := "可升级" if bool(tech_upgrade_enabled.get(tech_id, false)) else "锁定"
	var progress := "■".repeat(level) + "□".repeat(max(0, 4 - level))
	button.text = "%s Lv.%d\n%s  %s" % [display_name, level, progress, state_text]
	button.tooltip_text = "%s科技 Lv.%d，当前状态：%s" % [display_name, level, state_text]

func _refresh_top_status_text() -> void:
	if top_status_label == null:
		return
	top_status_label.text = "%s    回合：%d    暗能：%d/%d    NPC：%d    HP：%d    缩圈：%d    模式：%s" % [
		status_title,
		status_turn,
		status_energy,
		status_max_energy,
		status_npc,
		status_hp,
		status_collapse,
		status_mode
	]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
