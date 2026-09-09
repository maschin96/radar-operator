extends SceneTree

const PATH := "res://data/scenarios/tutorial_mission_2.tres"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var strategies := [
		[[&"sensor_early_warning", Vector2(900, 400)], [&"defense_short_range", Vector2(650, 470)], [&"defense_medium_range", Vector2(1320, 520)]],
		[[&"sensor_short_range", Vector2(380, 300)], [&"sensor_early_warning", Vector2(1400, 450)], [&"defense_short_range", Vector2(650, 470)], [&"defense_short_range", Vector2(1100, 700)]],
	]
	for strategy in strategies:
		var session := make_session(strategy)
		for tick in 3100:
			session.advance(0.1)
		var report := MissionReport.new()
		report.build(session.scenario, session.events, session.replay_frames, session.infrastructure.get_infrastructure())
		print("DARK NETWORK STRATEGY: ", report.get_metrics())
		expect(session.infrastructure.get_mission_status() == InfrastructureSystem.MissionStatus.VICTORY, "Viable dark-network strategy did not win")
		expect(session.events.any(func(e: Dictionary) -> bool: return e.type == &"network_state_changed"), "Mission produced no visible network state change")
	var failed := make_session([[&"sensor_short_range", Vector2(150, 1000)], [&"defense_gun", Vector2(220, 1000)]])
	for tick in 3100:
		failed.advance(0.1)
	expect(failed.infrastructure.get_mission_status() == InfrastructureSystem.MissionStatus.DEFEAT, "Unprotected network did not produce a defeat")
	var original := make_session(strategies[0])
	for tick in 630:
		original.advance(0.1)
	expect(not original.sensors.get_sensors()[0].operational, "Command power loss did not interrupt dependent communications")
	var saves := SaveManager.new()
	var save_path := "/tmp/radar_dark_network_save.json"
	expect(saves.save_session(original, save_path).success, "Outage save failed")
	var loaded := saves.load_session(save_path)
	expect(loaded.success, "Outage load failed: " + str(loaded.get("errors", [])))
	if loaded.success:
		for tick in 200:
			original.advance(0.1)
			loaded.session.advance(0.1)
		expect(original.events == loaded.session.events, "Scheduled outage/restore diverged after load")
		expect(saves.snapshots_match(original.get_persistence_snapshot(), loaded.session.get_persistence_snapshot()), "Outage state diverged after load")
	DirAccess.remove_absolute(save_path)
	var scenario := original.scenario.duplicate(true) as ScenarioDefinition
	scenario.mission_events[0].connection_id = &"missing_connection"
	expect(not ScenarioLoader.new().validate_scenario(scenario).is_empty(), "Invalid timed network event was accepted")
	var tutorial := TutorialController.new()
	tutorial.initialize([{"trigger": &"network_degraded"}])
	expect(tutorial.update_from_snapshot({"network_connections": [{"status": InfrastructureState.NetworkStatus.RESERVE}]}).advanced, "Network tutorial did not react to reserve state")
	for failure in failures:
		push_error(failure)
	print("DARK NETWORK MISSION TESTS PASSED: 5 test cases" if failures.is_empty() else "DARK NETWORK MISSION TESTS FAILED")
	quit(0 if failures.is_empty() else 1)

func make_session(strategy: Array) -> GameSession:
	var loaded := ScenarioLoader.new().load_scenario(PATH)
	expect(loaded.success, "Dark network scenario invalid: " + str(loaded.get("errors", [])))
	var session := GameSession.new()
	session.initialize(loaded.scenario)
	for placement in strategy:
		expect(session.place_system(placement[0], placement[1]).success, "Strategy placement failed")
	expect(session.start_mission().success, "Strategy did not start")
	return session

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
