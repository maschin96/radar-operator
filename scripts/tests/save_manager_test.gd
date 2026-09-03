extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const SessionScript := preload("res://scripts/app/game_session.gd")
const SaveScript := preload("res://scripts/systems/save_manager.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"
const SAVE_PATH := "/tmp/radar_operator_save_roundtrip.json"
const CORRUPT_PATH := "/tmp/radar_operator_save_corrupt.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var session: Variant = _running_session()
	var saves: Variant = SaveScript.new()

	_test_roundtrip_and_atomic_replacement(saves, session)
	_test_continuation_is_deterministic(saves, session)
	_test_corrupt_and_incompatible_files_are_rejected(saves)
	_cleanup()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SAVE MANAGER TESTS PASSED: 3 test cases")
	quit(0)


func _running_session() -> Variant:
	var scenario: Variant = LoaderScript.new().load_scenario(SCENARIO_PATH).scenario
	var session: Variant = SessionScript.new()
	session.initialize(scenario)
	session.place_system(&"sensor_early_warning", Vector2(1500.0, 380.0))
	session.place_system(&"defense_medium_range", Vector2(1320.0, 520.0))
	session.set_defense_rules({"profile_id": "save-test", "display_name": "Gespeicherte Wache", "minimum_classification": "hostile"})
	session.start_mission()
	for tick in 75:
		session.advance(0.1)
	var tracks: Array = session.fusion.get_active_tracks()
	_expect(not tracks.is_empty(), "Save fixture did not produce a controllable track")
	if not tracks.is_empty():
		session.set_track_priority(tracks[0].id, TrackState.Priority.CRITICAL, "Save fixture")
		session.set_track_release(tracks[0].id, TrackState.ReleaseStatus.BLOCKED)
		session.set_track_release(&"missing_track", TrackState.ReleaseStatus.AUTHORIZED)
		session.set_defense_rules({"display_name": ""})
		session.set_defense_rules({"automatic_release": false})
		var network_result: Dictionary = session.set_network_connection_enabled(&"auto_energy_placed_0001", false)
		_expect(network_result.success, "Save fixture could not change a network connection")
		network_result = session.set_network_connection_enabled(&"auto_communication_placed_0002", false)
		_expect(network_result.success, "Save fixture could not change a communication connection")
	return session


func _test_roundtrip_and_atomic_replacement(saves: Variant, session: Variant) -> void:
	_expect(saves.save_session(session, SAVE_PATH).success, "Initial save failed")
	_expect(saves.save_session(session, SAVE_PATH).success, "Replacing existing save failed")
	var loaded: Dictionary = saves.load_session(SAVE_PATH)
	_expect(loaded.success, "Save/load roundtrip failed: " + str(loaded.get("errors", [])))
	if loaded.success:
		_expect(saves.snapshots_match(loaded.session.get_persistence_snapshot(), session.get_persistence_snapshot()), "Loaded state differs from saved state")


func _test_continuation_is_deterministic(saves: Variant, session: Variant) -> void:
	var loaded: Dictionary = saves.load_session(SAVE_PATH)
	if not loaded.success:
		_failures.append("Could not load for continuation test")
		return
	for tick in 90:
		session.advance(0.1)
		loaded.session.advance(0.1)
	_expect(saves.snapshots_match(loaded.session.get_persistence_snapshot(), session.get_persistence_snapshot()), "Loaded mission diverged during deterministic continuation")
	_expect(not session.sensors.get_sensors()[0].powered, "Energy outage did not disable connected sensor after reserve expiry")
	_expect(not session.defenses.get_defenses()[0].operational, "Communication outage did not disable connected defense after reserve expiry")


func _test_corrupt_and_incompatible_files_are_rejected(saves: Variant) -> void:
	var file := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_expect(not saves.load_session(CORRUPT_PATH).success, "Corrupt JSON save was accepted")
	file = FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 999}))
	file.close()
	_expect(not saves.load_session(CORRUPT_PATH).success, "Incompatible save version was accepted")
	var old_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	old_data.format_version = 2
	file = FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	var old_result: Dictionary = saves.load_session(CORRUPT_PATH)
	_expect(not old_result.success and "Unsupported save format version" in str(old_result.errors), "Old saves were not rejected explicitly")


func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak", CORRUPT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
