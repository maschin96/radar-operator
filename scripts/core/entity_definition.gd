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


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Definition has an empty id")
	if display_name.strip_edges().is_empty():
		errors.append("Definition '%s' has no display name" % id)
	if purchase_cost < 0:
		errors.append("Definition '%s' has a negative purchase cost" % id)
	return errors
