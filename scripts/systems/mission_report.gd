class_name MissionReport
extends RefCounted

var _events: Array[Dictionary] = []
var _replay_frames: Array[Dictionary] = []
var _infrastructure: Array = []
var _scenario_id: StringName
var _seed: int


func build(
	scenario: ScenarioDefinition,
	events: Array[Dictionary],
	replay_frames: Array[Dictionary],
	infrastructure: Array
) -> void:
	_scenario_id = scenario.scenario_id
	_seed = scenario.seed
	_events = events.duplicate(true)
	_replay_frames = replay_frames.duplicate(true)
	_infrastructure = infrastructure.duplicate()


func get_metrics() -> Dictionary:
	var metrics := {
		"threats_entered": 0,
		"threats_neutralized": 0,
		"targets_reached": 0,
		"tracks_created": 0,
		"engagements_succeeded": 0,
		"engagements_failed": 0,
		"infrastructure_hits": 0,
		"infrastructure_survived": 0,
		"infrastructure_destroyed": 0,
	}
	for event in _events:
		match StringName(event.type):
			&"threat_entered": metrics.threats_entered += 1
			&"threat_neutralized": metrics.threats_neutralized += 1
			&"threat_target_reached": metrics.targets_reached += 1
			&"track_created": metrics.tracks_created += 1
			&"engagement_succeeded": metrics.engagements_succeeded += 1
			&"engagement_failed": metrics.engagements_failed += 1
			&"infrastructure_damaged": metrics.infrastructure_hits += 1
	for state in _infrastructure:
		if state.status == InfrastructureState.Status.DESTROYED:
			metrics.infrastructure_destroyed += 1
		else:
			metrics.infrastructure_survived += 1
	return metrics


func filter_events(filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events:
		if filters.has("category") and StringName(event.category) != StringName(filters.category):
			continue
		if filters.has("type") and StringName(event.type) != StringName(filters.type):
			continue
		if filters.has("object_id") and not _variant_contains(event, str(filters.object_id)):
			continue
		result.append(event.duplicate(true))
	return result


func build_causal_chain(damage_event_index: int) -> Array[Dictionary]:
	var damage_event := _find_event_by_index(damage_event_index)
	if damage_event.is_empty() or StringName(damage_event.type) != &"infrastructure_damaged":
		return []
	var threat_id := StringName(_find_nested_value(damage_event, "threat_id"))
	var target_id := StringName(_find_nested_value(damage_event, "target_id"))
	var related_track_ids: Dictionary = {}
	for event in _events:
		if int(event.index) > damage_event_index:
			continue
		if StringName(event.category) == &"fusion" and _variant_contains(event, str(threat_id)):
			var track_id := StringName(_find_nested_value(event, "track_id"))
			if not track_id.is_empty():
				related_track_ids[track_id] = true
	var chain: Array[Dictionary] = []
	for event in _events:
		if int(event.index) > damage_event_index:
			continue
		var related := _variant_contains(event, str(threat_id)) or _variant_contains(event, str(target_id))
		if not related:
			for track_id in related_track_ids:
				if _variant_contains(event, str(track_id)):
					related = true
					break
		if related:
			chain.append(event.duplicate(true))
	return chain


func get_replay_frames() -> Array[Dictionary]:
	return _replay_frames.duplicate(true)


func get_replay_frame_near(simulation_time: float) -> Dictionary:
	var best: Dictionary = {}
	for frame in _replay_frames:
		if float(frame.simulation_time) <= simulation_time:
			best = frame
		else:
			break
	return best.duplicate(true)


func get_restart_configuration(same_seed: bool) -> Dictionary:
	return {"scenario_id": _scenario_id, "seed": _seed if same_seed else _seed + 1}


func _find_event_by_index(index: int) -> Dictionary:
	for event in _events:
		if int(event.index) == index:
			return event
	return {}


func _variant_contains(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for child in value.values():
			if _variant_contains(child, needle):
				return true
		return false
	if value is Array:
		for child in value:
			if _variant_contains(child, needle):
				return true
		return false
	return str(value) == needle


func _find_nested_value(value: Variant, key: String) -> Variant:
	if value is Dictionary:
		if value.has(key):
			return value[key]
		for child in value.values():
			var found: Variant = _find_nested_value(child, key)
			if found != null:
				return found
	return null
