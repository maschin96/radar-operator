extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const SCENARIO_PATH := "res://data/scenarios/tutorial_mission_1.tres"
const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tutorial_scenario_data()
	await _test_guided_mission_flow()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("TUTORIAL MISSION 1 TESTS PASSED: 2 test cases")
	quit(0)


func _test_tutorial_scenario_data() -> void:
	var result: Dictionary = LoaderScript.new().load_scenario(SCENARIO_PATH)
	_expect(result.success, "Tutorial scenario failed validation: " + str(result.get("errors", [])))
	if not result.success:
		return
	var scenario: ScenarioDefinition = result.scenario
	_expect(scenario.scenario_id == &"tutorial_mission_1", "Tutorial scenario has the wrong id")
	_expect(scenario.tutorial_steps.size() == 10, "Tutorial does not contain ten guided learning steps")
	_expect(scenario.attack_waves.size() == 1, "Tutorial must contain exactly one attack wave")
	_expect(scenario.starting_entities.size() == 1, "Tutorial must contain exactly one protected target")


func _test_guided_mission_flow() -> void:
	var main: Variant = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.get_node("AudioManager").alerts_enabled = false

	_expect(main.tutorial.get_current_index() == 0, "Tutorial did not start at the briefing step")
	main._close_briefing()
	_expect(main.tutorial.get_current_index() == 1, "Closing briefing did not advance tutorial")
	_expect(main.select_build_definition(&"sensor_early_warning"), "Tutorial sensor could not be selected")
	_expect(main.tutorial.get_current_index() == 2, "Sensor selection did not advance tutorial")
	_expect(main.place_selected_at(Vector2(880.0, 470.0)).success, "Tutorial sensor could not be placed")
	_expect(main.tutorial.get_current_index() == 3, "Sensor placement did not advance tutorial")
	_expect(main.select_build_definition(&"defense_short_range"), "Tutorial defense could not be selected")
	_expect(main.tutorial.get_current_index() == 4, "Defense selection did not advance tutorial")
	_expect(main.place_selected_at(Vector2(1120.0, 700.0)).success, "Tutorial defense could not be placed")
	_expect(main.tutorial.get_current_index() == 5, "Defense placement did not advance tutorial")
	_expect(main.start_mission().success, "Tutorial mission could not start")
	_expect(main.tutorial.get_current_index() == 6, "Mission start did not advance tutorial")

	for tick in 250:
		main.session.advance(0.1)
		if main.tutorial.get_current_index() == 7:
			break
	_expect(main.tutorial.get_current_index() == 7, "Track detection did not advance tutorial")
	_expect(is_zero_approx(main.session.simulation.get_time_scale()), "Tutorial did not pause on first track")
	var tracks: Array = main.session.get_snapshot().tracks
	_expect(not tracks.is_empty(), "Tutorial pause contains no inspectable track")
	if not tracks.is_empty():
		main._on_object_selected(&"track", tracks[0].id)
	_expect(main.tutorial.get_current_index() == 8, "Track selection did not advance tutorial")
	main._set_time_scale(4.0)
	_expect(main.tutorial.get_current_index() == 9, "Resuming simulation did not advance tutorial")

	for tick in 400:
		main.session.advance(0.1)
		if main.session.phase == GameSession.Phase.ENDED:
			break
	_expect(main.session.phase == GameSession.Phase.ENDED, "Tutorial mission did not reach evaluation")
	_expect(not main.tutorial.is_active(), "Tutorial remained active after mission evaluation")
	_expect(main.mission_report != null, "Tutorial mission produced no mission report")
	_expect(not main.get_node("TutorialPanel").visible, "Tutorial panel remained visible after completion")
	_expect(main.session.infrastructure.get_mission_status() == InfrastructureSystem.MissionStatus.VICTORY, "Guided tutorial path did not end in victory")
	var protected_target: InfrastructureState = main.session.infrastructure.get_state(&"tutorial_power")
	_expect(is_equal_approx(protected_target.integrity, protected_target.maximum_integrity), "Guided tutorial path allowed damage to the protected infrastructure")
	if main.mission_report != null:
		var metrics: Dictionary = main.mission_report.get_metrics()
		_expect(int(metrics.engagements_succeeded) >= 1, "Tutorial defense never completed a successful engagement")
		_expect(int(metrics.targets_reached) == 0, "Tutorial contact reached the protected target")

	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
