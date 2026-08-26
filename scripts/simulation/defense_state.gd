class_name DefenseState
extends EntityState

enum Status {
	OFFLINE,
	READY,
	TRACKING,
	RELOADING,
	DEPLETED,
}

var status: Status = Status.READY
var ammunition: int
var assigned_track_id: StringName
var tracking_remaining: float = 0.0
var reload_remaining: float = 0.0
var powered: bool = true
var operational: bool = true
var last_decision: Dictionary = {}


func _init(
	entity_id: StringName,
	definition_id_value: StringName,
	world_position: Vector2,
	initial_ammunition: int
) -> void:
	super(entity_id, definition_id_value, &"player", world_position)
	ammunition = initial_ammunition
