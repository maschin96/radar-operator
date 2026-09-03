class_name InfrastructureState
extends EntityState

enum Status {
	FUNCTIONAL,
	DAMAGED,
	DESTROYED,
}

enum NetworkStatus {
	ONLINE,
	RESERVE,
	DEGRADED,
	OFFLINE,
}

var maximum_integrity: float
var integrity: float
var status: Status = Status.FUNCTIONAL
var powered: bool = true
var communication_online: bool = true
var energy_status: NetworkStatus = NetworkStatus.ONLINE
var communication_status: NetworkStatus = NetworkStatus.ONLINE
var network_reserves: Dictionary = {"energy": 0.0, "communication": 0.0}
var network_sources: Dictionary = {"energy": "", "communication": ""}
var network_causes: Dictionary = {"energy": "", "communication": ""}
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
		"communication_online": communication_online,
		"energy_status": energy_status,
		"communication_status": communication_status,
		"network_reserves": network_reserves.duplicate(true),
		"network_sources": network_sources.duplicate(true),
		"network_causes": network_causes.duplicate(true),
		"protection_value": protection_value,
		"infrastructure_type": String(infrastructure_type),
		"is_critical": is_critical,
	}, true)
	return data
