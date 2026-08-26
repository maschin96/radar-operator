class_name SensorDefinition
extends EntityDefinition

@export var detection_range: float = 300.0
@export var update_interval: float = 1.0
@export_range(0.0, 1.0) var classification_strength: float = 0.25
@export var position_error: float = 30.0
@export_range(0.0, 1.0) var resistance: float = 0.5
@export var power_demand: float = 10.0
@export var mobile: bool = false


func _init() -> void:
	category = Category.SENSOR


func get_validation_errors() -> Array[String]:
	var errors := super.get_validation_errors()
	if detection_range <= 0.0:
		errors.append("Sensor '%s' has no detection range" % id)
	if update_interval <= 0.0:
		errors.append("Sensor '%s' has an invalid update interval" % id)
	if position_error < 0.0:
		errors.append("Sensor '%s' has a negative position error" % id)
	if power_demand < 0.0:
		errors.append("Sensor '%s' has a negative power demand" % id)
	return errors
