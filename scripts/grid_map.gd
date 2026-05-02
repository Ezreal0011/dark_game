class_name DarkSignalGridMap
extends TileMapLayer

const SOURCE_ID := 0
const SPACE_TILE := Vector2i(0, 0)
const OBSTACLE_TILE := Vector2i(1, 0)

var map_width := 24
var map_height := 16
var tile_size := 40
var use_authored_map := false

func setup(config: Dictionary) -> void:
	map_width = int(config.get("map_width", map_width))
	map_height = int(config.get("map_height", map_height))
	tile_size = int(config.get("tile_size", tile_size))
	use_authored_map = bool(config.get("use_authored_map", false))
	if not use_authored_map or get_used_cells().is_empty():
		_draw_default_grid()

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
	return {
		"x": tile.x,
		"y": tile.y,
		"type": tile_type,
		"passable": passable,
		"zoneType": zone_type
	}

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
