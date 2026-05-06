extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failed := false
	failed = failed or not await _test_grid_roundtrip_under_tilt()
	if failed:
		quit(1)
	else:
		print("M9 倾斜地图坐标测试通过")
		quit(0)

func _test_grid_roundtrip_under_tilt() -> bool:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var grid_map: DarkSignalGridMap = scene.get_node("GridMap")
	if absf(grid_map.rotation) > 0.001:
		push_error("主地图不应整块旋转")
		scene.queue_free()
		return false
	var samples: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 2),
		Vector2i(12, 8),
		Vector2i(23, 15)
	]
	for tile in samples:
		var world_pos := grid_map.grid_to_world(tile)
		var roundtrip := grid_map.world_to_grid(world_pos)
		if roundtrip != tile:
			push_error("倾斜地图点击换算失败：%s -> %s" % [str(tile), str(roundtrip)])
			scene.queue_free()
			return false
	scene.queue_free()
	return true
