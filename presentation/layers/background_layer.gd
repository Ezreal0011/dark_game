class_name BackgroundLayer
extends Node2D

const ART_MANIFEST := "res://presentation/resources/art_manifest.json"
const BACKGROUND_SIZE := Vector2(1280, 800)

var game_controller: GameController
var grid_map: DarkSignalGridMap
var built := false

func bind_game(game: GameController, map: DarkSignalGridMap) -> void:
	game_controller = game
	grid_map = map

func refresh() -> void:
	if built:
		return
	built = true
	clear()
	z_index = -1000
	var manifest := _load_json(ART_MANIFEST)
	var backgrounds: Dictionary = manifest.get("backgrounds", {})
	_add_sprite(String(backgrounds.get("space_main", "")), BACKGROUND_SIZE * 0.5, Vector2(0.8, 0.8), 1.0, -1000)

func clear() -> void:
	for child in get_children():
		child.queue_free()

func _add_decorations(manifest: Dictionary) -> void:
	var decorations: Dictionary = manifest.get("decorations", {})
	var asteroids: Array = decorations.get("asteroids", [])
	var wrecks: Array = decorations.get("wrecks", [])
	var positions := [
		Vector2(196, 170), Vector2(310, 612), Vector2(470, 292), Vector2(650, 132),
		Vector2(815, 178), Vector2(960, 530), Vector2(1110, 336), Vector2(1192, 646),
		Vector2(738, 464), Vector2(545, 705), Vector2(1035, 708), Vector2(155, 522)
	]
	for i in range(min(positions.size(), asteroids.size())):
		var sprite := _add_sprite(String(asteroids[i]), positions[i], Vector2.ONE * (0.18 + float(i % 4) * 0.045), 0.62, -990 + i)
		if sprite != null:
			sprite.rotation_degrees = -35.0 + float(i * 17 % 70)
	var wreck_positions := [Vector2(285, 330), Vector2(870, 96), Vector2(980, 585), Vector2(415, 690), Vector2(1130, 150)]
	for i in range(min(wreck_positions.size(), wrecks.size())):
		var sprite := _add_sprite(String(wrecks[i]), wreck_positions[i], Vector2.ONE * (0.28 + float(i % 3) * 0.08), 0.66, -980 + i)
		if sprite != null:
			sprite.rotation_degrees = -25.0 + float(i * 22)

func _add_sprite(path: String, pos: Vector2, sprite_scale: Vector2, alpha: float, next_z: int) -> Sprite2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	sprite.scale = sprite_scale
	sprite.modulate.a = alpha
	sprite.z_index = next_z
	add_child(sprite)
	return sprite

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
