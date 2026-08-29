class_name DefenseSystem
extends RefCounted

signal target_assigned(defense_id: StringName, track_id: StringName)
signal engagement_resolved(event: Dictionary)
signal track_neutralized(track_id: StringName)

const CLASSIFICATION_RANK := {
	&"unknown": 0,
	&"air_contact": 1,
	&"suspicious": 2,
	&"hostile": 3,
}

var _definitions: Dictionary = {}
var _infrastructure_definitions: Dictionary = {}
var _infrastructure: Array = []
var _defenses: Dictionary = {}
var _events: Array[Dictionary] = []
var _neutralized_tracks: Dictionary = {}
var _manual_authorizations: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _rules: Dictionary = EngagementRuleProfile.new().to_dictionary()


static func reason_text(reason: String) -> String:
	return {
		"": "Einsatz möglich",
		"track_not_found": "Track nicht mehr verfügbar",
		"system_offline": "System nicht einsatzbereit",
		"ammunition_empty": "Keine Munition",
		"system_reloading": "System lädt nach",
		"system_busy": "System verfolgt einen anderen Track",
		"out_of_range": "Außerhalb der Einsatzreichweite",
		"classification_too_low": "Klassifikation unter der Mindestanforderung",
		"track_blocked": "Track manuell gesperrt",
		"authorization_required": "Manuelle Freigabe fehlt",
		"redundant_engagement": "Track bereits einem System zugewiesen",
		"no_eligible_system": "Kein einsatzbereites System vorhanden",
		"mission_not_running": "Mission läuft nicht",
		"no_tracks": "Keine aktiven Tracks",
		"no_eligible_track": "Kein Track erfüllt alle Einsatzregeln",
		"selected": "Höchste Bewertung, bei Gleichstand stabile Trackreihenfolge",
		"lower_score_or_stable_tie": "Niedrigere Bewertung oder stabiler Gleichstand",
		"invalid_priority": "Ungültige Prioritätsstufe",
		"invalid_release_status": "Ungültiger Freigabestatus",
	}.get(reason, reason)


static func describe_decision(decision: Dictionary) -> String:
	if decision.is_empty():
		return "Noch keine Zielentscheidung."
	var text: String = {"assigned": "Zuweisung", "cancelled": "Abbruch", "maintained": "Zuweisung bleibt bestehen", "no_valid_track": "Keine Zuweisung"}.get(decision.get("result", ""), "Entscheidung") + "\n"
	if decision.has("rules"):
		text += "Profil: %s\n" % decision.rules.display_name
	if decision.has("track_id"):
		text += "Track: %s\n" % decision.track_id
	text += reason_text(String(decision.get("reason", "selected")))
	if decision.has("total_score"):
		text += "\nBewertung %.1f = Klassifikation %.1f + Schutz %.1f + Erfolg %.1f + Priorität %.1f − Doppelbelegung %.1f" % [decision.total_score, decision.classification_score, decision.urgency_score, decision.success_score, decision.priority_score, decision.duplicate_penalty]
	for candidate in decision.get("candidates", []):
		text += "\n%s: %s" % [candidate.track_id, reason_text(candidate.reason)]
	return text


func configure(scenario: ScenarioDefinition, infrastructure: Array = []) -> void:
	_definitions.clear()
	_infrastructure_definitions.clear()
	_defenses.clear()
	_events.clear()
	_neutralized_tracks.clear()
	_manual_authorizations.clear()
	_infrastructure = infrastructure.duplicate()
	_rules = EngagementRuleProfile.new().to_dictionary()
	if scenario.engagement_profile != null:
		set_rules(scenario.engagement_profile.to_dictionary())
	_random.seed = scenario.seed ^ 0xD3F3A5
	for definition in scenario.definitions:
		if definition is DefenseDefinition:
			_definitions[definition.id] = definition
		elif definition is InfrastructureDefinition:
			_infrastructure_definitions[definition.id] = definition


func add_defense(entity: EntityState) -> DefenseState:
	if not _definitions.has(entity.definition_id):
		push_warning("Unknown defense definition: %s" % entity.definition_id)
		return null
	var definition := _definitions[entity.definition_id] as DefenseDefinition
	var defense := DefenseState.new(entity.id, entity.definition_id, entity.position, definition.ammunition)
	_defenses[defense.id] = defense
	return defense


func set_rules(rules: Dictionary) -> Dictionary:
	var merged := _rules.duplicate(true)
	for key in rules:
		if not _rules.has(key):
			return {"success": false, "errors": ["Unbekannte Einsatzregel '%s'." % key]}
		merged[key] = rules[key]
	var errors := validate_rules(merged)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	_rules = merged.duplicate(true)
	return {"success": true, "rules": get_rules()}


func validate_rules(rules: Dictionary) -> Array[String]:
	var errors := EngagementRuleProfile.validate_data(rules)
	if rules.get("infrastructure_priorities") is Dictionary:
		for id in rules.infrastructure_priorities:
			var found := false
			for entity in _infrastructure:
				found = found or String(entity.id) == String(id)
			if not found:
				errors.append("Unbekannte Infrastruktur '%s'." % id)
	return errors


func get_rules() -> Dictionary:
	return _rules.duplicate(true)


func authorize_track(track_id: StringName) -> void:
	_manual_authorizations[track_id] = true


func revoke_track_authorization(track_id: StringName) -> void:
	_manual_authorizations.erase(track_id)


func get_track_eligibility(track: TrackState, manual_release: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for defense in get_defenses():
		var reason := _assignment_rejection(defense, _definitions[defense.definition_id], track, _current_assignment_counts(), manual_release)
		result.append({"defense_id": String(defense.id), "eligible": reason.is_empty(), "reason": reason})
	return result


func process_tick(delta: float, simulation_time: float, tracks: Array) -> void:
	var tracks_by_id: Dictionary = {}
	for track in tracks:
		if track.active and not _neutralized_tracks.has(track.id):
			tracks_by_id[track.id] = track
	var assigned_counts := _current_assignment_counts()
	var defense_ids: Array = _defenses.keys()
	defense_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for defense_id in defense_ids:
		var defense := _defenses[defense_id] as DefenseState
		_update_defense(defense, delta, simulation_time, tracks_by_id, assigned_counts)


func get_defenses() -> Array[DefenseState]:
	var result: Array[DefenseState] = []
	for defense in _defenses.values():
		result.append(defense)
	result.sort_custom(func(a: DefenseState, b: DefenseState) -> bool: return String(a.id) < String(b.id))
	return result


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func is_track_neutralized(track_id: StringName) -> bool:
	return _neutralized_tracks.has(track_id)


func _update_defense(
	defense: DefenseState,
	delta: float,
	simulation_time: float,
	tracks_by_id: Dictionary,
	assigned_counts: Dictionary
) -> void:
	if not defense.active or not defense.operational or not defense.powered:
		if not defense.assigned_track_id.is_empty():
			_cancel_assignment(defense, assigned_counts, simulation_time, "system_offline")
		defense.status = DefenseState.Status.OFFLINE
		return
	var definition := _definitions[defense.definition_id] as DefenseDefinition
	match defense.status:
		DefenseState.Status.OFFLINE:
			defense.status = DefenseState.Status.READY if defense.ammunition > 0 else DefenseState.Status.DEPLETED
		DefenseState.Status.RELOADING:
			defense.reload_remaining = maxf(defense.reload_remaining - delta, 0.0)
			if defense.reload_remaining <= 0.0:
				defense.status = DefenseState.Status.READY if defense.ammunition > 0 else DefenseState.Status.DEPLETED
		DefenseState.Status.TRACKING:
			if not tracks_by_id.has(defense.assigned_track_id):
				_cancel_assignment(defense, assigned_counts, simulation_time, "track_not_found")
				return
			var track := tracks_by_id[defense.assigned_track_id] as TrackState
			var reason := _assignment_rejection(defense, definition, track, assigned_counts)
			if not reason.is_empty():
				_cancel_assignment(defense, assigned_counts, simulation_time, reason)
				return
			defense.tracking_remaining = maxf(defense.tracking_remaining - delta, 0.0)
			if defense.tracking_remaining <= 0.0:
				_resolve_engagement(defense, definition, track, simulation_time, assigned_counts)
		DefenseState.Status.READY:
			_assign_best_track(defense, definition, tracks_by_id, assigned_counts, simulation_time)
		DefenseState.Status.DEPLETED:
			pass


func _assign_best_track(
	defense: DefenseState,
	definition: DefenseDefinition,
	tracks_by_id: Dictionary,
	assigned_counts: Dictionary,
	simulation_time: float
) -> void:
	var decision := _evaluate_assignment(defense, definition, tracks_by_id, assigned_counts)
	var previous := defense.last_decision
	defense.last_decision = decision
	if decision.result == "no_valid_track":
		# Repeated idle ticks must not flood the event log.
		if previous.get("result") != decision.result or previous.get("candidates") != decision.candidates or previous.get("rules") != decision.rules:
			_record_event(&"assignment_declined", defense, &"", simulation_time, decision)
		return
	defense.assigned_track_id = StringName(decision.track_id)
	defense.tracking_remaining = definition.tracking_time
	defense.status = DefenseState.Status.TRACKING
	assigned_counts[defense.assigned_track_id] = int(assigned_counts.get(defense.assigned_track_id, 0)) + 1
	_record_event(&"target_assigned", defense, defense.assigned_track_id, simulation_time, decision)
	target_assigned.emit(defense.id, defense.assigned_track_id)


func _evaluate_assignment(defense: DefenseState, definition: DefenseDefinition, tracks: Dictionary, counts: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var candidates: Array[Dictionary] = []
	var ids := tracks.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var track: TrackState = tracks[id]
		var reason := _assignment_rejection(defense, definition, track, counts)
		var candidate := {"track_id": String(id), "reason": reason, "eligible": reason.is_empty()}
		if reason.is_empty():
			candidate.merge(_score_track(defense, definition, track, int(counts.get(id, 0))))
			if best.is_empty() or float(candidate.total_score) > float(best.total_score) + 0.000001:
				best = candidate.duplicate(true)
		candidates.append(candidate)
	var decision := best.duplicate(true) if not best.is_empty() else {"result": "no_valid_track", "reason": "no_eligible_track" if not candidates.is_empty() else "no_tracks"}
	for candidate in candidates:
		if candidate.eligible:
			candidate.reason = "selected" if candidate.track_id == best.track_id else "lower_score_or_stable_tie"
	decision["candidates"] = candidates
	decision["rules"] = get_rules()
	return decision


func preview_rules(rules: Dictionary, tracks: Array) -> Dictionary:
	var errors := validate_rules(rules)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	# Separate evaluator shares read-only inputs, never advances a tick or RNG.
	var evaluator := DefenseSystem.new()
	evaluator._rules = rules.duplicate(true)
	evaluator._infrastructure = _infrastructure
	evaluator._definitions = _definitions
	evaluator._infrastructure_definitions = _infrastructure_definitions
	evaluator._manual_authorizations = _manual_authorizations
	evaluator._neutralized_tracks = _neutralized_tracks
	var tracks_by_id: Dictionary = {}
	for track in tracks:
		if track.active and not _neutralized_tracks.has(track.id):
			tracks_by_id[track.id] = track
	var counts := _current_assignment_counts()
	var decisions: Array[Dictionary] = []
	for defense in get_defenses():
		var decision: Dictionary
		if defense.status == DefenseState.Status.TRACKING:
			var track: TrackState = tracks_by_id.get(defense.assigned_track_id)
			var reason := "track_not_found" if track == null else evaluator._assignment_rejection(defense, _definitions[defense.definition_id], track, counts)
			decision = {"result": "maintained" if reason.is_empty() else "cancelled", "reason": reason, "track_id": String(defense.assigned_track_id), "rules": rules.duplicate(true)}
			if not reason.is_empty():
				_decrement_assignment(counts, defense.assigned_track_id)
		else:
			decision = evaluator._evaluate_assignment(defense, _definitions[defense.definition_id], tracks_by_id, counts)
			if decision.result == "assigned":
				var id := StringName(decision.track_id)
				counts[id] = int(counts.get(id, 0)) + 1
		decisions.append({"defense_id": String(defense.id), "decision": decision})
	return {"success": true, "decisions": decisions}


func _assignment_rejection(
	defense: DefenseState, definition: DefenseDefinition, track: TrackState,
	assigned_counts: Dictionary, manual_release: bool = false
) -> String:
	if not track.active or _neutralized_tracks.has(track.id):
		return "track_not_found"
	if not defense.active or not defense.operational or not defense.powered or defense.status == DefenseState.Status.OFFLINE:
		return "system_offline"
	if defense.ammunition <= 0:
		return "ammunition_empty"
	if defense.status == DefenseState.Status.RELOADING:
		return "system_reloading"
	if defense.status == DefenseState.Status.TRACKING and defense.assigned_track_id != track.id:
		return "system_busy"
	if not _is_track_in_envelope(defense, definition, track):
		return "out_of_range"
	var minimum_rank: int = int(CLASSIFICATION_RANK.get(_rules.minimum_classification, 2))
	if int(CLASSIFICATION_RANK.get(track.classification, 0)) < minimum_rank:
		return "classification_too_low"
	if not manual_release:
		if track.release_status == TrackState.ReleaseStatus.BLOCKED:
			return "track_blocked"
		if not bool(_rules.automatic_release) and not _manual_authorizations.has(track.id):
			return "authorization_required"
	# An existing assignment does not compete against itself.
	if defense.assigned_track_id == track.id:
		return ""
	var assignment_count := int(assigned_counts.get(track.id, 0))
	if assignment_count == 0 or bool(_rules.allow_redundant_engagement):
		return ""
	return "redundant_engagement"


func _cancel_assignment(defense: DefenseState, counts: Dictionary, time: float, reason: String) -> void:
	defense.last_decision = {"result": "cancelled", "track_id": String(defense.assigned_track_id), "reason": reason, "rules": get_rules()}
	_record_event(&"assignment_lost", defense, defense.assigned_track_id, time, defense.last_decision)
	_decrement_assignment(counts, defense.assigned_track_id)
	defense.assigned_track_id = &""
	defense.tracking_remaining = 0.0
	defense.status = DefenseState.Status.READY if defense.ammunition > 0 else DefenseState.Status.DEPLETED


func _is_track_in_envelope(defense: DefenseState, definition: DefenseDefinition, track: TrackState) -> bool:
	var distance := defense.position.distance_to(track.estimated_position)
	return distance >= definition.minimum_range and distance <= definition.engagement_range


func _score_track(
	defense: DefenseState,
	definition: DefenseDefinition,
	track: TrackState,
	assignment_count: int
) -> Dictionary:
	var threat_info := _estimate_infrastructure_threat(track)
	var classification_score := track.classification_confidence * 40.0
	var urgency_score := float(threat_info.protection_value) * 35.0 / (1.0 + float(threat_info.time_to_impact) / 10.0)
	var success_chance := _success_chance(defense, definition, track)
	var success_score := success_chance * 20.0
	var duplicate_penalty := assignment_count * 25.0
	var priority_score: float = [0.0, 35.0, 80.0][track.priority]
	return {
		"result": "assigned",
		"track_id": String(track.id),
		"classification_score": classification_score,
		"urgency_score": urgency_score,
		"success_chance": success_chance,
		"success_score": success_score,
		"duplicate_penalty": duplicate_penalty,
		"priority_score": priority_score,
		"threatened_infrastructure_id": String(threat_info.infrastructure_id),
		"time_to_impact": threat_info.time_to_impact,
		"total_score": classification_score + urgency_score + success_score + priority_score - duplicate_penalty,
	}


func _estimate_infrastructure_threat(track: TrackState) -> Dictionary:
	var best_time := INF
	var best_value := 1.0
	var best_id: StringName
	var speed := maxf(track.estimated_velocity.length(), 1.0)
	for entity in _infrastructure:
		if not entity.active:
			continue
		var time := track.estimated_position.distance_to(entity.position) / speed
		var definition := _infrastructure_definitions.get(entity.definition_id) as InfrastructureDefinition
		var value := definition.protection_value if definition != null else 1.0
		value *= float((_rules.infrastructure_priorities as Dictionary).get(String(entity.id), 1.0))
		var weighted_time := time / maxf(value, 0.1)
		if weighted_time < best_time:
			best_time = weighted_time
			best_value = value
			best_id = entity.id
	return {
		"infrastructure_id": best_id,
		"time_to_impact": best_time if best_time < INF else 9999.0,
		"protection_value": best_value,
	}


func _success_chance(defense: DefenseState, definition: DefenseDefinition, track: TrackState) -> float:
	var uncertainty_penalty := clampf(track.uncertainty_radius / definition.engagement_range, 0.0, 1.0) * 0.25
	return clampf(definition.base_success_chance - uncertainty_penalty, 0.05, 0.95)


func _resolve_engagement(
	defense: DefenseState,
	definition: DefenseDefinition,
	track: TrackState,
	simulation_time: float,
	assigned_counts: Dictionary
) -> void:
	defense.ammunition -= 1
	var chance := _success_chance(defense, definition, track)
	var succeeded := _random.randf() <= chance
	var event := _record_event(
		&"engagement_succeeded" if succeeded else &"engagement_failed",
		defense,
		track.id,
		simulation_time,
		{"success_chance": chance, "ammunition_remaining": defense.ammunition}
	)
	if succeeded:
		_neutralized_tracks[track.id] = true
		track_neutralized.emit(track.id)
	_decrement_assignment(assigned_counts, track.id)
	defense.assigned_track_id = &""
	if defense.ammunition <= 0:
		defense.status = DefenseState.Status.DEPLETED
	else:
		defense.status = DefenseState.Status.RELOADING
		defense.reload_remaining = definition.reload_time
	engagement_resolved.emit(event)


func _current_assignment_counts() -> Dictionary:
	var result: Dictionary = {}
	for defense in _defenses.values():
		if defense.status == DefenseState.Status.TRACKING and not defense.assigned_track_id.is_empty():
			result[defense.assigned_track_id] = int(result.get(defense.assigned_track_id, 0)) + 1
	return result


func _decrement_assignment(counts: Dictionary, track_id: StringName) -> void:
	counts[track_id] = maxi(int(counts.get(track_id, 0)) - 1, 0)


func _record_event(
	type: StringName,
	defense: DefenseState,
	track_id: StringName,
	simulation_time: float,
	data: Dictionary = {}
) -> Dictionary:
	var event := {
		"type": type,
		"defense_id": defense.id,
		"track_id": track_id,
		"simulation_time": simulation_time,
		"data": data.duplicate(true),
	}
	_events.append(event)
	return event
