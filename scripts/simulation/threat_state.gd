class_name ThreatState
extends EntityState

var route: PackedVector2Array
var next_waypoint_index: int = 1
var target_id: StringName
var completion: StringName
var durability: float
var spawn_time: float
var resolved: bool = false


func _init(
	entity_id: StringName,
	definition_id_value: StringName,
	start_position: Vector2,
	threat_route: PackedVector2Array,
	threat_target_id: StringName,
	completion_type: StringName,
	initial_durability: float,
	scheduled_spawn_time: float
) -> void:
	super(entity_id, definition_id_value, &"hostile", start_position)
	route = threat_route.duplicate()
	target_id = threat_target_id
	completion = completion_type
	durability = initial_durability
	spawn_time = scheduled_spawn_time
