extends SceneTree

const MapScript := preload("res://scripts/ui/tactical_map.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tactical_map: Variant = MapScript.new()
	tactical_map.size = Vector2(1000.0, 600.0)
	root.add_child(tactical_map)
	await process_frame

	_test_coordinate_roundtrip(tactical_map)
	_test_zoom_anchor(tactical_map)
	_test_camera_clamping(tactical_map)
	_test_independent_layers(tactical_map)
	_test_supported_viewport_sizes(tactical_map)

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return

	print("TACTICAL MAP TESTS PASSED: 5 test cases")
	quit(0)


func _test_coordinate_roundtrip(tactical_map: Variant) -> void:
	var world_position := Vector2(725.0, 410.0)
	var restored: Vector2 = tactical_map.screen_to_world(tactical_map.world_to_screen(world_position))
	_expect(restored.is_equal_approx(world_position), "World/screen coordinate roundtrip drifted")


func _test_zoom_anchor(tactical_map: Variant) -> void:
	tactical_map.set_camera(Vector2(1000.0, 600.0), 1.0)
	var cursor := Vector2(720.0, 240.0)
	var anchored_before: Vector2 = tactical_map.screen_to_world(cursor)
	tactical_map.zoom_at(cursor, 1.2)
	var anchored_after: Vector2 = tactical_map.screen_to_world(cursor)
	_expect(anchored_before.is_equal_approx(anchored_after), "Zoom did not preserve cursor world position")


func _test_camera_clamping(tactical_map: Variant) -> void:
	tactical_map.set_camera(Vector2(-5000.0, 9000.0), 1.0)
	var position: Vector2 = tactical_map.camera_world_position
	_expect(position.x >= 500.0, "Camera moved beyond left map boundary")
	_expect(position.y <= 900.0, "Camera moved beyond bottom map boundary")


func _test_independent_layers(tactical_map: Variant) -> void:
	_expect(tactical_map.set_layer_visible(&"tracks", false), "Known layer was rejected")
	_expect(not tactical_map.is_layer_visible(&"tracks"), "Track layer did not hide")
	_expect(tactical_map.is_layer_visible(&"terrain"), "Hiding tracks also hid terrain")
	_expect(tactical_map.set_layer_visible(&"network", false), "Network layer was rejected")
	_expect(not tactical_map.is_layer_visible(&"network"), "Network layer did not hide")
	_expect(tactical_map.set_layer_visible(&"terrain_debug", true), "Terrain debug layer was rejected")
	_expect(tactical_map.is_layer_visible(&"terrain_debug"), "Terrain debug layer did not become visible")
	_expect(not tactical_map.set_layer_visible(&"nonexistent", false), "Unknown layer was accepted")


func _test_supported_viewport_sizes(tactical_map: Variant) -> void:
	for viewport_size in [Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0)]:
		tactical_map.size = viewport_size
		tactical_map.set_camera(Vector2(1000.0, 600.0), 1.0)
		var screen_center: Vector2 = tactical_map.world_to_screen(tactical_map.camera_world_position)
		_expect(
			screen_center.is_equal_approx(viewport_size * 0.5),
			"Map center was incorrect at %s" % viewport_size
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
