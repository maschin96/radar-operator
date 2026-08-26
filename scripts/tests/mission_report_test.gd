extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const InfrastructureScript := preload("res://scripts/systems/infrastructure_system.gd")
const ReportScript := preload("res://scripts/systems/mission_report.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenario: Variant = LoaderScript.new().load_scenario(SCENARIO_PATH).scenario
	var infrastructure: Variant = InfrastructureScript.new()
	infrastructure.configure(scenario)
	var report: Variant = ReportScript.new()
	var events: Array[Dictionary] = _events()
	var frames: Array[Dictionary] = [
		{"simulation_time": 0.0, "tracks": [], "infrastructure": []},
		{"simulation_time": 5.0, "tracks": [{"id": "T0001"}], "infrastructure": []},
	]
	report.build(scenario, events, frames, infrastructure.get_infrastructure())

	_test_metrics(report)
	_test_filters(report)
	_test_causal_chain(report)
	_test_replay_and_restart(report, scenario.seed)

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("MISSION REPORT TESTS PASSED: 4 test cases")
	quit(0)


func _events() -> Array[Dictionary]:
	return [
		{"index": 0, "type": &"threat_entered", "category": &"movement", "simulation_time": 1.0, "data": {"threat_id": &"x1"}},
		{"index": 1, "type": &"track_created", "category": &"fusion", "simulation_time": 2.0, "data": {"track_id": &"T0001", "source_entities": [&"x1"]}},
		{"index": 2, "type": &"engagement_failed", "category": &"defense", "simulation_time": 3.0, "data": {"track_id": &"T0001"}},
		{"index": 3, "type": &"threat_target_reached", "category": &"movement", "simulation_time": 4.0, "data": {"threat_id": &"x1", "target_id": &"east_factory"}},
		{"index": 4, "type": &"infrastructure_damaged", "category": &"infrastructure", "simulation_time": 4.0, "data": {"data": {"threat_id": &"x1", "target_id": &"east_factory"}}},
	]


func _test_metrics(report: Variant) -> void:
	var metrics: Dictionary = report.get_metrics()
	_expect(metrics.threats_entered == 1 and metrics.targets_reached == 1, "Threat metrics are incorrect")
	_expect(metrics.engagements_failed == 1 and metrics.infrastructure_hits == 1, "Defense/damage metrics are incorrect")
	_expect(metrics.infrastructure_survived == 3, "Infrastructure survival metric is incorrect")


func _test_filters(report: Variant) -> void:
	_expect(report.filter_events({"category": &"fusion"}).size() == 1, "Category filter is incorrect")
	_expect(report.filter_events({"object_id": &"T0001"}).size() == 2, "Object filter did not link track events")


func _test_causal_chain(report: Variant) -> void:
	var chain: Array = report.build_causal_chain(4)
	_expect(chain.size() == 5, "Damage causal chain did not include detection, defense and impact history")
	_expect(chain.back().type == &"infrastructure_damaged", "Damage causal chain does not end with selected hit")


func _test_replay_and_restart(report: Variant, seed: int) -> void:
	_expect(is_equal_approx(report.get_replay_frame_near(4.9).simulation_time, 0.0), "Replay seek selected a future frame")
	_expect(is_equal_approx(report.get_replay_frame_near(5.0).simulation_time, 5.0), "Replay seek missed exact frame")
	_expect(report.get_restart_configuration(true).seed == seed, "Same-seed restart changed seed")
	_expect(report.get_restart_configuration(false).seed == seed + 1, "New-seed restart did not change seed")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
