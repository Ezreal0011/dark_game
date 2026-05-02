class_name PointVisualLayer
extends Node2D

var game_controller: GameController
var grid_map: DarkSignalGridMap

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map

func refresh() -> void:
	pass

func clear() -> void:
	for child in get_children():
		child.queue_free()
