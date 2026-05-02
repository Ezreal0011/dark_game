class_name SignalManager
extends Node

var move_signal_duration := 3
var scan_signal_duration := 2
var attack_signal_duration := 2

var signals: Array[Dictionary] = []

func setup(config: Dictionary) -> void:
	move_signal_duration = int(config.get("move_signal_duration", move_signal_duration))
	scan_signal_duration = int(config.get("scan_signal_duration", scan_signal_duration))
	attack_signal_duration = int(config.get("attack_signal_duration", attack_signal_duration))

func add_signal(signal_type: String, tile: Vector2i, strength: int, duration: int, public_signal: bool = false) -> void:
	signals.append({
		"type": signal_type,
		"tile": tile,
		"strength": strength,
		"remaining": duration,
		"public": public_signal
	})

func add_move_signal(tile: Vector2i) -> void:
	add_signal("move", tile, 1, move_signal_duration)

func add_scan_signal(tile: Vector2i) -> void:
	add_signal("scan", tile, 3, scan_signal_duration)

func add_attack_signal(tile: Vector2i) -> void:
	add_signal("attack", tile, 4, attack_signal_duration)

func decay_signals() -> void:
	var kept: Array[Dictionary] = []
	for signal_record in signals:
		signal_record["remaining"] = int(signal_record["remaining"]) - 1
		if int(signal_record["remaining"]) > 0:
			kept.append(signal_record)
	signals = kept

func get_visible_signals(player_tile: Vector2i, scan_range: int) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for signal_record in signals:
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
	return Color(0.15, 0.65, 1.0, 0.42)
