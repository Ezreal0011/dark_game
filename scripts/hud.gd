class_name HUD
extends CanvasLayer

signal wait_pressed
signal scan_pressed
signal attack_pressed
signal end_turn_pressed

@onready var title_label: Label = $Root/TopBar/TitleLabel
@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var energy_label: Label = $Root/TopBar/EnergyLabel
@onready var unit_label: Label = $Root/TopBar/UnitLabel
@onready var mode_label: Label = $Root/TopBar/ModeLabel
@onready var wait_button: Button = $Root/TopBar/WaitButton
@onready var scan_button: Button = $Root/TopBar/ScanButton
@onready var attack_button: Button = $Root/TopBar/AttackButton
@onready var end_turn_button: Button = $Root/TopBar/EndTurnButton
@onready var hover_label: Label = $Root/BottomBar/HoverLabel
@onready var action_hint_label: Label = $Root/BottomBar/ActionHintLabel
@onready var log_box: RichTextLabel = $Root/LogPanel/LogBox
@onready var center_notice: Label = $Root/CenterNotice

func _ready() -> void:
	wait_button.pressed.connect(func() -> void: wait_pressed.emit())
	scan_button.pressed.connect(func() -> void: scan_pressed.emit())
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
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

func set_mode(mode_name: String) -> void:
	mode_label.text = "模式：%s" % mode_name

func set_hover_text(text: String) -> void:
	hover_label.text = text

func set_action_hint(text: String) -> void:
	action_hint_label.text = text

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
	end_turn_button.disabled = not enabled

func is_screen_point_over_hud(screen_point: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var in_top := screen_point.y < 64.0
	var in_bottom := screen_point.y > viewport_size.y - 92.0
	var in_log := screen_point.x > viewport_size.x - 360.0 and screen_point.y < 390.0
	return in_top or in_bottom or in_log
