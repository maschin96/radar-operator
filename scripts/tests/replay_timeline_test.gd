extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var frames := [
		{"simulation_time": 0.0, "tracks": [{"id": "T1", "estimated_position": {"x": 0.0, "y": 0.0}}]},
		{"simulation_time": 10.0, "tracks": [{"id": "T1", "estimated_position": {"x": 100.0, "y": 0.0}}]},
	]
	var events := [
		{"index": 1, "simulation_time": 8.0, "type": &"track_release_changed", "category": &"session", "data": {"track_id": "T1"}},
		{"index": 0, "simulation_time": 2.0, "type": &"track_created", "category": &"fusion", "data": {"track_id": "T1"}},
	]
	var timeline := ReplayTimeline.new()
	timeline.configure(frames, events)
	timeline.seek(5.0)
	expect(is_equal_approx(timeline.get_frame().tracks[0].estimated_position.x, 50.0), "Replay interpolation failed")
	expect(frames[0].tracks[0].estimated_position.x == 0.0, "Replay mutated recorded data")
	expect(timeline.events[0].index == 0, "Replay did not sort events chronologically")
	timeline.playing = true
	timeline.speed = 2.0
	timeline.advance(1.0)
	expect(timeline.time == 7.0, "Replay speed failed")
	timeline.advance(10.0)
	expect(timeline.time == 10.0 and not timeline.playing, "Replay did not stop at its end")
	var panel := ReplayPanel.new()
	root.add_child(panel)
	panel.configure({"replay_frames": frames, "events": events})
	panel.select_event(1)
	expect(panel.timeline.time == 8.0 and panel.map.focus_position == Vector2(80, 0), "Event click did not seek and focus its track")
	panel.queue_free()
	await process_frame
	var session := GameSession.new()
	session.initialize(ScenarioLoader.new().load_scenario("res://data/scenarios/tutorial_mission_1.tres").scenario)
	session.place_system(&"sensor_early_warning", Vector2(880, 470))
	session.place_system(&"defense_short_range", Vector2(1120, 700))
	session.start_mission()
	for tick in 57:
		session.advance(0.1)
	expect(session.abort_mission().success, "Running mission could not be aborted")
	expect(session.manually_aborted and session.phase == GameSession.Phase.ENDED, "Abort did not reach terminal state")
	expect(is_equal_approx(float(session.replay_frames[-1].simulation_time), 5.7), "Abort replay omitted the final partial second")
	var snapshot := session.get_persistence_snapshot()
	session.advance(1.0)
	expect(session.get_persistence_snapshot() == snapshot, "Aborted mission kept simulating")
	var save := SaveManager.new()
	var path := "/tmp/radar_replay_abort.json"
	expect(save.save_session(session, path).success, "Abort save failed")
	var loaded := save.load_session(path)
	expect(loaded.success, "Abort restore failed: " + str(loaded.get("errors", [])))
	if loaded.success:
		expect(loaded.session.manually_aborted and loaded.session.replay_frames == session.replay_frames, "Abort replay did not reproduce")
	DirAccess.remove_absolute(path)
	for failure in failures:
		push_error(failure)
	print("REPLAY TIMELINE TESTS PASSED: 4 test cases" if failures.is_empty() else "REPLAY TIMELINE TESTS FAILED")
	quit(0 if failures.is_empty() else 1)
func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
