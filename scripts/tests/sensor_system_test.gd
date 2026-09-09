extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const SensorSystemScript := preload("res://scripts/systems/sensor_system.gd")
const SensorStateScript := preload("res://scripts/simulation/sensor_state.gd")
const ThreatStateScript := preload("res://scripts/simulation/threat_state.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_range_and_boundary_behavior()
	_test_update_intervals()
	_test_seed_reproduces_measurements()
	_test_terrain_can_block_measurement()
	_test_terrain_reduces_accuracy_and_classification()
	_test_player_measurement_hides_true_entity_id()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SENSOR SYSTEM TESTS PASSED: 6 test cases")
	quit(0)


func _scenario() -> Variant:
	return LoaderScript.new().load_scenario(SCENARIO_PATH).scenario


func _sensor_system(sensor_definition: StringName = &"sensor_short_range") -> Variant:
	var system: Variant = SensorSystemScript.new()
	system.configure(_scenario())
	var sensor: Variant = SensorStateScript.new(&"sensor_test", sensor_definition, Vector2(500.0, 500.0))
	_expect(system.add_sensor(sensor), "Could not add valid test sensor")
	return system


func _threat(position: Vector2, id: StringName = &"threat_test") -> Variant:
	return ThreatStateScript.new(
		id,
		&"threat_swift",
		position,
		PackedVector2Array([position, position + Vector2.ONE]),
		&"target",
		&"target",
		1.0,
		0.0
	)


func _test_range_and_boundary_behavior() -> void:
	var system: Variant = _sensor_system()
	var boundary: Variant = _threat(Vector2(860.0, 500.0), &"boundary")
	var outside: Variant = _threat(Vector2(860.01, 500.0), &"outside")
	var measurements: Array = system.process_tick(0.0, [boundary, outside])
	_expect(measurements.size() == 1, "Sensor range boundary included outside target or excluded boundary target")
	if measurements.size() == 1:
		_expect(measurements[0].debug_source_entity_id == &"boundary", "Wrong boundary target was measured")


func _test_update_intervals() -> void:
	var short_system: Variant = _sensor_system(&"sensor_short_range")
	var early_system: Variant = _sensor_system(&"sensor_early_warning")
	var target: Variant = _threat(Vector2(500.0, 500.0))
	short_system.process_tick(1.5, [target])
	early_system.process_tick(1.5, [target])
	_expect(short_system.get_measurements().size() == 4, "Short-range sensor did not scan at 0.0, 0.5, 1.0 and 1.5")
	_expect(early_system.get_measurements().size() == 2, "Early-warning sensor did not scan at 0.0 and 1.5")


func _test_seed_reproduces_measurements() -> void:
	var first: Variant = _sensor_system()
	var second: Variant = _sensor_system()
	var target: Variant = _threat(Vector2(600.0, 500.0))
	var first_measurements: Array = first.process_tick(1.0, [target])
	var second_measurements: Array = second.process_tick(1.0, [target])
	_expect(first_measurements.size() == second_measurements.size(), "Same seed changed measurement count")
	for index in first_measurements.size():
		_expect(
			first_measurements[index].measured_position.is_equal_approx(second_measurements[index].measured_position),
			"Same seed changed measurement position"
		)


func _test_terrain_can_block_measurement() -> void:
	var system: Variant = _sensor_system()
	system.set_terrain_visibility_sampler(func(_sensor: Vector2, _threat_position: Vector2, _height: float) -> float: return 0.0)
	var measurements: Array = system.process_tick(0.0, [_threat(Vector2(500.0, 500.0))])
	_expect(measurements.is_empty(), "Terrain visibility of zero did not block measurement")


func _test_terrain_reduces_accuracy_and_classification() -> void:
	var clear_system: Variant = _sensor_system()
	var obscured_system: Variant = _sensor_system()
	clear_system.set_terrain_visibility_sampler(func(_sensor: Vector2, _target: Vector2, _height: float) -> float: return 1.0)
	obscured_system.set_terrain_visibility_sampler(func(_sensor: Vector2, _target: Vector2, _height: float) -> float: return 0.7)
	var target: Variant = _threat(Vector2(500.0, 500.0))
	var clear_measurements: Array = clear_system.process_tick(0.0, [target])
	var obscured_measurements: Array = obscured_system.process_tick(0.0, [target])
	_expect(clear_measurements.size() == 1 and obscured_measurements.size() == 1, "Terrain accuracy fixture did not produce both measurements")
	if clear_measurements.size() == 1 and obscured_measurements.size() == 1:
		_expect(obscured_measurements[0].position_error_radius > clear_measurements[0].position_error_radius, "Obscured terrain did not increase position error")
		_expect(obscured_measurements[0].classification_evidence < clear_measurements[0].classification_evidence, "Obscured terrain did not reduce classification confidence")


func _test_player_measurement_hides_true_entity_id() -> void:
	var system: Variant = _sensor_system()
	var measurements: Array = system.process_tick(0.0, [_threat(Vector2(500.0, 500.0), &"secret_true_id")])
	_expect(not measurements.is_empty(), "Expected a close-range measurement")
	if not measurements.is_empty():
		var player_data: Dictionary = measurements[0].to_player_dictionary()
		_expect(not player_data.has("debug_source_entity_id"), "Player measurement leaked true entity id")
		_expect(not player_data.has("true_position"), "Player measurement leaked true position")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
