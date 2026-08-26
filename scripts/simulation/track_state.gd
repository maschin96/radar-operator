class_name TrackState
extends RefCounted

const CLASSIFICATION_UNKNOWN := &"unknown"
const CLASSIFICATION_AIR_CONTACT := &"air_contact"
const CLASSIFICATION_SUSPICIOUS := &"suspicious"
const CLASSIFICATION_HOSTILE := &"hostile"

var id: StringName
var estimated_position: Vector2
var estimated_velocity: Vector2 = Vector2.ZERO
var uncertainty_radius: float
var classification_confidence: float = 0.0
var classification: StringName = CLASSIFICATION_UNKNOWN
var last_measurement_time: float
var last_prediction_time: float
var last_measurement_position: Vector2
var measurement_count: int = 0
var reporting_sensors: Dictionary = {}
var debug_source_entities: Dictionary = {}
var active: bool = true
var last_update_summary: Dictionary = {}


func _init(
	track_id: StringName,
	initial_position: Vector2,
	initial_uncertainty: float,
	initial_time: float
) -> void:
	id = track_id
	estimated_position = initial_position
	uncertainty_radius = initial_uncertainty
	last_measurement_time = initial_time
	last_prediction_time = initial_time
	last_measurement_position = initial_position


func refresh_classification() -> void:
	if classification_confidence >= 0.75:
		classification = CLASSIFICATION_HOSTILE
	elif classification_confidence >= 0.45:
		classification = CLASSIFICATION_SUSPICIOUS
	elif classification_confidence >= 0.20:
		classification = CLASSIFICATION_AIR_CONTACT
	else:
		classification = CLASSIFICATION_UNKNOWN


func to_player_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"estimated_position": {
			"x": estimated_position.x,
			"y": estimated_position.y,
		},
		"estimated_velocity": {
			"x": estimated_velocity.x,
			"y": estimated_velocity.y,
		},
		"uncertainty_radius": uncertainty_radius,
		"classification_confidence": classification_confidence,
		"classification": String(classification),
		"last_measurement_time": last_measurement_time,
		"measurement_count": measurement_count,
		"reporting_sensors": reporting_sensors.keys().map(func(value: Variant) -> String: return String(value)),
		"last_update_summary": last_update_summary.duplicate(true),
	}
