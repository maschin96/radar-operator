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
	_test_invalid_types()
	_test_protected_files()
	_test_destination_rechecked()
	_test_failed_commit_keeps_active_settings()
	_test_explicit_file_recovery()
	_cleanup()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("SETTINGS MANAGER TESTS PASSED: 6 test cases")
	quit(0)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".protected"]:
		var path: String = TEST_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _test_invalid_types() -> void:
	var manager: Variant = SettingsScript.new()
	var invalid_values := [null, [], {}, true, "1", 1.5]
	for key in ["format_version", "window_mode", "master_volume", "alerts_volume", "voice_volume", "alerts_enabled", "high_contrast", "reduced_effects", "action_bindings"]:
		for value in invalid_values:
			if value is bool and key in ["alerts_enabled", "high_contrast", "reduced_effects"]:
				continue
			var data: Dictionary = manager.get_defaults()
			data[key] = value
			_write_json(data)
			var loaded: Dictionary = manager.load_or_defaults(TEST_PATH)
			_expect(loaded.recovered, "Invalid field '%s' was accepted: %s" % [key, str(value)])
			_expect(manager.settings == manager.get_defaults(), "Malformed settings did not restore defaults")
	for value in invalid_values + [0, -1, 1e30, INF, NAN]:
		var data: Dictionary = manager.get_defaults()
		data.action_bindings.simulation_pause = value
		_expect(not manager.validate(data).is_empty(), "Malformed key binding was accepted: %s" % str(value))
	for value in [INF, NAN, -INF]:
		var data: Dictionary = manager.get_defaults()
		data.master_volume = value
		_expect(not manager.validate(data).is_empty(), "Non-finite volume was accepted")


func _test_protected_files() -> void:
	var manager: Variant = SettingsScript.new()
	var future: Dictionary = manager.get_defaults()
	future.format_version = SettingsScript.FORMAT_VERSION + 1
	future["future_setting"] = {"keep": [1, 2, 3]}
	for contents in [JSON.stringify(future), "broken json", "[]"]:
		_write_text(contents)
		var loaded: Dictionary = manager.load_or_defaults(TEST_PATH)
		_expect(loaded.recovered and loaded.warning.contains("Originaldatei"), "Recovery did not explain file protection")
		manager.begin_edit()
		manager.update_draft({"master_volume": 0.12})
		_expect(not manager.commit_draft(TEST_PATH).success, "Commit overwrote a protected file")
		manager.reset_draft()
		_expect(not manager.commit_draft(TEST_PATH).success, "Reset overwrote a protected file")
		_expect(not manager.save(TEST_PATH).success, "Direct save overwrote a protected file")
		_expect(FileAccess.get_file_as_string(TEST_PATH) == contents, "Protected file bytes changed")
		_expect(not FileAccess.file_exists(TEST_PATH + ".tmp"), "Blocked save created a temporary file")


func _test_destination_rechecked() -> void:
	var manager: Variant = SettingsScript.new()
	_write_json(manager.get_defaults())
	manager.load_or_defaults(TEST_PATH)
	manager.begin_edit()
	manager.update_draft({"master_volume": 0.1})
	var future: Dictionary = manager.get_defaults()
	future.format_version = SettingsScript.FORMAT_VERSION + 1
	_write_json(future)
	var original := FileAccess.get_file_as_string(TEST_PATH)
	_expect(not manager.commit_draft(TEST_PATH).success, "File changed after startup was overwritten")
	var fresh: Variant = SettingsScript.new()
	fresh.settings = fresh.get_defaults()
	_expect(not fresh.save(TEST_PATH).success, "Saving without loading bypassed file protection")
	_expect(FileAccess.get_file_as_string(TEST_PATH) == original, "Destination check changed original bytes")


func _test_failed_commit_keeps_active_settings() -> void:
	_cleanup()
	var manager: Variant = SettingsScript.new()
	manager.load_or_defaults(TEST_PATH)
	var before: Dictionary = manager.settings.duplicate(true)
	var volume_before := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var input_before := InputMap.action_get_events("simulation_pause")
	manager.begin_edit()
	manager.update_draft({"master_volume": 0.1, "high_contrast": true})
	manager.set_draft_binding(&"simulation_pause", KEY_P)
	var result: Dictionary = manager.commit_draft(TEST_PATH + "/settings.json")
	_expect(not result.success, "Writing into a missing directory unexpectedly succeeded")
	_expect(manager.settings == before, "Failed save changed active settings")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), volume_before), "Failed save changed active volume")
	_expect(InputMap.action_get_events("simulation_pause") == input_before, "Failed save changed active input bindings")
	_expect(manager.draft.high_contrast, "Failed save discarded the editable draft")
	_expect(manager.commit_draft(TEST_PATH).success, "Retry could not save retained draft")
	_expect(manager.settings.high_contrast and InputMap.action_get_events("simulation_pause")[0].physical_keycode == KEY_P, "Successful retry did not apply settings")


func _test_explicit_file_recovery() -> void:
	_cleanup()
	_write_text("broken original")
	var manager: Variant = SettingsScript.new()
	manager.load_or_defaults(TEST_PATH)
	manager.begin_edit()
	manager.update_draft({"high_contrast": true})
	_expect(DirAccess.rename_absolute(TEST_PATH, TEST_PATH + ".protected") == OK, "Could not preserve original for explicit recovery")
	_expect(manager.commit_draft(TEST_PATH).success, "Renaming damaged file did not enable recovery")
	var restored: Variant = SettingsScript.new()
	var loaded: Dictionary = restored.load_or_defaults(TEST_PATH)
	_expect(not loaded.recovered and restored.settings.high_contrast, "Recovered settings did not survive restart")
	_expect(FileAccess.get_file_as_string(TEST_PATH + ".protected") == "broken original", "Recovery changed preserved original")


func _write_json(data: Dictionary) -> void:
	_write_text(JSON.stringify(data))


func _write_text(contents: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
