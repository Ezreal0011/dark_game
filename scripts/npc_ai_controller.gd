class_name NpcAIController
extends Node

var npc_types: Dictionary = {}

func setup(config: Dictionary) -> void:
	npc_types = config.get("npc_types", {})

func choose_action(npc: Dictionary, context: Dictionary) -> Dictionary:
	var npc_tile: Vector2i = npc["tile"]
	var move_options: Array = context.get("move_options", [])
	if move_options.is_empty():
		return {"action": "wait", "target": npc_tile, "reason": "无可行动格"}

	var black_tiles: Array = context.get("black_tiles", [])
	if black_tiles.has(npc_tile):
		return {
			"action": "move",
			"target": _best_tile_away_from_black(move_options, black_tiles, npc_tile),
			"reason": "脱离黑域"
		}

	var visible_signals: Array = context.get("visible_signals", [])
	if not visible_signals.is_empty() and _type_weight(String(npc.get("type", "")), "signal_weight") > 0:
		var signal_tile := _strongest_signal_tile(visible_signals)
		return {
			"action": "move",
			"target": _closest_option_to(move_options, signal_tile),
			"reason": "追踪可见信号"
		}

	var map_points: Array = context.get("map_points", [])
	if not map_points.is_empty() and _type_weight(String(npc.get("type", "")), "map_point_weight") > 0:
		var point_tile := _nearest_target(npc_tile, map_points)
		return {
			"action": "move",
			"target": _closest_option_to(move_options, point_tile),
			"reason": "争夺地图点"
		}

	return {
		"action": "move",
		"target": move_options[0],
		"reason": "巡逻"
	}

func _type_weight(npc_type: String, key: String) -> int:
	var config: Dictionary = npc_types.get(npc_type, {})
	return int(config.get(key, 1))

func _strongest_signal_tile(signals: Array) -> Vector2i:
	var best_tile := Vector2i.ZERO
	var best_score := -999999
	for signal_record in signals:
		var record: Dictionary = signal_record
		var score := int(record.get("strength", 1)) * 10 + int(record.get("remaining", 1))
		if score > best_score:
			best_score = score
			best_tile = record.get("tile", Vector2i.ZERO)
	return best_tile

func _best_tile_away_from_black(options: Array, black_tiles: Array, fallback: Vector2i) -> Vector2i:
	var best_tile := fallback
	var best_score := -999999
	for option in options:
		var tile: Vector2i = option
		if black_tiles.has(tile):
			continue
		var nearest_black := _nearest_distance(tile, black_tiles)
		if nearest_black > best_score:
			best_score = nearest_black
			best_tile = tile
	return best_tile

func _closest_option_to(options: Array, target: Vector2i) -> Vector2i:
	var best_tile: Vector2i = options[0]
	var best_distance := _distance(best_tile, target)
	for option in options:
		var tile: Vector2i = option
		var distance := _distance(tile, target)
		if distance < best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _nearest_target(from_tile: Vector2i, targets: Array) -> Vector2i:
	var best_tile: Vector2i = targets[0]
	var best_distance := _distance(from_tile, best_tile)
	for target in targets:
		var tile: Vector2i = target
		var distance := _distance(from_tile, tile)
		if distance < best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _nearest_distance(from_tile: Vector2i, targets: Array) -> int:
	if targets.is_empty():
		return 999999
	var best := 999999
	for target in targets:
		best = min(best, _distance(from_tile, target))
	return best

func _distance(a: Vector2i, b: Vector2i) -> int:
	var delta := (a - b).abs()
	return delta.x + delta.y
