extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const SessionScript := preload("res://scripts/app/game_session.gd")
const ReportScript := preload("res://scripts/systems/mission_report.gd")
const MovementScript := preload("res://scripts/systems/threat_movement_system.gd")
const SensorSystemScript := preload("res://scripts/systems/sensor_system.gd")
const SensorStateScript := preload("res://scripts/simulation/sensor_state.gd")
const FusionScript := preload("res://scripts/systems/track_fusion_system.gd")
const WaveScript := preload("res://scripts/core/attack_wave_definition.gd")
const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_briefing_and_accessibility_controls()
	_test_complete_vertical_slice()
	_test_contact_stress_profile()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("VERTICAL SLICE QA TESTS PASSED: 3 test cases")
	quit(0)


func _scenario() -> Variant:
	return LoaderScript.new().load_scenario(SCENARIO_PATH).scenario


func _test_briefing_and_accessibility_controls() -> void:
	var main: Variant = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_expect(main.get_node("BriefingPanel").visible, "Mission briefing is not visible on first start")
	var map: Variant = main.get_node("Margin/Layout/Body/TacticalMap")
	main.get_node("Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/HighContrast").button_pressed = true
	main.get_node("Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/ReducedEffects").button_pressed = true
	await process_frame
	_expect(map.high_contrast and map.reduced_effects, "Accessibility toggles did not reach tactical map")
	main.queue_free()
	await process_frame


func _test_complete_vertical_slice() -> void:
	var session: Variant = SessionScript.new()
	session.initialize(_scenario())
	for placement in [
		[&"sensor_early_warning", Vector2(1500.0, 380.0)],
		[&"sensor_short_range", Vector2(380.0, 300.0)],
		[&"defense_medium_range", Vector2(1320.0, 520.0)],
		[&"defense_short_range", Vector2(650.0, 470.0)],
	]:
		_expect(session.place_system(placement[0], placement[1]).success, "Recommended vertical-slice placement failed")
	_expect(session.start_mission().success, "Recommended setup could not start mission")
	for tick in 1800:
		session.advance(0.1)
	_expect(session.phase == GameSession.Phase.ENDED, "Full mission did not reach terminal state")
	var report: Variant = ReportScript.new()
	report.build(session.scenario, session.events, session.replay_frames, session.infrastructure.get_infrastructure())
	var metrics: Dictionary = report.get_metrics()
	_expect(metrics.threats_entered == 3, "Full mission did not execute complete attack wave")
	_expect(metrics.infrastructure_survived >= 2, "Balanced recommended setup failed minimum survivor goal")
	_expect(not report.get_replay_frames().is_empty(), "Full mission produced no replay frames")


func _test_contact_stress_profile() -> void:
	var scenario: Variant = _scenario().duplicate(true)
	var wave: Variant = WaveScript.new()
	wave.id = &"stress_wave"
	wave.start_time = 0.0
	for index in 200:
		wave.spawns.append({
			"id": StringName("stress_%04d" % index),
			"definition_id": &"threat_heavy",
			"delay": 0.0,
			"route": PackedVector2Array([Vector2(0.0, 100.0 + index * 5.0), Vector2(2000.0, 100.0 + index * 5.0)]),
			"target_id": &"",
			"completion": &"exit",
		})
	scenario.attack_waves.clear()
	scenario.attack_waves.append(wave)
	var movement: Variant = MovementScript.new()
	var sensors: Variant = SensorSystemScript.new()
	var fusion: Variant = FusionScript.new()
	movement.configure(scenario)
	sensors.configure(scenario)
	for index in 6:
		sensors.add_sensor(SensorStateScript.new(
			StringName("stress_sensor_%d" % index),
			&"sensor_early_warning",
			Vector2(500.0 + index * 200.0, 600.0)
		))
	var started_usec := Time.get_ticks_usec()
	for tick in 300:
		var time := (tick + 1) * 0.1
		movement.process_tick(0.1, time)
		var measurements: Array = sensors.process_tick(time, movement.get_debug_threat_states())
		fusion.process_measurements(measurements, time)
	var elapsed_seconds := (Time.get_ticks_usec() - started_usec) / 1000000.0
	_expect(elapsed_seconds < 10.0, "Stress profile exceeded ten seconds: %.2f" % elapsed_seconds)
	_expect(not fusion.get_events().is_empty(), "Stress profile generated no sensor/track work")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
