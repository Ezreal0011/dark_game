class_name SignalManager
extends Node

var move_signal_duration := 3
var scan_signal_duration := 2
var attack_signal_duration := 2
var collect_signal_duration := 3
var skill_pick_signal_duration := 3
var move_signal_reveal_delay := 3

var signals: Array[Dictionary] = []

func setup(config: Dictionary) -> void:
	move_signal_duration = int(config.get("move_signal_lifetime_turns", 5))
	move_signal_reveal_delay = int(config.get("move_signal_reveal_delay", move_signal_reveal_delay))
	scan_signal_duration = int(config.get("scan_signal_duration", scan_signal_duration))
	attack_signal_duration = int(config.get("attack_signal_duration", attack_signal_duration))
	collect_signal_duration = int(config.get("collect_signal_duration", collect_signal_duration))
	skill_pick_signal_duration = int(config.get("skill_pick_signal_duration", skill_pick_signal_duration))

func add_signal(signal_type: String, tile: Vector2i, strength: int, duration: int, public_signal: bool = false, reveal_after: int = 0) -> void:
	signals.append({
		"type": signal_type,
		"tile": tile,
		"strength": strength,
		"remaining": duration,
		"public": public_signal,
		"reveal_after": reveal_after
	})

func add_move_signal(from_tile: Vector2i, to_tile: Vector2i = Vector2i(-9999, -9999), public_signal: bool = false) -> void:
	var actual_to := from_tile if to_tile == Vector2i(-9999, -9999) else to_tile
	signals.append({
		"type": "move",
		"tile": actual_to,
		"from_tile": from_tile,
		"to_tile": actual_to,
		"strength": 1,
		"remaining": move_signal_duration,
		"public": public_signal,
		"reveal_after": move_signal_reveal_delay
	})

func add_scan_signal(tile: Vector2i) -> void:
	add_signal("scan", tile, 3, scan_signal_duration)

func add_attack_signal(tile: Vector2i) -> void:
	add_signal("attack", tile, 4, attack_signal_duration)

func add_collect_signal(tile: Vector2i, public_signal: bool = false) -> void:
	add_signal("collect", tile, 3, collect_signal_duration, public_signal)

func add_skill_pick_signal(tile: Vector2i, level: int, public_signal: bool = false) -> void:
	add_signal("skill_pick", tile, clampi(level + 1, 2, 5), skill_pick_signal_duration, public_signal)

func decay_signals() -> void:
	var kept: Array[Dictionary] = []
	for signal_record in signals:
		signal_record["remaining"] = int(signal_record["remaining"]) - 1
		signal_record["reveal_after"] = max(0, int(signal_record.get("reveal_after", 0)) - 1)
		if int(signal_record["remaining"]) > 0:
			kept.append(signal_record)
	signals = kept

func get_visible_signals(player_tile: Vector2i, scan_range: int) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for signal_record in signals:
		if int(signal_record.get("reveal_after", 0)) > 0:
			continue
		if bool(signal_record["public"]):
			visible.append(signal_record)
			continue
		var tile: Vector2i = signal_record["tile"]
		var delta := (tile - player_tile).abs()
		if delta.x + delta.y <= scan_range:
			visible.append(signal_record)
	return visible

func get_signal_color(signal_type: String) -> Color:
	if signal_type == "attack":
		return Color(1.0, 0.2, 0.1, 0.62)
	if signal_type == "scan":
		return Color(0.72, 0.35, 1.0, 0.52)
	if signal_type == "death":
		return Color(1.0, 0.0, 0.0, 0.78)
	if signal_type == "collect":
		return Color(1.0, 0.82, 0.18, 0.62)
	if signal_type == "skill_pick":
		return Color(0.88, 0.25, 1.0, 0.62)
	if signal_type == "skill":
		return Color(0.95, 0.24, 1.0, 0.58)
	if signal_type == "echo":
		return Color(1.0, 0.46, 0.12, 0.70)
	return Color(0.15, 0.65, 1.0, 0.42)
