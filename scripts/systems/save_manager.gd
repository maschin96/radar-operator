class_name SaveManager
extends RefCounted

const FORMAT_VERSION := 6


func save_session(session: GameSession, path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var existing := load_session(path)
		if not existing.success:
			return {"success": false, "errors": existing.errors + ["Originaldatei bleibt erhalten. Datei sichern und umbenennen oder eine passende Spielversion verwenden."]}
	var snapshot := session.get_persistence_snapshot()
	var data := {
		"format_version": FORMAT_VERSION,
		"scenario_content_version": session.scenario.content_version,
		"scenario_path": session.scenario_source_path,
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
	var migrated := migrate(json.data)
	if not migrated.success:
		return migrated
	var data: Dictionary = migrated.data
	var errors := _validate_save_data(data)
	if not errors.is_empty():
		return {"success": false, "errors": errors}

	var content := ScenarioLoader.new().load_scenario(data.scenario_path)
	if not content.success:
		return content
	var scenario: ScenarioDefinition = content.scenario
	if String(scenario.scenario_id) != data.scenario_id or scenario.content_version != data.scenario_content_version:
		return {"success": false, "errors": ["Spielstand und Szenarioinhalt sind nicht kompatibel."]}
	if data.tick > ceili(scenario.mission_duration / GameSession.TICK_DURATION) + 1:
		return {"success": false, "errors": ["Spielstand überschreitet die Missionsdauer."]}
	scenario = scenario.duplicate(true)
	scenario.seed = int(data.seed)
	var session := GameSession.new()
	session.initialize(scenario)
	session.scenario_source_path = data.scenario_path
	var saved_placements: Array = data.placements.duplicate(true)
	saved_placements.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("id", "")) < String(right.get("id", ""))
	)
	for placement_data in saved_placements:
		var position_data: Dictionary = placement_data.get("initial_position", placement_data.position)
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
	_normalize_snapshot_order(data.expected_snapshot)
	_normalize_snapshot_order(actual_snapshot)
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
	for key in ["format_version", "scenario_path", "scenario_id", "seed", "phase", "tick", "time_scale", "placements", "defense_rules", "player_commands", "expected_snapshot", "scenario_content_version"]:
		if not data.has(key):
			errors.append("Save file is missing field '%s'" % key)
	if not errors.is_empty():
		return errors
	var numeric := SettingsManager.new()
	for key in ["format_version", "scenario_content_version", "seed", "phase", "tick"]:
		if not numeric._is_integer(data[key]):
			errors.append("Save field '%s' must be an integer" % key)
	if not errors.is_empty():
		return errors
	if data.format_version != FORMAT_VERSION:
		errors.append("Unsupported save format version: %s" % str(data.format_version))
	if not data.scenario_path is String or not data.scenario_path.begins_with("res://data/") or not ResourceLoader.exists(data.scenario_path):
		errors.append("Referenced scenario does not exist")
	if not data.scenario_id is String or data.scenario_id.is_empty():
		errors.append("Invalid scenario id")
	if data.tick < 0 or data.tick > 144000 or not [0, 1, 2].has(int(data.phase)):
		errors.append("Invalid mission tick or phase")
	if not numeric._is_number(data.time_scale) or not [0.0, 1.0, 2.0, 4.0].has(float(data.time_scale)):
		errors.append("Invalid simulation speed")
	if not data.placements is Array or not data.defense_rules is Dictionary or not data.player_commands is Array or not data.expected_snapshot is Dictionary:
		errors.append("Save file contains invalid collection fields")
		return errors
	for placement in data.placements:
		if not placement is Dictionary or not placement.get("id") is String or not placement.get("definition_id") is String or not _valid_position(placement.get("position")) or not _valid_position(placement.get("initial_position", placement.get("position"))):
			errors.append("Invalid saved placement")
	var last_tick := 0
	for command in data.player_commands:
		if not command is Dictionary or not numeric._is_integer(command.get("tick")) or not command.get("data") is Dictionary or not _valid_command(command):
			errors.append("Invalid player command")
			continue
		if command.tick < last_tick or command.tick > data.tick:
			errors.append("Invalid player command order")
		last_tick = int(command.tick)
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


func migrate(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("format_version")
	if not SettingsManager.new()._is_integer(version) or not [5, FORMAT_VERSION].has(int(version)):
		return {"success": false, "errors": ["Unsupported save format version: %s. Originaldatei bleibt erhalten; passende Spielversion verwenden." % str(version)]}
	var result := data.duplicate(true)
	if int(version) == 5:
		result["scenario_content_version"] = 1
	result["format_version"] = FORMAT_VERSION
	return {"success": true, "data": result}


func _valid_position(value: Variant) -> bool:
	var numeric := SettingsManager.new()
	return value is Dictionary and numeric._is_number(value.get("x")) and numeric._is_number(value.get("y")) and is_finite(float(value.x)) and is_finite(float(value.y))


func _valid_command(command: Dictionary) -> bool:
	var data: Dictionary = command.data
	var numeric := SettingsManager.new()
	match command.get("type"):
		"abort_mission": return true
		"set_track_priority": return data.get("track_id") is String and numeric._is_integer(data.get("priority")) and data.get("reason", "") is String
		"set_track_release": return data.get("track_id") is String and numeric._is_integer(data.get("release_status"))
		"set_defense_rules": return data.get("rules") is Dictionary
		"set_network_connection_enabled": return data.get("connection_id") is String and data.get("enabled") is bool
		"relocate_system": return data.get("entity_id") is String and _valid_position(data.get("target"))
		"cancel_relocation": return data.get("entity_id") is String
	return false


func _normalize_snapshot_order(snapshot: Dictionary) -> void:
	# Entity collections have identity, not meaningful array order. Older saves
	# sorted StringName handles, which can vary between separate processes.
	for key in ["placements", "infrastructure", "tracks", "threats", "sensors", "defenses"]:
		var collection: Variant = snapshot.get(key)
		if not collection is Array:
			continue
		var valid := true
		for item in collection:
			if not item is Dictionary or not item.get("id") is String:
				valid = false
		if valid:
			collection.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
