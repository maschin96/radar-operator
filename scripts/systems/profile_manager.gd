class_name ProfileManager
extends RefCounted

const FORMAT_VERSION := 2

var profile: Dictionary = {}
var _catalog: Variant


func create_default(catalog: Variant) -> Dictionary:
	_catalog = catalog
	var unlocked: Array[String] = []
	for scenario in catalog.scenarios:
		if scenario.unlock_requires.is_empty():
			unlocked.append(String(scenario.scenario_id))
	profile = {
		"format_version": FORMAT_VERSION,
		"unlocked_missions": unlocked,
		"completed_missions": [],
		"best_results": {},
		"last_played_mission": "",
	}
	return profile.duplicate(true)


func load_or_create(path: String, catalog: Variant) -> Dictionary:
	_catalog = catalog
	if not FileAccess.file_exists(path):
		create_default(catalog)
		return {"success": true, "created": true, "profile": profile.duplicate(true)}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "errors": ["Profil konnte nicht geöffnet werden."]}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return {"success": false, "errors": ["Profildatei ist beschädigt: %s" % json.get_error_message()]}
	var migrated := migrate(json.data, catalog)
	if not migrated.success:
		return migrated
	var errors := _validate(migrated.profile, catalog)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	profile = (migrated.profile as Dictionary).duplicate(true)
	return {"success": true, "created": false, "profile": profile.duplicate(true)}


func save(path: String) -> Dictionary:
	if profile.is_empty():
		return {"success": false, "errors": ["Kein Profil zum Speichern vorhanden."]}
	if FileAccess.file_exists(path):
		var probe := ProfileManager.new()
		var existing := probe.load_or_create(path, _catalog)
		if not existing.success:
			return {"success": false, "errors": existing.errors + [recovery_hint(path)]}
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "errors": ["Temporäre Profildatei konnte nicht geöffnet werden."]}
	file.store_string(JSON.stringify(profile, "  "))
	file.flush()
	file.close()
	var replace_error := _replace_file(temporary_path, path)
	if replace_error != OK:
		return {"success": false, "errors": ["Profil konnte nicht sicher gespeichert werden: %s" % error_string(replace_error)]}
	return {"success": true, "path": path}


func record_mission_result(scenario_id: StringName, status: int, catalog: Variant) -> bool:
	var id_text := String(scenario_id)
	profile["last_played_mission"] = id_text
	var best_results: Dictionary = profile.get("best_results", {})
	var previous_status := int(best_results.get(id_text, -1))
	best_results[id_text] = (
		InfrastructureSystem.MissionStatus.VICTORY
		if previous_status == InfrastructureSystem.MissionStatus.VICTORY or status == InfrastructureSystem.MissionStatus.VICTORY
		else status
	)
	profile["best_results"] = best_results
	if status != InfrastructureSystem.MissionStatus.VICTORY:
		return false
	var completed: Array = profile.get("completed_missions", [])
	if not completed.has(id_text):
		completed.append(id_text)
		completed.sort()
	profile["completed_missions"] = completed
	var unlocked: Array = profile.get("unlocked_missions", [])
	var changed := false
	for scenario in catalog.scenarios:
		var candidate_id := String(scenario.scenario_id)
		if unlocked.has(candidate_id):
			continue
		var requirements_met := true
		for requirement in scenario.unlock_requires:
			if not completed.has(String(requirement)):
				requirements_met = false
				break
		if requirements_met:
			unlocked.append(candidate_id)
			changed = true
	unlocked.sort()
	profile["unlocked_missions"] = unlocked
	return changed


func is_unlocked(scenario_id: StringName) -> bool:
	return profile.get("unlocked_missions", []).has(String(scenario_id))


func is_completed(scenario_id: StringName) -> bool:
	return profile.get("completed_missions", []).has(String(scenario_id))


func get_mission_result(scenario_id: StringName) -> int:
	return int((profile.get("best_results", {}) as Dictionary).get(String(scenario_id), -1))


func get_campaign_progress(catalog: Variant) -> Dictionary:
	var completed := 0
	for scenario in catalog.scenarios:
		if scenario.is_campaign_mission and is_completed(scenario.scenario_id):
			completed += 1
	return {"completed": completed, "total": catalog.scenarios.filter(func(s: ScenarioDefinition) -> bool: return s.is_campaign_mission).size()}


func get_next_unlocked_scenario(scenario_id: StringName, catalog: Variant) -> ScenarioDefinition:
	var current: ScenarioDefinition = catalog.get_scenario(scenario_id)
	if current == null:
		return null
	for scenario in catalog.scenarios:
		if scenario.is_campaign_mission and scenario.campaign_order > current.campaign_order and is_unlocked(scenario.scenario_id):
			return scenario
	return null


func reset(catalog: Variant, confirmed: bool) -> Dictionary:
	if not confirmed:
		return {"success": false, "errors": ["Zurücksetzen wurde nicht bestätigt."]}
	return {"success": true, "profile": create_default(catalog)}


func _validate(data: Dictionary, _unused_catalog: Variant) -> Array[String]:
	var errors: Array[String] = []
	for key in ["format_version", "unlocked_missions", "completed_missions", "best_results", "last_played_mission"]:
		if not data.has(key):
			errors.append("Profildatei enthält das Feld '%s' nicht." % key)
	if not errors.is_empty():
		return errors
	if not SettingsManager.new()._is_integer(data.format_version) or data.format_version != FORMAT_VERSION:
		errors.append("Nicht unterstützte Profilversion: %s" % str(data.format_version))
	if not data.unlocked_missions is Array or not data.completed_missions is Array or not data.best_results is Dictionary:
		errors.append("Profildatei enthält ungültige Sammlungen.")
		return errors
	for mission_id in data.unlocked_missions + data.completed_missions:
		if not mission_id is String or mission_id.is_empty():
			errors.append("Profildatei enthält eine ungültige Missionskennung.")
	if not data.last_played_mission is String:
		errors.append("Zuletzt gespielte Mission ist ungültig.")
	for id in data.best_results:
		if not id is String or not SettingsManager.new()._is_integer(data.best_results[id]) or not [InfrastructureSystem.MissionStatus.VICTORY, InfrastructureSystem.MissionStatus.DEFEAT].has(int(data.best_results[id])):
			errors.append("Profildatei enthält ein ungültiges Missionsergebnis.")
	return errors


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


func migrate(data: Dictionary, catalog: Variant) -> Dictionary:
	var version: Variant = data.get("format_version")
	if not SettingsManager.new()._is_integer(version) or not [1, FORMAT_VERSION].has(int(version)):
		return {"success": false, "errors": ["Nicht unterstützte Profilversion: %s" % str(version)]}
	var result := data.duplicate(true)
	result["format_version"] = FORMAT_VERSION
	var errors := _validate(result, catalog)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	# Retain unknown mission IDs so removed content never erases progress.
	for scenario in catalog.scenarios:
		var met := true
		for requirement in scenario.unlock_requires:
			if not result.completed_missions.has(String(requirement)):
				met = false
		if met and not result.unlocked_missions.has(String(scenario.scenario_id)):
			result.unlocked_missions.append(String(scenario.scenario_id))
	for id in result.completed_missions:
		if not result.unlocked_missions.has(id):
			result.unlocked_missions.append(id)
		result.best_results[id] = InfrastructureSystem.MissionStatus.VICTORY
	result.unlocked_missions.sort()
	return {"success": true, "profile": result}


func recovery_hint(path: String) -> String:
	return "Die Originaldatei bleibt erhalten. Passende Spielversion verwenden oder '%s' sichern und umbenennen, dann neu starten." % ProjectSettings.globalize_path(path)
