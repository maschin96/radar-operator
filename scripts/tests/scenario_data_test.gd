extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const CatalogScript := preload("res://scripts/core/scenario_catalog.gd")
const ScenarioScript := preload("res://scripts/core/scenario_definition.gd")
const SensorScript := preload("res://scripts/core/sensor_definition.gd")
const EntityStateScript := preload("res://scripts/core/entity_state.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_scenario_loads()
	_test_catalog_discovers_scenarios_in_campaign_order()
	_test_incompatible_content_version_is_rejected()
	_test_duplicate_definition_is_rejected()
	_test_missing_definition_is_rejected()
	_test_invalid_definition_values_are_rejected()
	_test_entity_state_roundtrip()
	_test_mission_rule_profile()
	_test_network_graph_validation()
	_test_mobility_profile_validation()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SCENARIO DATA TESTS PASSED: 10 test cases")
	quit(0)


func _test_valid_scenario_loads() -> void:
	var loader: Variant = LoaderScript.new()
	var result: Dictionary = loader.load_scenario(SCENARIO_PATH)
	_expect(result.success, "MVP test scenario failed validation: " + str(result.get("errors", [])))
	if result.success:
		var entities: Array = loader.instantiate_starting_entities(result.scenario)
		_expect(entities.size() == 3, "Test scenario did not instantiate three infrastructure entities")


func _test_catalog_discovers_scenarios_in_campaign_order() -> void:
	var result: Dictionary = CatalogScript.new().discover()
	_expect(result.success, "Scenario catalog failed validation: " + str(result.errors))
	if result.success:
		_expect(result.scenarios.size() == 2, "Scenario catalog did not discover both missions")
		_expect(result.scenarios[0].scenario_id == &"tutorial_mission_1", "Scenario catalog order is not deterministic")


func _test_incompatible_content_version_is_rejected() -> void:
	var loader: Variant = LoaderScript.new()
	var scenario: Variant = _minimal_scenario()
	scenario.content_version = ScenarioDefinition.CURRENT_CONTENT_VERSION + 1
	var errors: Array[String] = loader.validate_scenario(scenario)
	_expect(_contains_text(errors, "content version"), "Incompatible scenario content version was not rejected")


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
	original.mobility_status = EntityState.MobilityStatus.MOVING
	original.relocation_target = Vector2(80.0, 90.0)
	original.relocation_path = PackedVector2Array([original.position, original.relocation_target])
	original.relocation_path_index = 1
	original.relocation_remaining = 2.5
	var restored: Variant = EntityStateScript.from_dictionary(original.to_dictionary())
	_expect(restored.id == original.id, "Entity id changed during serialization")
	_expect(restored.position.is_equal_approx(original.position), "Entity position changed during serialization")
	_expect(restored.initial_position.is_equal_approx(original.initial_position), "Entity initial position changed during serialization")
	_expect(restored.active == original.active and is_equal_approx(restored.damage, original.damage), "Entity state changed during serialization")
	_expect(restored.mobility_status == original.mobility_status and restored.relocation_target == original.relocation_target, "Entity relocation state changed during serialization")


func _minimal_scenario() -> Variant:
	var scenario: Variant = ScenarioScript.new()
	scenario.scenario_id = &"validation_test"
	scenario.display_name = "Validation Test"
	scenario.summary = "Minimal valid scenario used by data validation tests."
	scenario.learning_objectives = PackedStringArray(["Validate scenario data"])
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


func _test_mission_rule_profile() -> void:
	var scenario: ScenarioDefinition = load(SCENARIO_PATH).duplicate(true)
	_expect(scenario.engagement_profile != null, "Mission does not reference rule resource")
	scenario.engagement_profile = load("res://data/rules/manual.tres").duplicate(true)
	var session := GameSession.new()
	session.initialize(scenario)
	_expect(not session.defenses.get_rules().automatic_release, "Mission profile not activated at initialization")
	scenario.engagement_profile.infrastructure_priorities = {"missing": 2.0}
	_expect(not ScenarioLoader.new().validate_scenario(scenario).is_empty(), "Missing profile infrastructure not rejected")


func _test_network_graph_validation() -> void:
	var scenario: ScenarioDefinition = load(SCENARIO_PATH).duplicate(true)
	scenario.network_model_version = ScenarioDefinition.CURRENT_NETWORK_MODEL_VERSION + 1
	var errors := ScenarioLoader.new().validate_scenario(scenario)
	_expect(_contains_text(errors, "Network model version"), "Incompatible network graph version was not rejected")
	scenario.network_model_version = ScenarioDefinition.CURRENT_NETWORK_MODEL_VERSION
	scenario.network_connections.append(scenario.network_connections[0].duplicate(true))
	errors = ScenarioLoader.new().validate_scenario(scenario)
	_expect(_contains_text(errors, "duplicate connection id"), "Duplicate network connection id was not rejected")
	scenario.network_connections[-1].id = &"invalid_network_edge"
	scenario.network_connections[-1].source_id = &"missing_source"
	errors = ScenarioLoader.new().validate_scenario(scenario)
	_expect(_contains_text(errors, "missing source"), "Missing network source was not rejected")


func _test_mobility_profile_validation() -> void:
	var scenario: ScenarioDefinition = load(SCENARIO_PATH).duplicate(true)
	var mobile_definition: EntityDefinition
	for definition in scenario.definitions:
		if definition is EntityDefinition and definition.mobile:
			mobile_definition = definition
			break
	_expect(mobile_definition != null, "Scenario exposes no mobile system")
	if mobile_definition != null:
		mobile_definition.relocation_speed = 0.0
		var errors := ScenarioLoader.new().validate_scenario(scenario)
		_expect(_contains_text(errors, "invalid relocation timing"), "Invalid mobile relocation profile was not rejected")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
