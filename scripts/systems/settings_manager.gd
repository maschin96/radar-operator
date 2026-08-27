class_name SettingsManager
extends RefCounted

const FORMAT_VERSION := 1
const ACTIONS := [
	"simulation_pause",
	"simulation_speed_1",
	"simulation_speed_2",
	"simulation_speed_4",
	"toggle_briefing",
]

var settings: Dictionary = {}
var draft: Dictionary = {}


func get_defaults() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"window_mode": "windowed",
		"master_volume": 0.8,
		"alerts_volume": 0.8,
		"voice_volume": 0.8,
		"alerts_enabled": true,
		"high_contrast": false,
		"reduced_effects": false,
		"action_bindings": {
			"simulation_pause": KEY_SPACE,
			"simulation_speed_1": KEY_1,
			"simulation_speed_2": KEY_2,
			"simulation_speed_4": KEY_4,
			"toggle_briefing": KEY_B,
		},
	}


func load_or_defaults(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		settings = get_defaults()
		apply(settings)
		return {"success": true, "recovered": false, "settings": settings.duplicate(true)}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _recover_defaults("Einstellungsdatei konnte nicht geöffnet werden.")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return _recover_defaults("Einstellungsdatei ist beschädigt: %s" % json.get_error_message())
	var errors := validate(json.data)
	if not errors.is_empty():
		return _recover_defaults("; ".join(errors))
	settings = (json.data as Dictionary).duplicate(true)
	apply(settings)
	return {"success": true, "recovered": false, "settings": settings.duplicate(true)}


func save(path: String) -> Dictionary:
	var errors := validate(settings)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["Temporäre Einstellungsdatei konnte nicht geöffnet werden."]}
	file.store_string(JSON.stringify(settings, "  "))
	file.flush()
	file.close()
	var replace_error := _replace_file(temporary_path, path)
	if replace_error != OK:
		return {"success": false, "errors": ["Einstellungen konnten nicht sicher gespeichert werden: %s" % error_string(replace_error)]}
	return {"success": true, "path": path}


func begin_edit() -> Dictionary:
	draft = settings.duplicate(true)
	return draft.duplicate(true)


func update_draft(values: Dictionary) -> Dictionary:
	if draft.is_empty():
		begin_edit()
	for key in values:
		draft[key] = values[key]
	var errors := validate(draft)
	return {"success": errors.is_empty(), "errors": errors, "draft": draft.duplicate(true)}


func set_draft_binding(action: StringName, keycode: Key) -> Dictionary:
	if not ACTIONS.has(String(action)):
		return {"success": false, "errors": ["Unbekannte Eingabeaktion '%s'." % action]}
	if draft.is_empty():
		begin_edit()
	var bindings: Dictionary = draft.action_bindings.duplicate()
	bindings[String(action)] = int(keycode)
	var errors := _binding_errors(bindings)
	if not errors.is_empty():
		return {"success": false, "errors": errors, "draft": draft.duplicate(true)}
	draft["action_bindings"] = bindings
	return {"success": true, "errors": [], "draft": draft.duplicate(true)}


func commit_draft(path: String) -> Dictionary:
	var errors := validate(draft)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	settings = draft.duplicate(true)
	apply(settings)
	return save(path)


func cancel_draft() -> Dictionary:
	draft = settings.duplicate(true)
	return draft.duplicate(true)


func reset_draft() -> Dictionary:
	draft = get_defaults()
	return draft.duplicate(true)


func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["format_version", "window_mode", "master_volume", "alerts_volume", "voice_volume", "alerts_enabled", "high_contrast", "reduced_effects", "action_bindings"]:
		if not data.has(key):
			errors.append("Einstellungsdatei enthält das Feld '%s' nicht." % key)
	if not errors.is_empty():
		return errors
	if int(data.format_version) != FORMAT_VERSION:
		errors.append("Nicht unterstützte Einstellungsversion: %s" % data.format_version)
	if not ["windowed", "fullscreen"].has(String(data.window_mode)):
		errors.append("Ungültiger Fenstermodus '%s'." % data.window_mode)
	for volume_key in ["master_volume", "alerts_volume", "voice_volume"]:
		var value := float(data[volume_key])
		if value < 0.0 or value > 1.0:
			errors.append("Lautstärke '%s' liegt außerhalb von 0 bis 1." % volume_key)
	if not data.action_bindings is Dictionary:
		errors.append("Tastenbelegungen sind ungültig.")
	else:
		errors.append_array(_binding_errors(data.action_bindings))
	return errors


func apply(data: Dictionary) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var linear_volume := clampf(float(data.master_volume), 0.0, 1.0)
		AudioServer.set_bus_mute(master_bus, linear_volume <= 0.0)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(linear_volume, 0.0001)))
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.window_mode == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var input_event := InputEventKey.new()
		input_event.physical_keycode = int(data.action_bindings[action]) as Key
		InputMap.action_add_event(action, input_event)


func _binding_errors(bindings: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var assigned: Dictionary = {}
	for action in ACTIONS:
		if not bindings.has(action):
			errors.append("Pflichtaktion '%s' besitzt keine Tastenbelegung." % action)
			continue
		var keycode := int(bindings[action])
		if keycode <= 0:
			errors.append("Pflichtaktion '%s' besitzt keine erreichbare Taste." % action)
		elif assigned.has(keycode):
			errors.append("Tastenkonflikt zwischen '%s' und '%s'." % [assigned[keycode], action])
		else:
			assigned[keycode] = action
	return errors


func _recover_defaults(reason: String) -> Dictionary:
	settings = get_defaults()
	apply(settings)
	return {"success": true, "recovered": true, "warning": reason, "settings": settings.duplicate(true)}


func _replace_file(temporary_path: String, final_path: String) -> Error:
	var backup_path := final_path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	var had_existing := FileAccess.file_exists(final_path)
	if had_existing:
		var backup_error := DirAccess.rename_absolute(final_path, backup_path)
		if backup_error != OK:
			return backup_error
	var replace_error := DirAccess.rename_absolute(temporary_path, final_path)
	if replace_error != OK:
		if had_existing:
			DirAccess.rename_absolute(backup_path, final_path)
		return replace_error
	if had_existing:
		DirAccess.remove_absolute(backup_path)
	return OK
