class_name DefenseDefinition
extends EntityDefinition

@export var engagement_range: float = 200.0
@export var minimum_range: float = 0.0
@export var tracking_time: float = 1.0
@export var reload_time: float = 3.0
@export var ammunition: int = 4
@export_range(0.0, 1.0) var base_success_chance: float = 0.65
@export var power_demand: float = 8.0


func _init() -> void:
	category = Category.DEFENSE


func get_validation_errors() -> Array[String]:
	var errors := super.get_validation_errors()
	if engagement_range <= 0.0 or minimum_range < 0.0 or minimum_range >= engagement_range:
		errors.append("Defense '%s' has an invalid engagement envelope" % id)
	if tracking_time < 0.0 or reload_time < 0.0:
		errors.append("Defense '%s' has a negative timing value" % id)
	if ammunition < 0:
		errors.append("Defense '%s' has negative ammunition" % id)
	return errors
