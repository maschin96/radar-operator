extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(MAIN_SCENE_PATH) as PackedScene
	var main: Variant = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.get_node("AudioManager").alerts_enabled = false

	await _test_catalog_and_layout(main)
	_test_complete_control_flow(main)
	_test_track_controls(main)
	main.queue_free()
	await process_frame

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("GAME SESSION UI TESTS PASSED: 3 test cases")
	quit(0)


func _test_catalog_and_layout(main: Variant) -> void:
	var ui_state: Dictionary = main.get_ui_state()
	_expect(ui_state.catalog_count == 2, "Tutorial UI does not expose its sensor and defense")
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0)]:
		main.size = viewport_size
		await process_frame
		var map: Control = main.get_node("Margin/Layout/Body/TacticalMap")
		var detail: Control = main.get_node("Margin/Layout/Body/DetailPanel")
		_expect(map.size.x >= 620.0 and map.size.y >= 480.0, "Tactical map collapsed at %s" % viewport_size)
		_expect(detail.position.x + detail.size.x <= viewport_size.x, "Detail panel exceeded viewport at %s" % viewport_size)


func _test_complete_control_flow(main: Variant) -> void:
	_expect(main.select_build_definition(&"sensor_early_warning"), "Could not select early-warning sensor")
	_expect(main.place_selected_at(Vector2(880.0, 470.0)).success, "Could not place selected sensor through UI flow")
	_expect(main.select_build_definition(&"defense_short_range"), "Could not select short-range defense")
	_expect(main.place_selected_at(Vector2(1120.0, 700.0)).success, "Could not place selected defense through UI flow")
	_expect(main.start_mission().success, "UI could not start a valid mission")
	for tick in 200:
		main.session.advance(0.1)
		if not main.session.get_snapshot().tracks.is_empty():
			break
	var snapshot: Dictionary = main.session.get_snapshot()
	_expect(snapshot.phase == GameSession.Phase.RUNNING, "Session left running phase unexpectedly")
	_expect(not snapshot.tracks.is_empty(), "Integrated movement, sensor and fusion flow produced no track")
	_expect(main.get_ui_state().phase_text == "EINSATZ", "UI did not reflect running phase")


func _test_track_controls(main: Variant) -> void:
	main.set_process(false)
	main.session.set_defense_rules({"automatic_release": false})
	var track: TrackState = main.session.fusion.get_active_tracks()[0]
	track.classification = &"hostile"
	track.estimated_position = Vector2(1200, 700)
	main.get_node("%TacticalMap").object_selected.emit(&"track", track.id)
	main.get_node("%TrackPriority").pressed.emit()
	_expect(track.priority == TrackState.Priority.HIGH, "UI priority control did not reach session")
	main.get_node("%AuthorizeTrack").pressed.emit()
	_expect(track.release_status == TrackState.ReleaseStatus.AUTHORIZED, "UI authorization failed")
	main.get_node("%BlockTrack").pressed.emit()
	_expect(track.release_status == TrackState.ReleaseStatus.BLOCKED, "UI block failed")
	main.get_node("%ResetTrackRelease").pressed.emit()
	_expect(track.release_status == TrackState.ReleaseStatus.DEFAULT, "UI revocation failed")
	track.classification = &"unknown"
	main.get_node("%AuthorizeTrack").pressed.emit()
	_expect(track.release_status == TrackState.ReleaseStatus.DEFAULT, "Rejected authorization changed state")
	_expect("Klassifikation" in main.get_node("%BuildStatus").text, "UI omitted concrete rejection reason")
	var event: Dictionary = main.session.events.back()
	_expect(event.type == &"track_release_rejected" and event.has("simulation_time"), "Rejection lacks timestamped event")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
