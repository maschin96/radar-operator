class_name InfrastructureState
extends EntityState

enum Status {
	FUNCTIONAL,
	DAMAGED,
	DESTROYED,
}

var maximum_integrity: float
var integrity: float
var status: Status = Status.FUNCTIONAL
var powered: bool = true
var protection_value: float
var infrastructure_type: StringName
var is_critical: bool


func _init(
	entity_id: StringName,
	definition_id_value: StringName,
	world_position: Vector2,
	definition: InfrastructureDefinition
) -> void:
	super(entity_id, definition_id_value, &"player", world_position)
	maximum_integrity = definition.maximum_integrity
	integrity = maximum_integrity
	protection_value = definition.protection_value
	infrastructure_type = definition.infrastructure_type
	is_critical = definition.is_critical


func apply_damage(amount: float) -> float:
	if status == Status.DESTROYED or amount <= 0.0:
		return 0.0
	var before := integrity
	integrity = maxf(integrity - amount, 0.0)
	damage = 1.0 - integrity / maximum_integrity
	if integrity <= 0.0:
		status = Status.DESTROYED
		active = false
	elif integrity < maximum_integrity:
		status = Status.DAMAGED
	return before - integrity


func to_dictionary() -> Dictionary:
	var data := super.to_dictionary()
	data.merge({
		"maximum_integrity": maximum_integrity,
		"integrity": integrity,
		"status": status,
		"powered": powered,
		"protection_value": protection_value,
		"infrastructure_type": String(infrastructure_type),
		"is_critical": is_critical,
	}, true)
	return data
