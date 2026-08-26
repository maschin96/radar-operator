extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const MovementScript := preload("res://scripts/systems/threat_movement_system.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_wave_timing_and_three_classes()
	_test_movement_is_tick_partition_independent()
	_test_target_completion_emits_once()
	_test_exit_completion_is_distinct()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("THREAT MOVEMENT TESTS PASSED: 4 test cases")
	quit(0)


func _load_scenario() -> Variant:
	var result: Dictionary = LoaderScript.new().load_scenario(SCENARIO_PATH)
	if not result.success:
		_failures.append("Could not load movement scenario: " + str(result.errors))
		return null
	return result.scenario


func _test_wave_timing_and_three_classes() -> void:
	var movement: Variant = MovementScript.new()
	movement.configure(_load_scenario())
	movement.process_tick(0.1, 4.9)
	_expect(movement.get_debug_threat_states().is_empty(), "Threat spawned before wave time")
	movement.process_tick(0.1, 5.0)
	_expect(movement.get_debug_threat_states().size() == 1, "First threat did not spawn at wave time")
	movement.process_tick(0.1, 12.0)
	movement.process_tick(0.1, 22.0)
	var entered_definitions: Dictionary = {}
	for event in movement.get_events():
		if event.type == &"threat_entered":
			entered_definitions[event.definition_id] = true
	_expect(entered_definitions.size() == 3, "Not all three threat classes entered")


func _test_movement_is_tick_partition_independent() -> void:
	var fine: Variant = MovementScript.new()
	var coarse: Variant = MovementScript.new()
	var scenario: Variant = _load_scenario()
	fine.configure(scenario)
	coarse.configure(scenario)
	for tick in 100:
		fine.process_tick(0.1, 5.0 + (tick + 1) * 0.1)
	for tick in 10:
		coarse.process_tick(1.0, 5.0 + (tick + 1) * 1.0)
	var fine_states: Array = fine.get_debug_threat_states()
	var coarse_states: Array = coarse.get_debug_threat_states()
	_expect(fine_states.size() == coarse_states.size(), "Tick partition changed active threat count")
	if not fine_states.is_empty() and not coarse_states.is_empty():
		_expect(fine_states[0].position.is_equal_approx(coarse_states[0].position), "Tick partition changed threat position")


func _test_target_completion_emits_once() -> void:
	var movement: Variant = MovementScript.new()
	movement.configure(_load_scenario())
	for tick in 400:
		movement.process_tick(0.1, (tick + 1) * 0.1)
	var reached_counts: Dictionary = {}
	for event in movement.get_events():
		if event.type == &"threat_target_reached":
			reached_counts[event.threat_id] = int(reached_counts.get(event.threat_id, 0)) + 1
	_expect(reached_counts.size() == 3, "Not every threat reached its target")
	for count in reached_counts.values():
		_expect(count == 1, "A target completion event was emitted more than once")


func _test_exit_completion_is_distinct() -> void:
	var scenario: Variant = _load_scenario().duplicate(true)
	var wave: Variant = scenario.attack_waves[0].duplicate(true)
	wave.spawns = wave.spawns.duplicate(true)
	wave.spawns[0] = wave.spawns[0].duplicate(true)
	wave.spawns[0].completion = &"exit"
	wave.spawns.resize(1)
	scenario.attack_waves.clear()
	scenario.attack_waves.append(wave)
	var movement: Variant = MovementScript.new()
	movement.configure(scenario)
	for tick in 200:
		movement.process_tick(0.1, (tick + 1) * 0.1)
	var exit_count := 0
	var target_count := 0
	for event in movement.get_events():
		exit_count += int(event.type == &"threat_exited")
		target_count += int(event.type == &"threat_target_reached")
	_expect(exit_count == 1 and target_count == 0, "Exit route did not produce exactly one distinct exit event")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
