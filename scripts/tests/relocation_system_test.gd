extends SceneTree

const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"
const SAVE_PREFIX := "/tmp/radar_operator_relocation_system_test"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rejections_and_route_validation()
	_test_relocation_lifecycle_and_network_lockout()
	_test_mobile_defense_uses_shared_state_and_lockout()
	_test_cancellation_during_teardown_and_movement()
	_test_system_failure_aborts_relocation()
	_test_replay_frames_include_relocation_state()
	_test_save_load_in_every_relocation_phase()
	_cleanup()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("RELOCATION SYSTEM TESTS PASSED: 7 test cases")
	quit(0)


func _test_rejections_and_route_validation() -> void:
	var session := _new_session(false)
	var mobile := session.placement.get_placement(&"placed_0001")
	var preview := session.preview_relocation(mobile.id, Vector2(700.0, 200.0))
	_expect(not preview.success and preview.reasons.has("phase_not_allowed"), "Relocation was allowed during an unsupported phase")
	_expect(session.start_mission().success, "Validation session did not start")
	preview = session.preview_relocation(&"placed_0002", Vector2(700.0, 300.0))
	_expect(not preview.success and preview.reasons.has("not_mobile"), "Stationary-only system accepted a relocation")
	preview = session.preview_relocation(mobile.id, Vector2(300.0, 200.0))
	_expect(not preview.success and preview.reasons.has("too_close_to_system"), "Relocation ignored minimum spacing")
	preview = session.preview_relocation(mobile.id, Vector2(1000.0, 600.0))
	_expect(not preview.success and preview.reasons.has("blocked_zone"), "Relocation accepted a blocked target")
	preview = session.preview_relocation(mobile.id, Vector2(700.0, 200.0))
	_expect(preview.success and (preview.path as PackedVector2Array).size() >= 2, "Valid relocation did not produce a route")
	mobile.position = Vector2(800.0, 600.0)
	preview = session.preview_relocation(mobile.id, Vector2(1200.0, 600.0))
	_expect(preview.success, "Route planner did not find a deterministic detour around terrain")
	if preview.success:
		for point in preview.path:
			_expect(not Rect2(940.0, 550.0, 120.0, 120.0).has_point(point), "Relocation route crossed a blocked terrain cell")


func _test_relocation_lifecycle_and_network_lockout() -> void:
	var session := _new_session()
	var sensor := session.placement.get_placement(&"placed_0001") as SensorState
	var initial_budget := session.placement.get_budget()
	var result := session.relocate_system(sensor.id, Vector2(700.0, 200.0))
	_expect(result.success, "Valid mobile sensor relocation was rejected: " + str(result))
	_expect(sensor.mobility_status == EntityState.MobilityStatus.TEARDOWN, "Relocation did not enter teardown")
	_expect(not sensor.powered and not sensor.operational, "Relocating sensor remained operational during teardown")
	_expect(session.placement.get_budget() == initial_budget - 40, "Relocation cost was not charged exactly once")
	var scans_before := sensor.scan_count
	_advance(session, 2.2)
	_expect(sensor.mobility_status == EntityState.MobilityStatus.MOVING and sensor.position.x > 200.0, "Relocation did not transition into visible movement")
	_expect(sensor.scan_count == scans_before, "Sensor scanned while teardown or movement was active")
	_advance_until_stationary(session, sensor)
	_expect(sensor.position.is_equal_approx(Vector2(700.0, 200.0)), "Relocation did not finish at the requested target")
	_expect(sensor.powered and sensor.operational, "Sensor did not return to service after setup")
	_expect(_has_event(session.events, &"relocation_completed"), "Completed relocation was not logged")


func _test_cancellation_during_teardown_and_movement() -> void:
	var session := _new_session()
	var sensor := session.placement.get_placement(&"placed_0001") as SensorState
	var origin := sensor.position
	_expect(session.relocate_system(sensor.id, Vector2(700.0, 300.0)).success, "Teardown cancellation setup failed")
	_expect(session.cancel_relocation(sensor.id).success, "Relocation could not be cancelled during teardown")
	_expect(sensor.mobility_status == EntityState.MobilityStatus.STATIONARY and sensor.position == origin, "Teardown cancellation did not restore the original ready state")
	_expect(session.relocate_system(sensor.id, Vector2(700.0, 300.0)).success, "Moving cancellation setup failed")
	_advance(session, 2.5)
	var stopped_position := sensor.position
	_expect(sensor.mobility_status == EntityState.MobilityStatus.MOVING, "System was not moving before cancellation")
	_expect(session.cancel_relocation(sensor.id).success, "Relocation could not be cancelled during movement")
	_expect(sensor.mobility_status == EntityState.MobilityStatus.SETUP and sensor.position == stopped_position, "Moving cancellation did not begin setup at the current position")
	_expect(not sensor.operational, "Cancelled moving system became operational before setup")
	_advance_until_stationary(session, sensor)
	_expect(sensor.position == stopped_position and sensor.operational, "Cancelled relocation did not complete setup at its stopping point")


func _test_mobile_defense_uses_shared_state_and_lockout() -> void:
	var session := _new_session()
	var defense := session.placement.get_placement(&"placed_0002") as DefenseState
	_expect(session.defenses.get_defenses()[0] == defense, "Placement and defense simulation do not share relocation state")
	var result := session.relocate_system(defense.id, Vector2(600.0, 350.0))
	_expect(result.success, "Valid mobile defense relocation was rejected")
	_expect(not defense.powered and not defense.operational, "Relocating defense remained operational")
	_advance(session, GameSession.TICK_DURATION)
	_expect(defense.status == DefenseState.Status.OFFLINE, "Defense did not enter its visible offline state during relocation")
	_advance_until_stationary(session, defense)
	_expect(defense.position.is_equal_approx(Vector2(600.0, 350.0)) and defense.operational, "Defense did not return to service at its relocation target")


func _test_system_failure_aborts_relocation() -> void:
	var session := _new_session()
	var sensor := session.placement.get_placement(&"placed_0001") as SensorState
	_expect(session.relocate_system(sensor.id, Vector2(700.0, 200.0)).success, "Failure test relocation was rejected")
	sensor.active = false
	_advance(session, GameSession.TICK_DURATION)
	_expect(sensor.mobility_status == EntityState.MobilityStatus.STATIONARY, "Failed system retained a running relocation")
	_expect(not sensor.powered and not sensor.operational, "Failed relocating system appeared operational")
	_expect(_has_event(session.events, &"relocation_failed"), "Relocation failure was not logged")


func _test_replay_frames_include_relocation_state() -> void:
	var session := _new_session()
	var sensor := session.placement.get_placement(&"placed_0001") as SensorState
	_expect(session.relocate_system(sensor.id, Vector2(700.0, 200.0)).success, "Replay test relocation was rejected")
	_advance(session, 3.0)
	_expect(not session.replay_frames.is_empty(), "Relocation generated no replay frames")
	var frame: Dictionary = session.replay_frames[-1]
	_expect(frame.has("placements") and not frame.placements.is_empty(), "Replay frame omitted system relocation states")
	var sensor_frame: Dictionary = {}
	for placement in frame.get("placements", []):
		if String(placement.id) == "placed_0001":
			sensor_frame = placement
			break
	_expect(not sensor_frame.is_empty() and int(sensor_frame.mobility_status) != EntityState.MobilityStatus.STATIONARY, "Replay frame hid the active relocation phase: " + str(sensor_frame))


func _test_save_load_in_every_relocation_phase() -> void:
	var phase_ticks := [0, 30, 75]
	var expected_phases := [EntityState.MobilityStatus.TEARDOWN, EntityState.MobilityStatus.MOVING, EntityState.MobilityStatus.SETUP]
	for index in phase_ticks.size():
		var session := _new_session()
		var sensor := session.placement.get_placement(&"placed_0001") as SensorState
		_expect(session.relocate_system(sensor.id, Vector2(700.0, 200.0)).success, "Save/load phase relocation was rejected")
		for _tick in int(phase_ticks[index]):
			session.advance(GameSession.TICK_DURATION)
		_expect(sensor.mobility_status == expected_phases[index], "Save fixture did not reach expected relocation phase")
		var path := "%s_%d.json" % [SAVE_PREFIX, index]
		var manager := SaveManager.new()
		_expect(manager.save_session(session, path).success, "Relocation phase could not be saved")
		var loaded := manager.load_session(path)
		_expect(loaded.success, "Relocation phase could not be restored: " + str(loaded.get("errors", [])))
		if loaded.success:
			_expect(manager.snapshots_match(session.get_persistence_snapshot(), loaded.session.get_persistence_snapshot()), "Relocation phase changed after deterministic restore")


func _new_session(use_mobile_defense: bool = true) -> GameSession:
	var scenario := ScenarioLoader.new().load_scenario(SCENARIO_PATH).scenario as ScenarioDefinition
	var session := GameSession.new()
	session.initialize(scenario)
	_expect(session.place_system(&"sensor_short_range", Vector2(200.0, 200.0)).success, "Test sensor placement failed")
	var defense_id := &"defense_gun" if use_mobile_defense else &"defense_short_range"
	_expect(session.place_system(defense_id, Vector2(300.0, 200.0)).success, "Test defense placement failed")
	if use_mobile_defense:
		_expect(session.start_mission().success, "Relocation test mission did not start")
	return session


func _advance(session: GameSession, duration: float) -> void:
	for _tick in ceili(duration / GameSession.TICK_DURATION):
		session.advance(GameSession.TICK_DURATION)


func _advance_until_stationary(session: GameSession, entity: EntityState) -> void:
	for _tick in 300:
		if entity.mobility_status == EntityState.MobilityStatus.STATIONARY:
			return
		session.advance(GameSession.TICK_DURATION)
	_expect(false, "Relocation did not finish within the guard interval")


func _has_event(events: Array[Dictionary], type: StringName) -> bool:
	for event in events:
		if StringName(event.type) == type:
			return true
	return false


func _cleanup() -> void:
	for index in 3:
		for suffix in ["", ".tmp", ".bak"]:
			var path := "%s_%d.json%s" % [SAVE_PREFIX, index, suffix]
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
