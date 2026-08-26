class_name SimulationCommand
extends RefCounted

var target_tick: int
var sequence: int
var action: StringName
var payload: Dictionary


func _init(
	command_target_tick: int,
	command_sequence: int,
	command_action: StringName,
	command_payload: Dictionary = {}
) -> void:
	target_tick = command_target_tick
	sequence = command_sequence
	action = command_action
	payload = command_payload.duplicate(true)


func comes_before(other: SimulationCommand) -> bool:
	if target_tick != other.target_tick:
		return target_tick < other.target_tick
	return sequence < other.sequence
