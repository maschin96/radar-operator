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
	session.start_mission()
	for tick in 75:
		session.advance(0.1)
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
	for tick in 20:
		session.advance(0.1)
		loaded.session.advance(0.1)
	_expect(saves.snapshots_match(loaded.session.get_persistence_snapshot(), session.get_persistence_snapshot()), "Loaded mission diverged during deterministic continuation")


func _test_corrupt_and_incompatible_files_are_rejected(saves: Variant) -> void:
	var file := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_expect(not saves.load_session(CORRUPT_PATH).success, "Corrupt JSON save was accepted")
	file = FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 999}))
	file.close()
	_expect(not saves.load_session(CORRUPT_PATH).success, "Incompatible save version was accepted")


func _cleanup() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak", CORRUPT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
