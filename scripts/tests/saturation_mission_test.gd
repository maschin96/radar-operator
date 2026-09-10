extends SceneTree

const PATH := "res://data/scenarios/mission_4_saturation.tres"
const CHALLENGE := "res://data/campaign/mission_4_challenge.tres"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var strategies := [
		[[&"sensor_early_warning", Vector2(400, 500)], [&"sensor_early_warning", Vector2(1400, 450)], [&"defense_short_range", Vector2(650, 470)], [&"defense_medium_range", Vector2(1320, 520)], [&"defense_gun", Vector2(1100, 700)]],
		[[&"sensor_early_warning", Vector2(900, 400)], [&"sensor_short_range", Vector2(380, 500)], [&"sensor_short_range", Vector2(1400, 600)], [&"defense_short_range", Vector2(650, 470)], [&"defense_short_range", Vector2(1100, 700)], [&"defense_medium_range", Vector2(1500, 600)]],
	]
	for index in 3:
		var path := CHALLENGE if index == 2 else PATH
		var strategy: Array = strategies[index % 2] if index < 2 else strategies[0]
		var loaded := ScenarioLoader.new().load_scenario(path)
		expect(loaded.success, "Saturation scenario invalid: " + str(loaded.get("errors", [])))
		var session := GameSession.new()
		session.initialize(loaded.scenario)
		for placement in strategy:
			expect(session.place_system(placement[0], placement[1]).success, "Saturation strategy exceeded budget or violated placement")
		expect(session.start_mission().success, "Saturation mission did not start")
		for tick in 4300:
			if tick == 1400 and index != 1:
				expect(session.relocate_system(&"placed_0005", Vector2(1600, 650)).success, "Mobile reserve relocation failed")
			session.advance(0.1)
		var report := MissionReport.new()
		report.build(session.scenario, session.events, session.replay_frames, session.infrastructure.get_infrastructure())
		print("SATURATION STRATEGY ", index, ": ", report.get_metrics())
		expect(session.infrastructure.get_mission_status() == InfrastructureSystem.MissionStatus.VICTORY, "Saturation strategy did not win")
		expect(report.get_metrics().ammunition_spent > 0, "Saturation debriefing contains no ammunition use")
		if index != 1:
			expect(report.get_metrics().relocations_completed == 1, "Saturation debriefing omitted reserve relocation")
		if index == 2:
			var saves := SaveManager.new()
			var save_path := "/tmp/radar_saturation_challenge.json"
			expect(saves.save_session(session, save_path).success, "Challenge save failed")
			var restored := saves.load_session(save_path)
			expect(restored.success, "Challenge restore failed: " + str(restored.get("errors", [])))
			if restored.success:
				expect(restored.session.scenario.starting_budget == 3400, "Load silently changed difficulty budget")
			DirAccess.remove_absolute(save_path)
	var app = load("res://scenes/app/app_shell.tscn").instantiate()
	app.profile_path = "/tmp/radar_saturation_profile.json"
	app.settings_path = "/tmp/radar_saturation_settings.json"
	root.add_child(app)
	await process_frame
	expect(not app.launch_variant(&"mission_4_saturation", CHALLENGE), "Locked challenge was launched")
	app.profile_manager.profile.unlocked_missions.append("mission_4_saturation")
	expect(app.launch_variant(&"mission_4_saturation", CHALLENGE), "Unlocked challenge could not be launched")
	expect(app.gameplay.session.scenario.starting_budget == 3400, "Variant UI selected the standard budget")
	expect(app.profile_manager.get_campaign_progress(app.catalog).total == 4, "Free scenario was counted as a fifth campaign mission")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/radar_saturation_profile.json")
	for failure in failures:
		push_error(failure)
	print("SATURATION MISSION TESTS PASSED: 5 test cases" if failures.is_empty() else "SATURATION MISSION TESTS FAILED")
	quit(0 if failures.is_empty() else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
