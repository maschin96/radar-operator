extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const InfrastructureSystemScript := preload("res://scripts/systems/infrastructure_system.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_only_valid_target_events_apply_damage_once()
	_test_power_dependency_uses_reserve_time()
	_test_required_target_loss_causes_defeat_once()
	_test_duration_with_goals_causes_victory()
	_test_simultaneous_terminal_events_freeze_state()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("INFRASTRUCTURE SYSTEM TESTS PASSED: 5 test cases")
	quit(0)


func _system() -> Variant:
	var scenario: Variant = LoaderScript.new().load_scenario(SCENARIO_PATH).scenario
	var system: Variant = InfrastructureSystemScript.new()
	system.configure(scenario)
	system.start_mission()
	return system


func _hit(threat_id: StringName, definition_id: StringName, target_id: StringName) -> Dictionary:
	return {
		"type": &"threat_target_reached",
		"threat_id": threat_id,
		"definition_id": definition_id,
		"target_id": target_id,
	}


func _test_only_valid_target_events_apply_damage_once() -> void:
	var system: Variant = _system()
	var before: float = system.get_state(&"east_factory").integrity
	var event := _hit(&"h1", &"threat_swift", &"east_factory")
	system.process_threat_events([event, event], 10.0)
	var after: float = system.get_state(&"east_factory").integrity
	_expect(is_equal_approx(before - after, 34.0), "Duplicate threat event applied damage more than once")
	system.process_threat_events([_hit(&"bad", &"threat_swift", &"missing")], 11.0)
	_expect(is_equal_approx(system.get_state(&"east_factory").integrity, after), "Invalid target damaged valid infrastructure")


func _test_power_dependency_uses_reserve_time() -> void:
	var system: Variant = _system()
	system.process_threat_events([
		_hit(&"p1", &"threat_heavy", &"north_power"),
		_hit(&"p2", &"threat_heavy", &"north_power"),
	], 1.0)
	_expect(system.get_state(&"north_power").status == InfrastructureState.Status.DESTROYED, "Power source was not destroyed")
	system.process_tick(4.9, 5.9)
	_expect(system.get_state(&"east_factory").powered, "Factory lost power before reserve expired")
	system.process_tick(0.2, 6.1)
	_expect(not system.get_state(&"east_factory").powered, "Factory retained power after reserve expired")


func _test_required_target_loss_causes_defeat_once() -> void:
	var system: Variant = _system()
	system.process_threat_events([
		_hit(&"c1", &"threat_heavy", &"capital_command"),
		_hit(&"c2", &"threat_heavy", &"capital_command"),
		_hit(&"c3", &"threat_heavy", &"capital_command"),
	], 20.0)
	_expect(system.get_mission_status() == InfrastructureSystem.MissionStatus.DEFEAT, "Required target loss did not cause defeat")
	var end_events := _count_events(system.get_events(), &"mission_ended")
	system.process_tick(1.0, 21.0)
	_expect(end_events == 1 and _count_events(system.get_events(), &"mission_ended") == 1, "Mission end was emitted more than once")


func _test_duration_with_goals_causes_victory() -> void:
	var system: Variant = _system()
	system.process_tick(0.1, 180.0)
	_expect(system.get_mission_status() == InfrastructureSystem.MissionStatus.VICTORY, "Surviving mission duration did not cause victory")


func _test_simultaneous_terminal_events_freeze_state() -> void:
	var system: Variant = _system()
	var events := [
		_hit(&"c1", &"threat_heavy", &"capital_command"),
		_hit(&"c2", &"threat_heavy", &"capital_command"),
		_hit(&"c3", &"threat_heavy", &"capital_command"),
	]
	system.process_threat_events(events, 180.0)
	var frozen_integrity: float = system.get_state(&"east_factory").integrity
	system.process_threat_events([_hit(&"late", &"threat_heavy", &"east_factory")], 180.0)
	_expect(is_equal_approx(system.get_state(&"east_factory").integrity, frozen_integrity), "State changed after terminal mission event")
	_expect(_count_events(system.get_events(), &"mission_ended") == 1, "Simultaneous terminal conditions emitted multiple ends")


func _count_events(events: Array, type: StringName) -> int:
	var count := 0
	for event in events:
		count += int(event.type == type)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
