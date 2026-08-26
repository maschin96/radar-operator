extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const PlacementScript := preload("res://scripts/systems/placement_system.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_invalid_positions_are_rejected()
	_test_budget_never_becomes_negative()
	_test_removal_refunds_full_cost()
	_test_preview_range_matches_definition()
	_test_deployment_locks_static_placement()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("PLACEMENT SYSTEM TESTS PASSED: 5 test cases")
	quit(0)


func _placement() -> Variant:
	var scenario: Variant = LoaderScript.new().load_scenario(SCENARIO_PATH).scenario
	var placement: Variant = PlacementScript.new()
	placement.configure(scenario)
	return placement


func _test_invalid_positions_are_rejected() -> void:
	var placement: Variant = _placement()
	_expect(not placement.place(&"sensor_short_range", Vector2(-1.0, 100.0)).success, "Outside-map placement was accepted")
	_expect(not placement.place(&"sensor_short_range", Vector2(1000.0, 610.0)).success, "Blocked-zone placement was accepted")
	_expect(placement.get_budget() == placement.get_initial_budget(), "Invalid placement changed budget")


func _test_budget_never_becomes_negative() -> void:
	var placement: Variant = _placement()
	var positions := [Vector2(200.0, 200.0), Vector2(500.0, 200.0), Vector2(800.0, 200.0)]
	for position in positions:
		placement.place(&"defense_medium_range", position)
	_expect(placement.get_budget() >= 0, "Placement budget became negative")
	_expect(placement.get_placements().size() == 2, "Unaffordable third system was placed")


func _test_removal_refunds_full_cost() -> void:
	var placement: Variant = _placement()
	var initial_budget: int = placement.get_budget()
	var result: Dictionary = placement.place(&"sensor_early_warning", Vector2(300.0, 300.0))
	_expect(result.success, "Valid sensor placement failed")
	if result.success:
		_expect(placement.remove(result.entity.id), "Placed sensor could not be removed")
		_expect(placement.get_budget() == initial_budget, "Removal did not restore full cost")


func _test_preview_range_matches_definition() -> void:
	var placement: Variant = _placement()
	var preview: Dictionary = placement.preview_placement(&"sensor_short_range", Vector2(250.0, 250.0))
	_expect(is_equal_approx(preview.range, 360.0), "Sensor overlay range differs from simulation definition")
	var defense_preview: Dictionary = placement.preview_placement(&"defense_medium_range", Vector2(250.0, 250.0))
	_expect(is_equal_approx(defense_preview.range, 520.0), "Defense overlay range differs from simulation definition")


func _test_deployment_locks_static_placement() -> void:
	var placement: Variant = _placement()
	var result: Dictionary = placement.place(&"defense_gun", Vector2(220.0, 220.0))
	_expect(result.success, "Valid pre-deployment placement failed")
	_expect(placement.start_deployment(), "Could not start deployment")
	_expect(not placement.place(&"defense_gun", Vector2(300.0, 220.0)).success, "Placement remained available after deployment")
	_expect(not placement.move(result.entity.id, Vector2(240.0, 240.0)).success, "Static system moved after deployment")
	_expect(not placement.remove(result.entity.id), "Static system was removed after deployment")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
