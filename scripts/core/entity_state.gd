class_name EntityState
extends RefCounted

var id: StringName
var definition_id: StringName
var faction: StringName
var position: Vector2
var active: bool = true
var damage: float = 0.0


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


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"definition_id": String(definition_id),
		"faction": String(faction),
		"position": {"x": position.x, "y": position.y},
		"active": active,
		"damage": damage,
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
	state.damage = float(data.get("damage", 0.0))
	return state
