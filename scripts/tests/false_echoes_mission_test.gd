extends SceneTree

const PATH := "res://data/scenarios/mission_3_false_echoes.tres"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var strategies := [
		[[&"sensor_early_warning", Vector2(400, 500)], [&"sensor_early_warning", Vector2(1400, 450)], [&"defense_short_range", Vector2(650, 470)], [&"defense_medium_range", Vector2(1320, 520)]],
		[[&"sensor_short_range", Vector2(380, 500)], [&"sensor_early_warning", Vector2(1000, 400)], [&"sensor_short_range", Vector2(1400, 600)], [&"defense_short_range", Vector2(650, 470)], [&"defense_medium_range", Vector2(1320, 520)]],
	]
	var suspected_tracks := 0
	for strategy in strategies:
		var result := ScenarioLoader.new().load_scenario(PATH)
		expect(result.success, "False Echoes scenario is invalid: " + str(result.get("errors", [])))
		var session := GameSession.new()
		session.initialize(result.scenario)
		for placement in strategy:
			expect(session.place_system(placement[0], placement[1]).success, "False Echoes placement failed")
		expect(session.start_mission().success, "False Echoes could not start")
		for tick in 3700:
			session.advance(0.1)
			for track in session.fusion.get_active_tracks():
				if track.possible_deception and track.release_status != TrackState.ReleaseStatus.BLOCKED:
					suspected_tracks += 1
					session.set_track_release(track.id, TrackState.ReleaseStatus.BLOCKED)
		var report := MissionReport.new()
		report.build(session.scenario, session.events, session.replay_frames, session.infrastructure.get_infrastructure())
		print("FALSE ECHOES STRATEGY: ", report.get_metrics())
		expect(is_equal_approx(float(report.get_metrics().peak_interference), 0.65), "Debriefing omitted peak interference")
		expect(session.infrastructure.get_mission_status() == InfrastructureSystem.MissionStatus.VICTORY, "False Echoes sensor strategy did not win")
		expect(not session.scenario.terrain_zones.is_empty() and not session.scenario.visibility_blockers.is_empty(), "Mission has no terrain decisions")
		expect(not session.replay_frames.is_empty() and session.replay_frames[-1].electronic_warfare.zone_levels.western_interference == 0.0, "Interference did not end in replay")
		for track in session.fusion.get_active_tracks():
			expect(not track.to_player_dictionary().has("debug_source_entities"), "Mission exposes hidden source truth")
	expect(suspected_tracks > 0, "Hybrid sensor strategy produced no observable suspicious tracks")
	for failure in failures:
		push_error(failure)
	print("FALSE ECHOES MISSION TESTS PASSED: 3 test cases" if failures.is_empty() else "FALSE ECHOES MISSION TESTS FAILED")
	quit(0 if failures.is_empty() else 1)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
