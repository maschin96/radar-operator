class_name SensorMeasurement
extends RefCounted

var id: int
var sensor_id: StringName
var measured_position: Vector2
var position_error_radius: float
var timestamp: float
var classification_evidence: float
var debug_source_entity_id: StringName


func _init(
	measurement_id: int,
	measurement_sensor_id: StringName,
	position: Vector2,
	error_radius: float,
	measurement_timestamp: float,
	classification: float,
	source_entity_id: StringName
) -> void:
	id = measurement_id
	sensor_id = measurement_sensor_id
	measured_position = position
	position_error_radius = error_radius
	timestamp = measurement_timestamp
	classification_evidence = classification
	debug_source_entity_id = source_entity_id


func to_player_dictionary() -> Dictionary:
	return {
		"id": id,
		"sensor_id": String(sensor_id),
		"measured_position": {
			"x": measured_position.x,
			"y": measured_position.y,
		},
		"position_error_radius": position_error_radius,
		"timestamp": timestamp,
		"classification_evidence": classification_evidence,
	}
