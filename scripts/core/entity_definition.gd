class_name EntityDefinition
extends Resource

enum Category {
	SENSOR,
	DEFENSE,
	THREAT,
	INFRASTRUCTURE,
}

@export var id: StringName
@export var display_name: String
@export var category: Category
@export_multiline var description: String
@export var purchase_cost: int = 0
@export_group("Mobility")
@export var mobile: bool = false
@export var relocation_cost: int = 0
@export var teardown_duration: float = 0.0
@export var relocation_speed: float = 0.0
@export var setup_duration: float = 0.0
@export var relocation_allowed_phases: PackedStringArray = PackedStringArray(["running"])


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Definition has an empty id")
	if display_name.strip_edges().is_empty():
		errors.append("Definition '%s' has no display name" % id)
	if purchase_cost < 0:
		errors.append("Definition '%s' has a negative purchase cost" % id)
	if relocation_cost < 0:
		errors.append("Definition '%s' has a negative relocation cost" % id)
	if mobile and (teardown_duration < 0.0 or relocation_speed <= 0.0 or setup_duration < 0.0):
		errors.append("Mobile definition '%s' has invalid relocation timing or speed" % id)
	for phase in relocation_allowed_phases:
		if phase != "preparation" and phase != "running":
			errors.append("Definition '%s' has invalid relocation phase '%s'" % [id, phase])
	return errors
