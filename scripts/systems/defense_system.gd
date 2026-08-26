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
var _rules := {
	"minimum_classification": &"suspicious",
	"automatic_release": true,
	"allow_redundant_engagement": false,
}


func configure(scenario: ScenarioDefinition, infrastructure: Array = []) -> void:
	_definitions.clear()
	_infrastructure_definitions.clear()
	_defenses.clear()
	_events.clear()
	_neutralized_tracks.clear()
	_manual_authorizations.clear()
	_infrastructure = infrastructure.duplicate()
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


func set_rules(rules: Dictionary) -> void:
	for key in rules:
		if _rules.has(key):
			_rules[key] = rules[key]


func get_rules() -> Dictionary:
	return _rules.duplicate(true)


func authorize_track(track_id: StringName) -> void:
	_manual_authorizations[track_id] = true


func process_tick(delta: float, simulation_time: float, tracks: Array) -> void:
	var tracks_by_id: Dictionary = {}
	for track in tracks:
		if track.active and not _neutralized_tracks.has(track.id):
			tracks_by_id[track.id] = track
	var assigned_counts := _current_assignment_counts()
	var defense_ids: Array = _defenses.keys()
	defense_ids.sort()
	for defense_id in defense_ids:
		var defense := _defenses[defense_id] as DefenseState
		_update_defense(defense, delta, simulation_time, tracks_by_id, assigned_counts)


func get_defenses() -> Array[DefenseState]:
	var result: Array[DefenseState] = []
	for defense in _defenses.values():
		result.append(defense)
	result.sort_custom(func(a: DefenseState, b: DefenseState) -> bool: return a.id < b.id)
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
				_record_event(&"assignment_lost", defense, defense.assigned_track_id, simulation_time)
				_decrement_assignment(assigned_counts, defense.assigned_track_id)
				defense.assigned_track_id = &""
				defense.status = DefenseState.Status.READY
				return
			var track := tracks_by_id[defense.assigned_track_id] as TrackState
			if not _is_track_in_envelope(defense, definition, track):
				_record_event(&"assignment_lost", defense, track.id, simulation_time)
				_decrement_assignment(assigned_counts, track.id)
				defense.assigned_track_id = &""
				defense.status = DefenseState.Status.READY
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
	var best_track: TrackState
	var best_score := -INF
	var best_explanation: Dictionary = {}
	var track_ids: Array = tracks_by_id.keys()
	track_ids.sort()
	for track_id in track_ids:
		var track := tracks_by_id[track_id] as TrackState
		if not _can_assign(defense, definition, track, assigned_counts):
			continue
		var explanation := _score_track(defense, definition, track, int(assigned_counts.get(track.id, 0)))
		var score := float(explanation.total_score)
		var is_stable_tie := (
			best_track != null
			and is_equal_approx(score, best_score)
			and String(track.id) < String(best_track.id)
		)
		if best_track == null or score > best_score + 0.000001 or is_stable_tie:
			best_score = score
			best_track = track
			best_explanation = explanation
	if best_track == null:
		defense.last_decision = {"result": "no_valid_track"}
		return
	defense.assigned_track_id = best_track.id
	defense.tracking_remaining = definition.tracking_time
	defense.status = DefenseState.Status.TRACKING
	defense.last_decision = best_explanation
	assigned_counts[best_track.id] = int(assigned_counts.get(best_track.id, 0)) + 1
	_record_event(&"target_assigned", defense, best_track.id, simulation_time, best_explanation)
	target_assigned.emit(defense.id, best_track.id)


func _can_assign(
	defense: DefenseState,
	definition: DefenseDefinition,
	track: TrackState,
	assigned_counts: Dictionary
) -> bool:
	if not _is_track_in_envelope(defense, definition, track):
		return false
	var minimum_rank: int = int(CLASSIFICATION_RANK.get(_rules.minimum_classification, 2))
	if int(CLASSIFICATION_RANK.get(track.classification, 0)) < minimum_rank:
		return false
	if not bool(_rules.automatic_release) and not _manual_authorizations.has(track.id):
		return false
	var assignment_count := int(assigned_counts.get(track.id, 0))
	if assignment_count == 0 or bool(_rules.allow_redundant_engagement):
		return true
	var threat_info := _estimate_infrastructure_threat(track)
	return track.classification == &"hostile" and float(threat_info.time_to_impact) < 5.0


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
	return {
		"result": "assigned",
		"track_id": String(track.id),
		"classification_score": classification_score,
		"urgency_score": urgency_score,
		"success_chance": success_chance,
		"success_score": success_score,
		"duplicate_penalty": duplicate_penalty,
		"threatened_infrastructure_id": String(threat_info.infrastructure_id),
		"time_to_impact": threat_info.time_to_impact,
		"total_score": classification_score + urgency_score + success_score - duplicate_penalty,
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
