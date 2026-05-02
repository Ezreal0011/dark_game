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
