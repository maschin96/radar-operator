class_name EntityState
extends RefCounted

enum MobilityStatus {
	STATIONARY,
	TEARDOWN,
	MOVING,
	SETUP,
}

var id: StringName
var definition_id: StringName
var faction: StringName
var position: Vector2
var initial_position: Vector2
var active: bool = true
var damage: float = 0.0
var mobility_status: MobilityStatus = MobilityStatus.STATIONARY
var relocation_origin := Vector2.ZERO
var relocation_target := Vector2.ZERO
var relocation_path: PackedVector2Array = PackedVector2Array()
var relocation_path_index: int = 0
var relocation_remaining: float = 0.0
var relocation_command_id: int = 0


func _init(
	entity_id: StringName,
	entity_definition_id: StringName,
	entity_faction: StringName,
	world_position: Vector2
) -> void:
	id = entity_id
	definition_id = entity_definition_id
	faction = entity_faction
	position = world_position
	initial_position = world_position


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"definition_id": String(definition_id),
		"faction": String(faction),
		"position": {"x": position.x, "y": position.y},
		"initial_position": {"x": initial_position.x, "y": initial_position.y},
		"active": active,
		"damage": damage,
		"mobility_status": mobility_status,
		"relocation_origin": {"x": relocation_origin.x, "y": relocation_origin.y},
		"relocation_target": {"x": relocation_target.x, "y": relocation_target.y},
		"relocation_path": _path_to_array(relocation_path),
		"relocation_path_index": relocation_path_index,
		"relocation_remaining": relocation_remaining,
		"relocation_command_id": relocation_command_id,
	}


static func from_dictionary(data: Dictionary) -> EntityState:
	var position_data: Dictionary = data.get("position", {})
	var state := EntityState.new(
		StringName(data.get("id", "")),
		StringName(data.get("definition_id", "")),
		StringName(data.get("faction", "neutral")),
		Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	)
	state.active = bool(data.get("active", true))
	state.initial_position = _dictionary_to_vector(data.get("initial_position", position_data))
	state.damage = float(data.get("damage", 0.0))
	state.mobility_status = int(data.get("mobility_status", MobilityStatus.STATIONARY)) as MobilityStatus
	state.relocation_origin = _dictionary_to_vector(data.get("relocation_origin", {}))
	state.relocation_target = _dictionary_to_vector(data.get("relocation_target", {}))
	state.relocation_path = _array_to_path(data.get("relocation_path", []))
	state.relocation_path_index = int(data.get("relocation_path_index", 0))
	state.relocation_remaining = float(data.get("relocation_remaining", 0.0))
	state.relocation_command_id = int(data.get("relocation_command_id", 0))
	return state


static func _path_to_array(path: PackedVector2Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for point in path:
		result.append({"x": point.x, "y": point.y})
	return result


static func _array_to_path(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(_dictionary_to_vector(point))
	return result


static func _dictionary_to_vector(data: Dictionary) -> Vector2:
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
