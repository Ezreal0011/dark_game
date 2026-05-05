class_name BattleViewController
extends Node

@onready var background_layer: Node = $BackgroundLayer
@onready var grid_visual_layer: Node = $GridVisualLayer
@onready var zone_visual_layer: Node = $ZoneVisualLayer
@onready var point_visual_layer: Node = $PointVisualLayer
@onready var unit_visual_layer: Node = $UnitVisualLayer
@onready var action_preview_layer: Node = $ActionPreviewLayer
@onready var fx_layer: Node = $FxLayer
@onready var hud_controller: Node = $HUDController
@onready var fx_controller: Node = $FxController
@onready var minimap_controller: Node = $MiniMapController

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map
	for layer in _visual_layers():
		layer.bind_game(game_controller, grid_map)
	hud_controller.bind_game(game_controller)
	fx_controller.bind_layers(fx_layer, action_preview_layer)
	minimap_controller.bind_game(game_controller, grid_map)

func refresh_all() -> void:
	for layer in _visual_layers():
		layer.refresh()
	hud_controller.refresh()
	minimap_controller.refresh()

func clear_action_preview() -> void:
	fx_controller.clear_preview()

func show_scan_range(tiles: Array[Vector2i]) -> void:
	fx_controller.show_range(tiles, Color(0.55, 0.18, 1.0, 0.14), Color(0.78, 0.36, 1.0, 0.72), "扫描范围")

func show_attack_range(tiles: Array[Vector2i]) -> void:
	fx_controller.show_range(tiles, Color(1.0, 0.28, 0.08, 0.12), Color(1.0, 0.38, 0.12, 0.68), "攻击范围")

func show_attack_target(from_tile: Vector2i, target_tile: Vector2i) -> void:
	fx_controller.show_target_path(from_tile, target_tile, Color(1.0, 0.36, 0.10, 0.90), "探测攻击")

func show_move_preview(from_tile: Vector2i, target_tile: Vector2i, cost: int) -> void:
	fx_controller.show_move_path(from_tile, target_tile, cost)

func show_attack_prediction(from_tile: Vector2i, target_tile: Vector2i, hit_rate: int, in_range: bool) -> void:
	fx_controller.show_attack_prediction(from_tile, target_tile, hit_rate, in_range)

func show_skill_range(tiles: Array[Vector2i], skill_name: String) -> void:
	fx_controller.show_range(tiles, Color(0.70, 0.20, 1.0, 0.13), Color(0.82, 0.34, 1.0, 0.72), skill_name)

func show_skill_target(from_tile: Vector2i, target_tile: Vector2i, affected_tiles: Array[Vector2i]) -> void:
	fx_controller.show_target_path(from_tile, target_tile, Color(1.0, 0.24, 0.56, 0.86), "技能目标")
	fx_controller.add_affected_tiles(affected_tiles, Color(1.0, 0.22, 0.52, 0.22), Color(1.0, 0.36, 0.66, 0.80))

func play_scan(center_tile: Vector2i, radius: int) -> void:
	fx_controller.play_scan(center_tile, radius)

func play_attack(from_tile: Vector2i, target_tile: Vector2i, hit: bool) -> void:
	fx_controller.play_attack(from_tile, target_tile, hit)

func play_collect(tile: Vector2i, amount: int) -> void:
	fx_controller.play_collect(tile, amount)

func play_skill_pick(tile: Vector2i, level: int) -> void:
	fx_controller.play_skill_pick(tile, level)

func play_skill(tiles: Array[Vector2i], skill_type: String) -> void:
	fx_controller.play_skill(tiles, skill_type)

func play_npc_move(from_tile: Vector2i, to_tile: Vector2i) -> void:
	fx_controller.play_npc_move(from_tile, to_tile)

func _visual_layers() -> Array[Node]:
	return [
		background_layer,
		grid_visual_layer,
		zone_visual_layer,
		point_visual_layer,
		unit_visual_layer,
		action_preview_layer,
		fx_layer
	]
