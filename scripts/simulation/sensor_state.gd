class_name SensorState
extends EntityState

var next_scan_time: float = 0.0
var powered: bool = true
var operational: bool = true
var scan_count: int = 0
var network_quality: float = 1.0


func _init(
	entity_id: StringName,
	definition_id_value: StringName,
	world_position: Vector2
) -> void:
	super(entity_id, definition_id_value, &"player", world_position)
