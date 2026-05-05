class_name FxController
extends Node

var fx_layer: Node
var action_preview_layer: Node

func bind_layers(next_fx_layer: Node, next_action_preview_layer: Node) -> void:
	fx_layer = next_fx_layer
	action_preview_layer = next_action_preview_layer

func clear_all() -> void:
	if action_preview_layer != null:
		action_preview_layer.clear()
	if fx_layer != null:
		fx_layer.clear()

func clear_preview() -> void:
	if action_preview_layer != null:
		action_preview_layer.clear()

func show_range(tiles: Array[Vector2i], fill_color: Color, line_color: Color, label_text: String = "") -> void:
	if action_preview_layer != null and action_preview_layer.has_method("show_range"):
		action_preview_layer.show_range(tiles, fill_color, line_color, label_text)

func show_target_path(from_tile: Vector2i, target_tile: Vector2i, color: Color, label_text: String = "") -> void:
	if action_preview_layer != null and action_preview_layer.has_method("show_target_path"):
		action_preview_layer.show_target_path(from_tile, target_tile, color, label_text)

func add_affected_tiles(tiles: Array[Vector2i], fill_color: Color, line_color: Color) -> void:
	if action_preview_layer != null and action_preview_layer.has_method("add_affected_tiles"):
		action_preview_layer.add_affected_tiles(tiles, fill_color, line_color)

func play_scan(center_tile: Vector2i, radius: int) -> void:
	if fx_layer != null and fx_layer.has_method("play_scan"):
		fx_layer.play_scan(center_tile, radius)

func play_attack(from_tile: Vector2i, target_tile: Vector2i, hit: bool) -> void:
	if fx_layer != null and fx_layer.has_method("play_attack"):
		fx_layer.play_attack(from_tile, target_tile, hit)

func play_collect(tile: Vector2i, amount: int) -> void:
	if fx_layer != null and fx_layer.has_method("play_collect"):
		fx_layer.play_collect(tile, amount)

func play_skill_pick(tile: Vector2i, level: int) -> void:
	if fx_layer != null and fx_layer.has_method("play_skill_pick"):
		fx_layer.play_skill_pick(tile, level)

func play_skill(tiles: Array[Vector2i], skill_type: String) -> void:
	if fx_layer != null and fx_layer.has_method("play_skill"):
		fx_layer.play_skill(tiles, skill_type)

func play_npc_move(from_tile: Vector2i, to_tile: Vector2i) -> void:
	if fx_layer != null and fx_layer.has_method("play_npc_move"):
		fx_layer.play_npc_move(from_tile, to_tile)
