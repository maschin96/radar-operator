class_name SimulationEvent
extends RefCounted

var tick: int
var simulation_time: float
var event_type: StringName
var data: Dictionary


func _init(
	event_tick: int,
	event_simulation_time: float,
	type: StringName,
	event_data: Dictionary = {}
) -> void:
	tick = event_tick
	simulation_time = event_simulation_time
	event_type = type
	data = event_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"simulation_time": simulation_time,
		"event_type": String(event_type),
		"data": data.duplicate(true),
	}
