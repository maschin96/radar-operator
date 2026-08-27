extends SceneTree

const LoaderScript := preload("res://scripts/core/scenario_loader.gd")
const DefenseSystemScript := preload("res://scripts/systems/defense_system.gd")
const EntityStateScript := preload("res://scripts/core/entity_state.gd")
const TrackScript := preload("res://scripts/simulation/track_state.gd")
const SCENARIO_PATH := "res://data/scenarios/mvp_test_scenario.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_only_valid_classified_tracks_are_assigned()
	_test_ammunition_and_reload_are_enforced()
	_test_redundant_assignments_are_avoided()
	_test_decision_is_explainable_and_ties_are_stable()
	_test_manual_release_and_track_loss()
	_test_manual_priority_changes_stable_target_order()
	_test_manual_block_prevents_assignment()
	_test_invalid_rule_profile_is_rejected()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("DEFENSE SYSTEM TESTS PASSED: 8 test cases")
	quit(0)


func _scenario() -> Variant:
	return LoaderScript.new().load_scenario(SCENARIO_PATH).scenario


func _system(defenses: Array) -> Variant:
	var scenario: Variant = _scenario()
	var infrastructure: Array[EntityState] = LoaderScript.new().instantiate_starting_entities(scenario)
	var system: Variant = DefenseSystemScript.new()
	system.configure(scenario, infrastructure)
	for data in defenses:
		system.add_defense(EntityStateScript.new(data.id, data.definition_id, &"player", data.position))
	return system


func _track(id: StringName, position: Vector2, classification: StringName = &"hostile") -> Variant:
	var track: Variant = TrackScript.new(id, position, 10.0, 0.0)
	track.classification = classification
	track.classification_confidence = 0.9 if classification == &"hostile" else 0.3
	track.estimated_velocity = Vector2(-40.0, 0.0)
	return track


func _test_only_valid_classified_tracks_are_assigned() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500.0, 500.0)}])
	var unknown: Variant = _track(&"T0001", Vector2(600.0, 500.0), &"unknown")
	system.process_tick(0.1, 0.1, [unknown])
	_expect(system.get_defenses()[0].assigned_track_id.is_empty(), "Unknown track was assigned")
	var hostile: Variant = _track(&"T0002", Vector2(600.0, 500.0))
	system.process_tick(0.1, 0.2, [hostile])
	_expect(system.get_defenses()[0].assigned_track_id == &"T0002", "Valid hostile track was not assigned")


func _test_ammunition_and_reload_are_enforced() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_gun", "position": Vector2(500.0, 500.0)}])
	var track: Variant = _track(&"T0001", Vector2(560.0, 500.0))
	system.process_tick(0.1, 0.1, [track])
	var before: int = system.get_defenses()[0].ammunition
	system.process_tick(0.5, 0.6, [track])
	var defense: Variant = system.get_defenses()[0]
	_expect(defense.ammunition == before - 1, "Engagement did not consume exactly one ammunition")
	_expect(defense.status != DefenseState.Status.READY, "Defense ignored reload/depleted state")


func _test_redundant_assignments_are_avoided() -> void:
	var system: Variant = _system([
		{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500.0, 500.0)},
		{"id": &"d2", "definition_id": &"defense_short_range", "position": Vector2(520.0, 500.0)},
	])
	var track: Variant = _track(&"T0001", Vector2(650.0, 500.0))
	track.estimated_velocity = Vector2.ZERO
	system.process_tick(0.1, 0.1, [track])
	var assigned := 0
	for defense in system.get_defenses():
		assigned += int(not defense.assigned_track_id.is_empty())
	_expect(assigned == 1, "Default rules created an unnecessary redundant assignment")


func _test_decision_is_explainable_and_ties_are_stable() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_medium_range", "position": Vector2(500.0, 500.0)}])
	var first: Variant = _track(&"T0001", Vector2(700.0, 500.0))
	var second: Variant = _track(&"T0002", Vector2(700.0, 500.0))
	system.process_tick(0.1, 0.1, [second, first])
	var defense: Variant = system.get_defenses()[0]
	_expect(
		defense.assigned_track_id == &"T0001",
		"Equal-score target tie was not resolved by stable id order; got '%s'" % defense.assigned_track_id
	)
	_expect(defense.last_decision.has("classification_score"), "Decision lacks classification explanation")
	_expect(defense.last_decision.has("success_chance"), "Decision lacks success explanation")


func _test_manual_release_and_track_loss() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500.0, 500.0)}])
	var track: Variant = _track(&"T0001", Vector2(600.0, 500.0))
	system.set_rules({"automatic_release": false})
	system.process_tick(0.1, 0.1, [track])
	_expect(system.get_defenses()[0].assigned_track_id.is_empty(), "Manual mode assigned without authorization")
	system.authorize_track(track.id)
	system.process_tick(0.1, 0.2, [track])
	_expect(system.get_defenses()[0].assigned_track_id == track.id, "Manual authorization did not assign track")
	system.process_tick(0.1, 0.3, [])
	_expect(system.get_defenses()[0].assigned_track_id.is_empty(), "Lost track remained assigned")


func _test_manual_priority_changes_stable_target_order() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_medium_range", "position": Vector2(500.0, 500.0)}])
	var first: Variant = _track(&"T0001", Vector2(700.0, 500.0))
	var second: Variant = _track(&"T0002", Vector2(700.0, 500.0))
	second.priority = TrackState.Priority.CRITICAL
	system.process_tick(0.1, 0.1, [first, second])
	_expect(system.get_defenses()[0].assigned_track_id == &"T0002", "Manual critical priority did not change deterministic assignment")


func _test_manual_block_prevents_assignment() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500.0, 500.0)}])
	var track: Variant = _track(&"T0001", Vector2(600.0, 500.0))
	track.release_status = TrackState.ReleaseStatus.BLOCKED
	system.process_tick(0.1, 0.1, [track])
	_expect(system.get_defenses()[0].assigned_track_id.is_empty(), "Blocked track was assigned")


func _test_invalid_rule_profile_is_rejected() -> void:
	var system: Variant = _system([])
	var before: Dictionary = system.get_rules()
	var result: Dictionary = system.set_rules({"minimum_classification": &"imaginary"})
	_expect(not result.success, "Invalid minimum classification was accepted")
	_expect(system.get_rules() == before, "Rejected rule profile partially changed active rules")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
