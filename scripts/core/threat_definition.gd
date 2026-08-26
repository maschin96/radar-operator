class_name ThreatDefinition
extends EntityDefinition

@export var movement_speed: float = 120.0
@export_range(0.0, 1.0) var signature_strength: float = 0.7
@export var durability: float = 1.0
@export var impact_damage: float = 40.0
@export var target_preference: StringName = &"any"


func _init() -> void:
	category = Category.THREAT


func get_validation_errors() -> Array[String]:
	var errors := super.get_validation_errors()
	if movement_speed <= 0.0:
		errors.append("Threat '%s' has no movement speed" % id)
	if durability <= 0.0 or impact_damage < 0.0:
		errors.append("Threat '%s' has invalid durability or impact damage" % id)
	return errors
