extends SceneTree

const CatalogScript := preload("res://scripts/core/scenario_catalog.gd")
const ProfileScript := preload("res://scripts/systems/profile_manager.gd")
const TEST_PATH := "user://profile_manager_test.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var catalog: Variant = CatalogScript.new()
	_expect(catalog.discover().success, "Test catalog failed to load")
	var manager: Variant = ProfileScript.new()
	manager.create_default(catalog)
	_expect(manager.is_unlocked(&"tutorial_mission_1"), "Default profile did not unlock entry mission")
	_expect(not manager.is_unlocked(&"mvp_test_scenario"), "Default profile unlocked dependent mission")
	_expect(not manager.reset(catalog, false).success, "Profile reset did not require confirmation")
	manager.record_mission_result(&"tutorial_mission_1", InfrastructureSystem.MissionStatus.VICTORY, catalog)
	_expect(manager.is_completed(&"tutorial_mission_1"), "Victory was not recorded")
	_expect(manager.is_unlocked(&"mvp_test_scenario"), "Victory did not unlock dependent mission")
	_expect(manager.save(TEST_PATH).success, "Profile could not be saved")
	var restored: Variant = ProfileScript.new()
	_expect(restored.load_or_create(TEST_PATH, catalog).success, "Saved profile could not be loaded")
	_expect(restored.is_completed(&"tutorial_mission_1") and restored.is_unlocked(&"mvp_test_scenario"), "Profile state changed after restart")
	_cleanup()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("PROFILE MANAGER TESTS PASSED: 1 test case")
	quit(0)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
