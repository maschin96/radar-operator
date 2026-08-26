extends SceneTree

const Core := preload("res://scripts/simulation/simulation_core.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pause_freezes_simulation()
	_test_supported_time_scales_process_every_tick()
	_test_frame_partition_does_not_change_state()
	_test_seed_and_commands_are_reproducible()
	_test_events_use_simulation_timestamps()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return

	print("SIMULATION CORE TESTS PASSED: 5 test cases")
	quit(0)


func _test_pause_freezes_simulation() -> void:
	var simulation := Core.new(7)
	_expect(simulation.set_time_scale(0.0), "Pause scale should be accepted")
	var processed := simulation.advance(30.0)
	var snapshot := simulation.get_snapshot()
	_expect(processed == 0, "Paused simulation processed ticks")
	_expect(snapshot.tick == 0, "Paused simulation changed tick")
	_expect(is_equal_approx(snapshot.simulation_time, 0.0), "Paused simulation changed time")


func _test_supported_time_scales_process_every_tick() -> void:
	var simulation := Core.new(11)
	var observed_ticks: Array[int] = []
	simulation.tick_completed.connect(func(tick: int) -> void: observed_ticks.append(tick))

	_expect(simulation.set_time_scale(2.0), "2x scale should be accepted")
	_expect(simulation.advance(0.25) == 5, "2x scale should process five ticks")
	_expect(simulation.set_time_scale(4.0), "4x scale should be accepted")
	_expect(simulation.advance(0.125) == 5, "4x scale should process five more ticks")
	_expect(observed_ticks == range(1, 11), "Time scaling skipped or reordered ticks")
	_expect(not simulation.set_time_scale(3.0), "Unsupported 3x scale was accepted")


func _test_frame_partition_does_not_change_state() -> void:
	var fine_frames := Core.new(23)
	var coarse_frames := Core.new(23)
	for index in 100:
		fine_frames.advance(0.01)
	for index in 4:
		coarse_frames.advance(0.25)

	_expect(
		_comparable_snapshot(fine_frames) == _comparable_snapshot(coarse_frames),
		"Different render-frame partitions produced different simulation state"
	)


func _test_seed_and_commands_are_reproducible() -> void:
	var first: Variant = _build_commanded_simulation(9182)
	var second: Variant = _build_commanded_simulation(9182)
	var other_seed: Variant = _build_commanded_simulation(9183)

	for index in 20:
		first.advance(0.05)
	for index in 5:
		second.advance(0.2)
	other_seed.advance(1.0)

	_expect(
		_comparable_snapshot(first) == _comparable_snapshot(second),
		"Same seed and commands did not reproduce the same world state"
	)
	_expect(
		first.get_snapshot().values != other_seed.get_snapshot().values,
		"Different seeds unexpectedly produced identical random world values"
	)


func _test_events_use_simulation_timestamps() -> void:
	var simulation: Variant = Core.new(3)
	simulation.enqueue_command(&"set_value", {"key": &"alert", "value": 2}, 3)
	simulation.advance(0.3)
	var events: Array = simulation.get_events()

	_expect(events.size() == 1, "Expected one command event")
	if events.size() == 1:
		_expect(events[0].tick == 3, "Event has wrong tick")
		_expect(is_equal_approx(events[0].simulation_time, 0.3), "Event has wrong simulation time")


func _build_commanded_simulation(seed: int) -> Variant:
	var simulation: Variant = Core.new(seed)
	simulation.enqueue_command(&"set_value", {"key": &"score", "value": 10}, 1)
	simulation.enqueue_command(&"random_add", {"key": &"score", "minimum": 1, "maximum": 1000}, 3)
	simulation.enqueue_command(&"add_value", {"key": &"score", "amount": 5}, 7)
	return simulation


func _comparable_snapshot(simulation: Variant) -> Dictionary:
	var snapshot: Dictionary = simulation.get_snapshot()
	return {
		"seed": snapshot.seed,
		"tick": snapshot.tick,
		"simulation_time": snapshot.simulation_time,
		"values": snapshot.values,
		"pending_command_count": snapshot.pending_command_count,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
