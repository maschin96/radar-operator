extends SceneTree

const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_active_warfare_save_and_replay()
	_test_time_curve_and_sensor_filter()
	_test_jamming_changes_sensor_measurement_and_cadence()
	_test_decoy_returns_are_seed_deterministic()
	_test_decoy_track_exposes_only_observable_hints()
	_test_later_multi_sensor_evidence_can_clear_suspicion()
	_test_defense_rules_ignore_hidden_source_truth()
	_test_decoy_track_is_lost_and_events_reproduce()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("ELECTRONIC WARFARE TESTS PASSED: 8 test cases")
	quit(0)


func _scenario() -> ScenarioDefinition:
	return ScenarioLoader.new().load_scenario(SCENARIO_PATH).scenario


func _test_time_curve_and_sensor_filter() -> void:
	var system := ElectronicWarfareSystem.new()
	system.configure(_scenario())
	var position := Vector2(200.0, 900.0)
	_expect(is_equal_approx(system.sample_jamming(&"sensor_short_range", position, position, 0.0), 0.0), "Jamming curve did not start at zero")
	_expect(is_equal_approx(system.sample_jamming(&"sensor_short_range", position, position, 7.5), 0.4), "Jamming curve interpolation is incorrect")
	_expect(is_equal_approx(system.sample_jamming(&"sensor_short_range", position, position, 20.0), 0.8), "Jamming curve did not reach configured strength")
	_expect(is_equal_approx(system.sample_jamming(&"sensor_early_warning", position, position, 20.0), 0.0), "Jamming affected an excluded sensor type")


func _test_jamming_changes_sensor_measurement_and_cadence() -> void:
	var scenario := _scenario()
	var clear := SensorSystem.new()
	clear.configure(scenario)
	var jammed := SensorSystem.new()
	jammed.configure(scenario)
	var warfare := ElectronicWarfareSystem.new()
	warfare.configure(scenario)
	jammed.set_electronic_warfare(warfare.sample_jamming, warfare.get_decoy_returns)
	var clear_sensor := SensorState.new(&"sensor", &"sensor_short_range", Vector2(200.0, 900.0))
	var jammed_sensor := SensorState.new(&"sensor", &"sensor_short_range", Vector2(200.0, 900.0))
	clear_sensor.next_scan_time = 7.5
	jammed_sensor.next_scan_time = 7.5
	clear.add_sensor(clear_sensor)
	jammed.add_sensor(jammed_sensor)
	var threat := ThreatState.new(&"real_contact", &"threat_swift", Vector2(240.0, 900.0), PackedVector2Array([Vector2(240.0, 900.0), Vector2(241.0, 900.0)]), &"target", &"target", 1.0, 0.0)
	var clear_measurements := clear.process_tick(7.5, [threat])
	var jammed_measurements := jammed.process_tick(7.5, [threat])
	_expect(clear_measurements.size() == 1 and jammed_measurements.size() == 1, "Moderate-jamming fixture did not produce comparable measurements")
	if clear_measurements.size() == 1 and jammed_measurements.size() == 1:
		_expect(jammed_measurements[0].position_error_radius > clear_measurements[0].position_error_radius, "Jamming did not increase position error")
		_expect(jammed_measurements[0].classification_evidence < clear_measurements[0].classification_evidence, "Jamming did not reduce classification evidence")
	_expect(jammed_sensor.next_scan_time > clear_sensor.next_scan_time, "Jamming did not slow sensor updates")


func _test_decoy_returns_are_seed_deterministic() -> void:
	var first := ElectronicWarfareSystem.new()
	var second := ElectronicWarfareSystem.new()
	first.configure(_scenario())
	second.configure(_scenario())
	var first_returns := first.get_decoy_returns(&"sensor_a", &"sensor_short_range", Vector2(400.0, 900.0), 500.0, 20.0)
	var second_returns := second.get_decoy_returns(&"sensor_a", &"sensor_short_range", Vector2(400.0, 900.0), 500.0, 20.0)
	_expect(first_returns.size() == 1 and second_returns.size() == 1, "Configured decoy did not generate one return")
	if first_returns.size() == 1 and second_returns.size() == 1:
		_expect(first_returns[0].position == second_returns[0].position and first_returns[0].signal_consistency == second_returns[0].signal_consistency, "Same seed changed decoy return")


func _test_decoy_track_exposes_only_observable_hints() -> void:
	var system := SensorSystem.new()
	var scenario := _scenario()
	system.configure(scenario)
	var warfare := ElectronicWarfareSystem.new()
	warfare.configure(scenario)
	system.set_electronic_warfare(warfare.sample_jamming, warfare.get_decoy_returns)
	var sensor := SensorState.new(&"sensor_a", &"sensor_short_range", Vector2(400.0, 900.0))
	sensor.next_scan_time = 20.0
	system.add_sensor(sensor)
	var measurements := system.process_tick(20.0, [])
	_expect(measurements.size() == 1, "Decoy did not enter fusion as a normal measurement")
	if measurements.is_empty():
		return
	var fusion := TrackFusionSystem.new()
	fusion.process_measurements(measurements, 20.0)
	var track := fusion.get_active_tracks()[0]
	var player_data := track.to_player_dictionary()
	_expect(track.possible_deception and not track.evidence_notes.is_empty(), "Inconsistent return produced no observable warning")
	_expect(not player_data.has("debug_source_entities") and not "decoy" in str(player_data).to_lower(), "Player-visible track leaked hidden decoy truth")


func _test_later_multi_sensor_evidence_can_clear_suspicion() -> void:
	var fusion := TrackFusionSystem.new()
	var first := SensorMeasurement.new(1, &"sensor_a", Vector2(300.0, 300.0), 35.0, 20.0, 0.25, &"opaque_return", {"signal_consistency": 0.42, "interference_level": 0.4})
	fusion.process_measurements([first], 20.0)
	for index in 4:
		var measurement := SensorMeasurement.new(index + 2, &"sensor_b", Vector2(300.0 + index, 300.0), 12.0, 21.0 + index, 0.4, &"opaque_return", {"signal_consistency": 1.0, "interference_level": 0.0})
		fusion.process_measurements([measurement], 21.0 + index)
	var track := fusion.get_active_tracks()[0]
	_expect(not track.possible_deception and track.reporting_sensors.size() == 2, "Later multi-sensor evidence could not disprove suspicion")


func _test_decoy_track_is_lost_and_events_reproduce() -> void:
	var first := ElectronicWarfareSystem.new()
	var second := ElectronicWarfareSystem.new()
	first.configure(_scenario())
	second.configure(_scenario())
	for system in [first, second]:
		system.process_tick(20.0)
		system.get_decoy_returns(&"sensor_a", &"sensor_short_range", Vector2(400.0, 900.0), 500.0, 20.0)
	_expect(first.get_events() == second.get_events(), "Electronic-warfare events changed with the same seed")
	var sensor_system := SensorSystem.new()
	var scenario := _scenario()
	sensor_system.configure(scenario)
	sensor_system.set_electronic_warfare(first.sample_jamming, first.get_decoy_returns)
	var sensor := SensorState.new(&"sensor_b", &"sensor_short_range", Vector2(400.0, 900.0))
	sensor.next_scan_time = 60.0
	sensor_system.add_sensor(sensor)
	var measurements := sensor_system.process_tick(60.0, [])
	var fusion := TrackFusionSystem.new()
	fusion.process_measurements(measurements, 60.0)
	_expect(not fusion.get_active_tracks().is_empty(), "Late decoy return did not create a track")
	fusion.process_measurements([], 73.0)
	_expect(fusion.get_active_tracks().is_empty(), "Unsupported decoy track did not become stale and disappear")


func _test_defense_rules_ignore_hidden_source_truth() -> void:
	var scenario := _scenario()
	var defenses := DefenseSystem.new()
	defenses.configure(scenario, [])
	defenses.add_defense(EntityState.new(&"defense", &"defense_short_range", &"player", Vector2(500.0, 500.0)))
	var observed := TrackState.new(&"T0001", Vector2(600.0, 500.0), 20.0, 1.0)
	observed.classification = &"hostile"
	observed.classification_confidence = 1.0
	observed.debug_source_entities[&"real_internal"] = true
	var anomalous := TrackState.new(&"T0002", Vector2(600.0, 500.0), 20.0, 1.0)
	anomalous.classification = observed.classification
	anomalous.classification_confidence = observed.classification_confidence
	anomalous.debug_source_entities[&"hidden_decoy_internal"] = true
	_expect(defenses.get_track_eligibility(observed) == defenses.get_track_eligibility(anomalous), "Defense eligibility used hidden source truth")


func _test_active_warfare_save_and_replay() -> void:
	var session := GameSession.new()
	session.initialize(_scenario())
	_expect(session.place_system(&"sensor_short_range", Vector2(400.0, 900.0)).success, "Warfare fixture sensor placement failed")
	_expect(session.place_system(&"defense_medium_range", Vector2(1320.0, 520.0)).success, "Warfare fixture defense placement failed")
	_expect(session.start_mission().success, "Warfare fixture did not start")
	for tick in 300:
		session.advance(GameSession.TICK_DURATION)
	var internal := session.get_persistence_snapshot().electronic_warfare as Dictionary
	_expect(int(internal.total_decoy_returns) > 0, "Save fixture contains no decoy measurements")
	var player_state := session.get_snapshot().electronic_warfare as Dictionary
	_expect(player_state.keys() == ["zone_levels"], "Player snapshot exposes internal emitter bookkeeping")
	var saves := SaveManager.new()
	var path := "/tmp/radar_operator_warfare_roundtrip.json"
	_expect(saves.save_session(session, path).success, "Active warfare save failed")
	var loaded := saves.load_session(path)
	_expect(loaded.success, "Active warfare load failed: " + str(loaded.get("errors", [])))
	if loaded.success:
		_expect(session.events == loaded.session.events, "Restored warfare event history differs")
		_expect(session.replay_frames == loaded.session.replay_frames, "Restored warfare replay differs")
		for tick in 100:
			session.advance(GameSession.TICK_DURATION)
			loaded.session.advance(GameSession.TICK_DURATION)
		_expect(saves.snapshots_match(session.get_persistence_snapshot(), loaded.session.get_persistence_snapshot()), "Active warfare diverged after load")
		_expect(session.events == loaded.session.events, "Warfare events diverged after load")
	for frame in session.replay_frames:
		_expect(frame.electronic_warfare.keys() == ["zone_levels"], "Replay exposes internal emitter bookkeeping")
	DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
