class_name DarkSignalGridMap
extends TileMapLayer

const SOURCE_ID := 0
const SPACE_TILE := Vector2i(0, 0)
const OBSTACLE_TILE := Vector2i(1, 0)
const SILENT_TILE := Vector2i(2, 0)
const ECHO_TILE := Vector2i(3, 0)
const BLACK_DOMAIN_TILE := Vector2i(4, 0)

var map_width := 24
var map_height := 16
var tile_size := 40
var use_authored_map := false
var collapse_layer := 0
var resource_points: Dictionary = {}
var skill_points: Dictionary = {}

func setup(config: Dictionary) -> void:
	map_width = int(config.get("map_width", map_width))
	map_height = int(config.get("map_height", map_height))
	tile_size = int(config.get("tile_size", tile_size))
	use_authored_map = bool(config.get("use_authored_map", false))
	if not use_authored_map or get_used_cells().is_empty():
		_draw_default_grid()
		_apply_config_zones(config)
	_load_points(config)

func _draw_default_grid() -> void:
	clear()
	for y in range(map_height):
		for x in range(map_width):
			set_cell(Vector2i(x, y), SOURCE_ID, SPACE_TILE)

	for tile in [
		Vector2i(8, 4),
		Vector2i(9, 4),
		Vector2i(10, 4),
		Vector2i(13, 8),
		Vector2i(14, 8),
		Vector2i(6, 11)
	]:
		set_cell(tile, SOURCE_ID, OBSTACLE_TILE)

func get_tile_info(tile: Vector2i) -> Dictionary:
	var atlas := get_cell_atlas_coords(tile)
	var tile_type := "space"
	var passable := true
	var zone_type := "normal"
	if atlas == OBSTACLE_TILE:
		tile_type = "obstacle"
		passable = false
	elif atlas == SILENT_TILE:
		tile_type = "silent_zone"
		zone_type = "silent"
	elif atlas == ECHO_TILE:
		tile_type = "echo_zone"
		zone_type = "echo"
	elif atlas == BLACK_DOMAIN_TILE:
		tile_type = "black_domain"
		zone_type = "black_domain"
	return {
		"x": tile.x,
		"y": tile.y,
		"type": tile_type,
		"passable": passable,
		"zoneType": zone_type
	}

func get_zone_type(tile: Vector2i) -> String:
	return String(get_tile_info(tile).get("zoneType", "normal"))

func is_silent_zone(tile: Vector2i) -> bool:
	return get_zone_type(tile) == "silent"

func is_echo_zone(tile: Vector2i) -> bool:
	return get_zone_type(tile) == "echo"

func is_black_domain(tile: Vector2i) -> bool:
	return get_zone_type(tile) == "black_domain"

func should_leave_move_signal(tile: Vector2i) -> bool:
	return not is_silent_zone(tile)

func has_resource_point(tile: Vector2i) -> bool:
	return resource_points.has(tile)

func has_skill_point(tile: Vector2i) -> bool:
	return skill_points.has(tile)

func get_resource_point(tile: Vector2i) -> Dictionary:
	return resource_points.get(tile, {})

func get_skill_point(tile: Vector2i) -> Dictionary:
	return skill_points.get(tile, {})

func collect_resource_point(tile: Vector2i) -> Dictionary:
	if not has_resource_point(tile):
		return {}
	var point: Dictionary = resource_points[tile]
	resource_points.erase(tile)
	return point

func pick_skill_point(tile: Vector2i) -> Dictionary:
	if not has_skill_point(tile):
		return {}
	var point: Dictionary = skill_points[tile]
	skill_points.erase(tile)
	return point

func advance_collapse() -> bool:
	if collapse_layer >= min(map_width, map_height) / 2:
		return false
	for x in range(collapse_layer, map_width - collapse_layer):
		_set_black_domain(Vector2i(x, collapse_layer))
		_set_black_domain(Vector2i(x, map_height - 1 - collapse_layer))
	for y in range(collapse_layer + 1, map_height - 1 - collapse_layer):
		_set_black_domain(Vector2i(collapse_layer, y))
		_set_black_domain(Vector2i(map_width - 1 - collapse_layer, y))
	collapse_layer += 1
	return true

func get_collapse_layer() -> int:
	return collapse_layer

func get_safe_bounds_text() -> String:
	return "安全区：左上(%d,%d) 右下(%d,%d)" % [
		collapse_layer,
		collapse_layer,
		map_width - 1 - collapse_layer,
		map_height - 1 - collapse_layer
	]

func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_width and tile.y < map_height

func is_passable(tile: Vector2i) -> bool:
	if not is_inside(tile):
		return false
	return bool(get_tile_info(tile).get("passable", false))

func grid_to_world(tile: Vector2i) -> Vector2:
	return to_global(map_to_local(tile))

func grid_to_local_center(tile: Vector2i) -> Vector2:
	return map_to_local(tile)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return local_to_map(to_local(world_position))

func is_adjacent(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	var delta := (to_tile - from_tile).abs()
	return delta.x + delta.y == 1

func _apply_config_zones(config: Dictionary) -> void:
	for entry in config.get("silent_zones", []):
		var tile := _entry_to_tile(entry)
		if is_inside(tile):
			set_cell(tile, SOURCE_ID, SILENT_TILE)
	for entry in config.get("echo_zones", []):
		var tile := _entry_to_tile(entry)
		if is_inside(tile):
			set_cell(tile, SOURCE_ID, ECHO_TILE)

func _load_points(config: Dictionary) -> void:
	resource_points.clear()
	skill_points.clear()
	for entry in config.get("resource_points", []):
		var tile := _entry_to_tile(entry)
		if is_passable(tile):
			resource_points[tile] = {
				"tile": tile,
				"energy": int(entry.get("energy", config.get("resource_collect_gain", 4)))
			}
	for entry in config.get("skill_points", []):
		var tile := _entry_to_tile(entry)
		if is_passable(tile):
			skill_points[tile] = {
				"tile": tile,
				"level": clampi(int(entry.get("level", 1)), 1, 4)
			}

func _set_black_domain(tile: Vector2i) -> void:
	if is_inside(tile):
		set_cell(tile, SOURCE_ID, BLACK_DOMAIN_TILE)

func _entry_to_tile(entry: Dictionary) -> Vector2i:
	return Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
