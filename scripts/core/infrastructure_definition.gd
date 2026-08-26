class_name InfrastructureDefinition
extends EntityDefinition

@export var infrastructure_type: StringName = &"generic"
@export var maximum_integrity: float = 100.0
@export var protection_value: float = 1.0
@export var power_output: float = 0.0
@export var is_critical: bool = false


func _init() -> void:
	category = Category.INFRASTRUCTURE


func get_validation_errors() -> Array[String]:
	var errors := super.get_validation_errors()
	if infrastructure_type.is_empty():
		errors.append("Infrastructure '%s' has no type" % id)
	if maximum_integrity <= 0.0 or protection_value < 0.0:
		errors.append("Infrastructure '%s' has invalid integrity or protection value" % id)
	return errors
