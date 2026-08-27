extends SceneTree

const SettingsScript := preload("res://scripts/systems/settings_manager.gd")
const TEST_PATH := "user://settings_manager_test.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var manager: Variant = SettingsScript.new()
	var loaded: Dictionary = manager.load_or_defaults(TEST_PATH)
	_expect(loaded.success and not loaded.recovered, "Missing settings did not produce safe defaults")
	manager.begin_edit()
	manager.update_draft({"high_contrast": true, "master_volume": 0.35})
	_expect(manager.commit_draft(TEST_PATH).success, "Valid settings could not be committed")
	var restored: Variant = SettingsScript.new()
	var restored_result: Dictionary = restored.load_or_defaults(TEST_PATH)
	_expect(restored_result.success and restored.settings.high_contrast, "Settings did not survive restart")
	_expect(is_equal_approx(float(restored.settings.master_volume), 0.35), "Volume changed during serialization")
	restored.begin_edit()
	var bindings_before: Dictionary = restored.draft.action_bindings.duplicate()
	var conflict: Dictionary = restored.set_draft_binding(&"simulation_speed_1", KEY_SPACE)
	_expect(not conflict.success, "Conflicting key binding was accepted")
	_expect(restored.draft.action_bindings == bindings_before, "Rejected conflict changed the active draft")
	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string("not json")
	corrupt.close()
	var recovered: Variant = SettingsScript.new()
	var recovery_result: Dictionary = recovered.load_or_defaults(TEST_PATH)
	_expect(recovery_result.success and recovery_result.recovered, "Corrupt settings did not fall back safely")
	_expect(recovered.settings == recovered.get_defaults(), "Recovery did not restore all defaults")
	_cleanup()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SETTINGS MANAGER TESTS PASSED: 1 test case")
	quit(0)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
