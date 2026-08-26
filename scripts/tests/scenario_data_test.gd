extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const ScenarioScript := preload("res://scripts/core/scenario_definition.gd")
const SensorScript := preload("res://scripts/core/sensor_definition.gd")
const EntityStateScript := preload("res://scripts/core/entity_state.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_scenario_loads()
	_test_duplicate_definition_is_rejected()
	_test_missing_definition_is_rejected()
	_test_invalid_definition_values_are_rejected()
	_test_entity_state_roundtrip()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SCENARIO DATA TESTS PASSED: 5 test cases")
	quit(0)


func _test_valid_scenario_loads() -> void:
	var loader: Variant = LoaderScript.new()
	var result: Dictionary = loader.load_scenario(SCENARIO_PATH)
	_expect(result.success, "MVP test scenario failed validation: " + str(result.get("errors", [])))
	if result.success:
		var entities: Array = loader.instantiate_starting_entities(result.scenario)
		_expect(entities.size() == 3, "Test scenario did not instantiate three infrastructure entities")


func _test_duplicate_definition_is_rejected() -> void:
	var loader: Variant = LoaderScript.new()
	var scenario: Variant = _minimal_scenario()
	scenario.definitions.append(scenario.definitions[0])
	var errors: Array[String] = loader.validate_scenario(scenario)
	_expect(_contains_text(errors, "Duplicate definition id"), "Duplicate definition id was not rejected")


func _test_missing_definition_is_rejected() -> void:
	var loader: Variant = LoaderScript.new()
	var scenario: Variant = _minimal_scenario()
	scenario.starting_entities.append({
		"id": &"bad_entity",
		"definition_id": &"missing",
		"faction": &"player",
		"position": Vector2(10.0, 10.0),
	})
	var errors: Array[String] = loader.validate_scenario(scenario)
	_expect(_contains_text(errors, "references missing definition"), "Missing definition was not rejected")


func _test_invalid_definition_values_are_rejected() -> void:
	var loader: Variant = LoaderScript.new()
	var scenario: Variant = _minimal_scenario()
	var sensor: Variant = scenario.definitions[0]
	sensor.detection_range = 0.0
	var errors: Array[String] = loader.validate_scenario(scenario)
	_expect(_contains_text(errors, "has no detection range"), "Invalid sensor range was not rejected")


func _test_entity_state_roundtrip() -> void:
	var original: Variant = EntityStateScript.new(&"entity_7", &"sensor_test", &"player", Vector2(12.5, 33.0))
	original.active = false
	original.damage = 0.25
	var restored: Variant = EntityStateScript.from_dictionary(original.to_dictionary())
	_expect(restored.id == original.id, "Entity id changed during serialization")
	_expect(restored.position.is_equal_approx(original.position), "Entity position changed during serialization")
	_expect(restored.active == original.active and is_equal_approx(restored.damage, original.damage), "Entity state changed during serialization")


func _minimal_scenario() -> Variant:
	var scenario: Variant = ScenarioScript.new()
	scenario.scenario_id = &"validation_test"
	scenario.display_name = "Validation Test"
	scenario.world_size = Vector2(100.0, 100.0)
	scenario.starting_budget = 1
	scenario.mission_duration = 1.0
	var sensor: Variant = SensorScript.new()
	sensor.id = &"sensor_test"
	sensor.display_name = "Test Sensor"
	sensor.detection_range = 10.0
	scenario.definitions.append(sensor)
	return scenario


func _contains_text(errors: Array[String], text: String) -> bool:
	for error in errors:
		if error.contains(text):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
