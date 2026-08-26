class_name SimulationCore
extends RefCounted

signal tick_completed(tick: int)
signal event_published(event: RefCounted)

const DEFAULT_TICK_DURATION := 0.1
const Clock := preload("res://scripts/simulation/simulation_clock.gd")
const Command := preload("res://scripts/simulation/simulation_command.gd")
const Event := preload("res://scripts/simulation/simulation_event.gd")

var _clock: RefCounted
var _seed: int
var _random := RandomNumberGenerator.new()
var _tick: int = 0
var _simulation_time: float = 0.0
var _next_command_sequence: int = 0
var _commands: Array[RefCounted] = []
var _events: Array[RefCounted] = []
var _values: Dictionary = {}


func _init(seed: int = 1, tick_duration: float = DEFAULT_TICK_DURATION) -> void:
	_seed = seed
	_random.seed = seed
	_clock = Clock.new(tick_duration)


func advance(real_delta: float) -> int:
	return _clock.advance(real_delta, _run_tick)


func set_time_scale(value: float) -> bool:
	return _clock.set_time_scale(value)


func get_time_scale() -> float:
	return _clock.time_scale


func is_paused() -> bool:
	return _clock.time_scale == 0.0


func enqueue_command(
	action: StringName,
	payload: Dictionary = {},
	target_tick: int = -1
) -> RefCounted:
	var scheduled_tick := target_tick
	if scheduled_tick < 0:
		scheduled_tick = _tick + 1
	if scheduled_tick <= _tick:
		push_warning(
			"Command '%s' targeted past tick %d; scheduled for tick %d instead"
			% [action, scheduled_tick, _tick + 1]
		)
		scheduled_tick = _tick + 1

	var command := Command.new(
		scheduled_tick,
		_next_command_sequence,
		action,
		payload
	)
	_next_command_sequence += 1
	_commands.append(command)
	_commands.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return a.comes_before(b))
	return command


func publish_event(event_type: StringName, data: Dictionary = {}) -> RefCounted:
	var event := Event.new(_tick, _simulation_time, event_type, data)
	_events.append(event)
	event_published.emit(event)
	return event


func get_snapshot() -> Dictionary:
	return {
		"seed": _seed,
		"tick": _tick,
		"simulation_time": _simulation_time,
		"time_scale": _clock.time_scale,
		"values": _values.duplicate(true),
		"pending_command_count": _commands.size(),
	}


func get_events() -> Array[RefCounted]:
	return _events.duplicate()


func get_interpolation_alpha() -> float:
	return _clock.get_alpha()


func _run_tick() -> void:
	_tick += 1
	_simulation_time = _tick * _clock.tick_duration
	_apply_due_commands()
	tick_completed.emit(_tick)


func _apply_due_commands() -> void:
	while not _commands.is_empty() and _commands[0].target_tick <= _tick:
		var command: RefCounted = _commands.pop_front()
		_apply_command(command)


func _apply_command(command: RefCounted) -> void:
	match command.action:
		&"set_value":
			var key := StringName(command.payload.get("key", ""))
			_values[key] = command.payload.get("value")
			publish_event(&"value_set", {"key": key, "value": _values[key]})
		&"add_value":
			var key := StringName(command.payload.get("key", ""))
			var amount: float = float(command.payload.get("amount", 0.0))
			_values[key] = float(_values.get(key, 0.0)) + amount
			publish_event(&"value_added", {"key": key, "amount": amount})
		&"random_add":
			var key := StringName(command.payload.get("key", ""))
			var minimum: int = int(command.payload.get("minimum", 0))
			var maximum: int = int(command.payload.get("maximum", 0))
			var random_amount := _random.randi_range(minimum, maximum)
			_values[key] = int(_values.get(key, 0)) + random_amount
			publish_event(&"random_value_added", {"key": key, "amount": random_amount})
		_:
			publish_event(
				&"command_rejected",
				{"action": command.action, "reason": "unknown_action"}
			)
