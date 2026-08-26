class_name TrackFusionSystem
extends RefCounted

signal track_created(track: TrackState)
signal track_updated(track: TrackState)
signal track_lost(track_id: StringName)

const MINIMUM_ASSOCIATION_GATE := 45.0
const MINIMUM_UNCERTAINTY := 4.0
const UNCERTAINTY_GROWTH_PER_SECOND := 18.0
const TRACK_STALE_TIMEOUT := 12.0
const TIME_EPSILON := 0.000000001

var _tracks: Dictionary = {}
var _next_track_number: int = 1
var _last_process_time: float = 0.0
var _event_time: float = 0.0
var _events: Array[Dictionary] = []


func reset() -> void:
	_tracks.clear()
	_next_track_number = 1
	_last_process_time = 0.0
	_events.clear()


func process_measurements(measurements: Array, current_time: float) -> Array[Dictionary]:
	if current_time + TIME_EPSILON < _last_process_time:
		push_warning("Track fusion cannot move backwards in time")
		return []
	var event_start := _events.size()
	_event_time = current_time
	_predict_tracks(current_time)

	var sorted_measurements := measurements.duplicate()
	sorted_measurements.sort_custom(
		func(a: SensorMeasurement, b: SensorMeasurement) -> bool:
			if not is_equal_approx(a.timestamp, b.timestamp):
				return a.timestamp < b.timestamp
			return a.id < b.id
	)
	var accepted_scan_keys: Dictionary = {}
	for measurement in sorted_measurements:
		var track := _find_best_track(measurement, accepted_scan_keys)
		if track == null:
			track = _create_track(measurement)
		else:
			_update_track(track, measurement)
		var scan_key := _measurement_scan_key(measurement)
		if not accepted_scan_keys.has(track.id):
			accepted_scan_keys[track.id] = {}
		accepted_scan_keys[track.id][scan_key] = true

	_remove_stale_tracks(current_time)
	_last_process_time = current_time
	return _events.slice(event_start)


func get_active_tracks() -> Array[TrackState]:
	var result: Array[TrackState] = []
	var ids: Array = _tracks.keys()
	ids.sort()
	for track_id in ids:
		result.append(_tracks[track_id])
	return result


func get_track(track_id: StringName) -> TrackState:
	return _tracks.get(track_id) as TrackState


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func remove_track(track_id: StringName, current_time: float, reason: StringName = &"removed") -> bool:
	if not _tracks.has(track_id):
		return false
	_event_time = current_time
	var track := _tracks[track_id] as TrackState
	track.active = false
	_tracks.erase(track_id)
	track.last_update_summary = {"result": String(reason)}
	_record_event(&"track_lost", track)
	track_lost.emit(track_id)
	return true


func _predict_tracks(current_time: float) -> void:
	for track in _tracks.values():
		var delta := maxf(current_time - track.last_prediction_time, 0.0)
		if delta <= 0.0:
			continue
		track.estimated_position += track.estimated_velocity * delta
		track.uncertainty_radius += UNCERTAINTY_GROWTH_PER_SECOND * delta
		track.last_prediction_time = current_time


func _find_best_track(measurement: SensorMeasurement, accepted_scan_keys: Dictionary) -> TrackState:
	var best_track: TrackState
	var best_distance := INF
	var scan_key := _measurement_scan_key(measurement)
	var ids: Array = _tracks.keys()
	ids.sort()
	for track_id in ids:
		var track := _tracks[track_id] as TrackState
		if accepted_scan_keys.has(track.id) and accepted_scan_keys[track.id].has(scan_key):
			continue
		var distance := track.estimated_position.distance_to(measurement.measured_position)
		var association_gate := maxf(
			MINIMUM_ASSOCIATION_GATE,
			track.uncertainty_radius + measurement.position_error_radius
		)
		if distance <= association_gate and distance < best_distance:
			best_distance = distance
			best_track = track
	return best_track


func _create_track(measurement: SensorMeasurement) -> TrackState:
	var track_id := StringName("T%04d" % _next_track_number)
	_next_track_number += 1
	var track := TrackState.new(
		track_id,
		measurement.measured_position,
		maxf(measurement.position_error_radius, MINIMUM_UNCERTAINTY),
		measurement.timestamp
	)
	track.measurement_count = 1
	track.reporting_sensors[measurement.sensor_id] = true
	track.debug_source_entities[measurement.debug_source_entity_id] = true
	track.classification_confidence = measurement.classification_evidence * 0.65
	track.refresh_classification()
	track.last_update_summary = {
		"measurement_id": measurement.id,
		"sensor_id": String(measurement.sensor_id),
		"residual": 0.0,
		"uncertainty_before": track.uncertainty_radius,
		"uncertainty_after": track.uncertainty_radius,
		"result": "created",
	}
	_tracks[track.id] = track
	_record_event(&"track_created", track)
	track_created.emit(track)
	return track


func _update_track(track: TrackState, measurement: SensorMeasurement) -> void:
	var residual := track.estimated_position.distance_to(measurement.measured_position)
	var uncertainty_before := track.uncertainty_radius
	var track_variance := maxf(track.uncertainty_radius * track.uncertainty_radius, 1.0)
	var measurement_variance := maxf(measurement.position_error_radius * measurement.position_error_radius, 1.0)
	var measurement_weight := track_variance / (track_variance + measurement_variance)
	var updated_position := track.estimated_position.lerp(measurement.measured_position, measurement_weight)
	var observation_delta := measurement.timestamp - track.last_measurement_time
	if observation_delta > TIME_EPSILON:
		var observed_velocity := (measurement.measured_position - track.last_measurement_position) / observation_delta
		track.estimated_velocity = track.estimated_velocity.lerp(observed_velocity, 0.55)
	track.estimated_position = updated_position
	track.last_measurement_position = measurement.measured_position
	track.last_measurement_time = maxf(track.last_measurement_time, measurement.timestamp)
	track.last_prediction_time = maxf(track.last_prediction_time, measurement.timestamp)
	track.uncertainty_radius = maxf(
		MINIMUM_UNCERTAINTY,
		sqrt(1.0 / (1.0 / track_variance + 1.0 / measurement_variance))
	)
	track.measurement_count += 1
	track.reporting_sensors[measurement.sensor_id] = true
	track.debug_source_entities[measurement.debug_source_entity_id] = true
	track.classification_confidence = 1.0 - (
		1.0 - track.classification_confidence
	) * (1.0 - measurement.classification_evidence * 0.65)
	track.refresh_classification()
	track.last_update_summary = {
		"measurement_id": measurement.id,
		"sensor_id": String(measurement.sensor_id),
		"residual": residual,
		"uncertainty_before": uncertainty_before,
		"uncertainty_after": track.uncertainty_radius,
		"result": "fused",
	}
	_record_event(&"track_updated", track)
	track_updated.emit(track)


func _remove_stale_tracks(current_time: float) -> void:
	var lost_ids: Array[StringName] = []
	for track in _tracks.values():
		if current_time - track.last_measurement_time > TRACK_STALE_TIMEOUT:
			lost_ids.append(track.id)
	lost_ids.sort()
	for track_id in lost_ids:
		var track := _tracks[track_id] as TrackState
		track.active = false
		_tracks.erase(track_id)
		_record_event(&"track_lost", track)
		track_lost.emit(track_id)


func _measurement_scan_key(measurement: SensorMeasurement) -> String:
	return "%s@%.6f" % [measurement.sensor_id, measurement.timestamp]


func _record_event(type: StringName, track: TrackState) -> void:
	_events.append({
		"type": type,
		"track_id": track.id,
		"simulation_time": _event_time,
		"position": track.estimated_position,
		"uncertainty": track.uncertainty_radius,
		"classification": track.classification,
		"source_entities": track.debug_source_entities.keys(),
	})
