class_name ConfigLoader
extends Node

const CONFIG_PATH := "res://configs/game_config.json"

var game_config: Dictionary = {}

func _ready() -> void:
	load_game_config()

func load_game_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("Missing config file: " + CONFIG_PATH)
		game_config = {}
		return game_config

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON config: " + CONFIG_PATH)
		game_config = {}
		return game_config

	game_config = parsed
	return game_config

func get_value(key: String, default_value: Variant) -> Variant:
	return game_config.get(key, default_value)
