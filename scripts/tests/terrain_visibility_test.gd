extends SceneTree

const TerrainScript := preload("res://scripts/systems/terrain_visibility_system.gd")
const LoaderScript := preload("res://scripts/core/scenario_loader.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_deterministic_mask_and_cache()
	_test_blocker_reduces_visibility()
	_test_map_edges_are_clipped()
	_test_invalid_terrain_data_is_rejected()
	_test_mask_generation_profile()
	_test_session_preview_is_available_before_purchase()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("TERRAIN VISIBILITY TESTS PASSED: 6 test cases")
	quit(0)


func _scenario() -> ScenarioDefinition:
	var scenario := ScenarioDefinition.new()
	scenario.scenario_id = &"terrain_test"
	scenario.display_name = "Terrain Test"
	scenario.summary = "Deterministic terrain visibility fixture."
	scenario.learning_objectives = PackedStringArray(["Test terrain"])
	scenario.world_size = Vector2(500.0, 300.0)
	scenario.terrain_cell_size = 50.0
	scenario.visibility_blockers = [{
		"area": Rect2(200.0, 0.0, 50.0, 300.0),
		"height": 200.0,
		"visibility_factor": 0.25,
	}]
	return scenario


func _system() -> TerrainVisibilitySystem:
	var system := TerrainScript.new()
	system.configure(_scenario())
	return system


func _test_deterministic_mask_and_cache() -> void:
	var first := _system()
	var second := _system()
	var first_mask := first.prepare_visibility_mask(Vector2(75.0, 125.0), 300.0, 20.0)
	var cached_mask := first.prepare_visibility_mask(Vector2(76.0, 126.0), 300.0, 20.0)
	var second_mask := second.prepare_visibility_mask(Vector2(75.0, 125.0), 300.0, 20.0)
	_expect(first_mask.values == cached_mask.values and first_mask.values == second_mask.values, "Identical terrain data produced different masks")
	var stats := first.get_cache_stats()
	_expect(stats.hits == 1 and stats.misses == 1 and stats.mask_count == 1, "Visibility mask cache did not reuse a quantized origin")


func _test_blocker_reduces_visibility() -> void:
	var system := _system()
	system.prepare_visibility_mask(Vector2(75.0, 125.0), 400.0)
	var blocked := system.sample_visibility(Vector2(75.0, 125.0), Vector2(425.0, 125.0))
	var clear := system.sample_visibility(Vector2(75.0, 125.0), Vector2(75.0, 225.0))
	_expect(blocked <= 0.25, "Visibility blocker did not apply documented reduction")
	_expect(is_equal_approx(clear, 1.0), "Clear line of sight was reduced unexpectedly")


func _test_map_edges_are_clipped() -> void:
	var mask := _system().prepare_visibility_mask(Vector2.ZERO, 200.0)
	_expect(mask.offset == Vector2i.ZERO, "Visibility mask extended beyond top-left map edge")
	_expect(mask.width <= 5 and mask.height <= 5, "Clipped edge mask has invalid dimensions")


func _test_invalid_terrain_data_is_rejected() -> void:
	var scenario := _scenario()
	scenario.terrain_model_version = ScenarioDefinition.CURRENT_TERRAIN_MODEL_VERSION + 1
	scenario.terrain_zones = [{
		"area": Rect2(450.0, 250.0, 100.0, 100.0),
		"terrain_type": &"invalid",
		"height": -1.0,
		"visibility_factor": 1.5,
	}]
	var errors := LoaderScript.new().validate_scenario(scenario)
	_expect(_contains(errors, "Terrain model version"), "Incompatible terrain model version was accepted")
	_expect(_contains(errors, "invalid area"), "Terrain area outside map was accepted")
	_expect(_contains(errors, "negative height"), "Negative terrain height was accepted")
	_expect(_contains(errors, "between 0 and 1"), "Invalid terrain visibility factor was accepted")


func _test_mask_generation_profile() -> void:
	var system := _system()
	var started := Time.get_ticks_usec()
	for index in 100:
		var position := Vector2(25.0 + (index % 10) * 50.0, 25.0 + (index / 10) * 25.0)
		system.prepare_visibility_mask(position, 300.0)
	var elapsed_seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	_expect(elapsed_seconds < 2.0, "Visibility mask profile exceeded two seconds: %.3f" % elapsed_seconds)
	_expect(system.get_cache_stats().generated_cells > 0, "Visibility mask profile generated no cells")


func _test_session_preview_is_available_before_purchase() -> void:
	var scenario := load("res://data/scenarios/mvp_test_scenario.tres") as ScenarioDefinition
	var session := GameSession.new()
	session.initialize(scenario)
	var mask := session.get_sensor_visibility_preview(&"sensor_early_warning", Vector2(75.0, 125.0))
	_expect(not mask.is_empty(), "Sensor visibility preview was unavailable before purchase")
	_expect(session.placement.get_placements().is_empty(), "Visibility preview purchased a system")
	var blocked := session.terrain.sample_visibility(Vector2(75.0, 125.0), Vector2(425.0, 125.0), 20.0)
	_expect(blocked <= 0.25, "Scenario preview did not expose configured blocker")


func _contains(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
