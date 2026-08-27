class_name SaveManager
extends RefCounted

const FORMAT_VERSION := 1


func save_session(session: GameSession, path: String) -> Dictionary:
	var snapshot := session.get_persistence_snapshot()
	var data := {
		"format_version": FORMAT_VERSION,
		"scenario_path": session.scenario.resource_path,
		"scenario_id": str(session.scenario.scenario_id),
		"seed": session.scenario.seed,
		"phase": session.phase,
		"tick": snapshot.tick,
		"time_scale": snapshot.time_scale,
		"placements": snapshot.placements,
		"defense_rules": snapshot.defense_rules,
		"player_commands": snapshot.player_commands,
		"expected_snapshot": snapshot,
	}
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["Could not open temporary save file: %s" % FileAccess.get_open_error()]}
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	var replace_result := _replace_file_safely(temporary_path, path)
	if replace_result != OK:
		return {"success": false, "errors": ["Could not replace save file: %s" % error_string(replace_result)]}
	return {"success": true, "path": path}


func load_session(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "errors": ["Save file does not exist"]}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "errors": ["Could not open save file"]}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return {"success": false, "errors": ["Save file is not valid JSON: %s" % json.get_error_message()]}
	var data: Dictionary = json.data
	var errors := _validate_save_data(data)
	if not errors.is_empty():
		return {"success": false, "errors": errors}

	var scenario := ResourceLoader.load(String(data.scenario_path)) as ScenarioDefinition
	if scenario == null:
		return {"success": false, "errors": ["Scenario resource could not be loaded"]}
	scenario = scenario.duplicate(true)
	scenario.seed = int(data.seed)
	var session := GameSession.new()
	session.initialize(scenario)
	var saved_placements: Array = data.placements.duplicate(true)
	saved_placements.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("id", "")) < String(right.get("id", ""))
	)
	for placement_data in saved_placements:
		var position_data: Dictionary = placement_data.position
		var result := session.place_system(
			StringName(placement_data.definition_id),
			Vector2(float(position_data.x), float(position_data.y))
		)
		if not result.success:
			return {"success": false, "errors": ["Saved placement could not be restored: " + str(result)]}
	var command_index := 0
	var commands: Array = data.player_commands
	if int(data.phase) != GameSession.Phase.PREPARATION:
		var start_result := session.start_mission()
		if not start_result.success:
			return {"success": false, "errors": ["Saved running mission could not be started"]}
		for tick in int(data.tick):
			while command_index < commands.size() and int(commands[command_index].tick) == tick:
				session.replay_player_command(commands[command_index])
				command_index += 1
			session.advance(GameSession.TICK_DURATION)
		while command_index < commands.size() and int(commands[command_index].tick) == int(data.tick):
			session.replay_player_command(commands[command_index])
			command_index += 1
	else:
		while command_index < commands.size() and int(commands[command_index].tick) == 0:
			session.replay_player_command(commands[command_index])
			command_index += 1
	session.set_time_scale(float(data.time_scale))

	var actual_snapshot := session.get_persistence_snapshot()
	var snapshot_difference := _first_difference(data.expected_snapshot, actual_snapshot)
	if not snapshot_difference.is_empty():
		return {"success": false, "errors": [
			"Restored state does not match saved deterministic snapshot at "
			+ snapshot_difference
		]}
	return {"success": true, "session": session}


func snapshots_match(first: Dictionary, second: Dictionary) -> bool:
	return _first_difference(first, second).is_empty()


func _validate_save_data(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["format_version", "scenario_path", "scenario_id", "seed", "phase", "tick", "time_scale", "placements", "defense_rules", "player_commands", "expected_snapshot"]:
		if not data.has(key):
			errors.append("Save file is missing field '%s'" % key)
	if not errors.is_empty():
		return errors
	if int(data.format_version) != FORMAT_VERSION:
		errors.append("Unsupported save format version: %s" % data.format_version)
	if not ResourceLoader.exists(String(data.scenario_path)):
		errors.append("Referenced scenario does not exist")
	if int(data.tick) < 0:
		errors.append("Saved tick cannot be negative")
	if not data.placements is Array or not data.defense_rules is Dictionary or not data.player_commands is Array or not data.expected_snapshot is Dictionary:
		errors.append("Save file contains invalid collection fields")
	return errors


func _replace_file_safely(temporary_path: String, final_path: String) -> Error:
	var backup_path := final_path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	var had_existing := FileAccess.file_exists(final_path)
	if had_existing:
		var backup_result := DirAccess.rename_absolute(final_path, backup_path)
		if backup_result != OK:
			return backup_result
	var replace_result := DirAccess.rename_absolute(temporary_path, final_path)
	if replace_result != OK:
		if had_existing:
			DirAccess.rename_absolute(backup_path, final_path)
		return replace_result
	if had_existing:
		DirAccess.remove_absolute(backup_path)
	return OK


func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> String:
	if expected is Dictionary and actual is Dictionary:
		for key in expected:
			if not actual.has(key):
				return "%s.%s (missing)" % [path, key]
			var child_difference := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if not child_difference.is_empty():
				return child_difference
		for key in actual:
			if not expected.has(key):
				return "%s.%s (unexpected)" % [path, key]
		return ""
	if expected is Array and actual is Array:
		if expected.size() != actual.size():
			return "%s.size expected=%d actual=%d" % [path, expected.size(), actual.size()]
		for index in expected.size():
			var child_difference := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if not child_difference.is_empty():
				return child_difference
		return ""
	if expected is float and actual is float and is_equal_approx(expected, actual):
		return ""
	if expected != actual:
		return "%s expected=%s(%s) actual=%s(%s)" % [path, expected, typeof(expected), actual, typeof(actual)]
	return ""
