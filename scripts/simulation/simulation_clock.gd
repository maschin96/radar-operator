class_name SimulationClock
extends RefCounted

const ALLOWED_TIME_SCALES: Array[float] = [0.0, 1.0, 2.0, 4.0]
const TICK_EPSILON := 0.000000001

var tick_duration: float
var time_scale: float = 1.0
var _accumulator: float = 0.0


func _init(fixed_tick_duration: float = 0.1) -> void:
	assert(fixed_tick_duration > 0.0, "Tick duration must be positive")
	tick_duration = fixed_tick_duration


func set_time_scale(value: float) -> bool:
	if not ALLOWED_TIME_SCALES.has(value):
		push_warning("Unsupported simulation time scale: %s" % value)
		return false
	time_scale = value
	return true


func advance(real_delta: float, tick_callback: Callable) -> int:
	if real_delta < 0.0:
		push_error("Simulation cannot advance by a negative delta")
		return 0
	if time_scale == 0.0 or real_delta == 0.0:
		return 0

	_accumulator += real_delta * time_scale
	var processed_ticks := 0
	while _accumulator + TICK_EPSILON >= tick_duration:
		_accumulator -= tick_duration
		if absf(_accumulator) < TICK_EPSILON:
			_accumulator = 0.0
		tick_callback.call()
		processed_ticks += 1
	return processed_ticks


func get_alpha() -> float:
	return clampf(_accumulator / tick_duration, 0.0, 1.0)


func get_accumulator() -> float:
	return _accumulator


func reset() -> void:
	time_scale = 1.0
	_accumulator = 0.0
