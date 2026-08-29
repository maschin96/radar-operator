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
	_test_assignment_cancellation()
	_test_manual_release_limits()
	_test_profile_preview_is_pure_and_matches_assignment()
	_test_profile_validation_and_reset()
	_test_rejected_candidates_and_idle_events()
	_test_protection_priorities_and_redundancy()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("DEFENSE SYSTEM TESTS PASSED: 14 test cases")
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


func _test_assignment_cancellation() -> void:
	for cause in ["block", "revoke", "classification", "offline", "range"]:
		var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500, 500)}])
		var track: Variant = _track(&"T0001", Vector2(600, 500))
		system.set_rules({"automatic_release": false})
		system.authorize_track(track.id)
		system.process_tick(0.1, 0.1, [track])
		var defense: DefenseState = system.get_defenses()[0]
		var ammunition := defense.ammunition
		match cause:
			"block": track.release_status = TrackState.ReleaseStatus.BLOCKED
			"revoke": system.revoke_track_authorization(track.id)
			"classification": track.classification = &"unknown"
			"offline": defense.powered = false
			"range": track.estimated_position = Vector2(1900, 1000)
		system.process_tick(10.0, 10.1, [track])
		_expect(defense.assigned_track_id.is_empty(), "Assignment survived " + cause)
		_expect(defense.ammunition == ammunition, "Cancellation consumed ammunition: " + cause)
		_expect(defense.last_decision.get("result") == "cancelled", "Cancellation missing decision: " + cause)
		_expect(system.get_events().back().data.has("reason"), "Cancellation missing reason: " + cause)


func _test_manual_release_limits() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_short_range", "position": Vector2(500, 500)}])
	var track: Variant = _track(&"T0001", Vector2(600, 500), &"unknown")
	_expect(system.get_track_eligibility(track, true)[0].reason == "classification_too_low", "Manual release bypassed classification")
	track.classification = &"hostile"
	track.estimated_position = Vector2(1900, 1000)
	_expect(system.get_track_eligibility(track, true)[0].reason == "out_of_range", "Manual release bypassed range")
	track.estimated_position = Vector2(600, 500)
	system.get_defenses()[0].ammunition = 0
	_expect(system.get_track_eligibility(track, true)[0].reason == "ammunition_empty", "Manual release bypassed ammunition")


func _test_profile_preview_is_pure_and_matches_assignment() -> void:
	var system: Variant = _system([
		{"id": &"d2", "definition_id": &"defense_medium_range", "position": Vector2(500, 500)},
		{"id": &"d1", "definition_id": &"defense_medium_range", "position": Vector2(500, 500)},
	])
	var first: Variant = _track(&"T0001", Vector2(700, 500))
	var second: Variant = _track(&"T0002", Vector2(700, 500), &"suspicious")
	second.priority = TrackState.Priority.CRITICAL
	var rules: Dictionary = system.get_rules()
	var events: Array = system.get_events()
	for classification in ["suspicious", "hostile"]:
		var draft := rules.duplicate(true)
		draft.minimum_classification = classification
		var preview: Dictionary = system.preview_rules(draft, [second, first])
		_expect(preview.success, "Valid preview rejected")
		_expect(system.get_rules() == rules and system.get_events() == events, "Preview mutated rules or events")
		_expect(system.get_defenses()[0].assigned_track_id.is_empty(), "Preview assigned a real system")
		var expected := "T0002" if classification == "suspicious" else "T0001"
		_expect(preview.decisions[0].decision.track_id == expected, "Preview ignored minimum classification or priority")
	var preview: Dictionary = system.preview_rules(rules, [second, first])
	system.process_tick(0.1, 0.1, [second, first])
	for index in 2:
		_expect(system.get_defenses()[index].last_decision == preview.decisions[index].decision, "Preview differs from real deterministic assignment")
	var stricter := rules.duplicate(true)
	stricter.minimum_classification = "hostile"
	var cancellation: Dictionary = system.preview_rules(stricter, [second, first])
	_expect(cancellation.decisions[0].decision.result == "cancelled", "Preview missed a profile-induced cancellation")


func _test_profile_validation_and_reset() -> void:
	var system: Variant = _system([])
	var before: Dictionary = system.get_rules()
	for patch in [{"display_name": " "}, {"automatic_release": "false"}, {"minimum_classification": "unknown"}, {"infrastructure_priorities": {"missing": 1}}, {"infrastructure_priorities": {"power_1": NAN}}, {"infrastructure_priorities": {"power_1": "high"}}]:
		_expect(not system.set_rules(patch).success, "Malformed/conflicting profile accepted: " + str(patch))
		_expect(system.get_rules() == before, "Invalid profile partially applied")
	_expect(not system.preview_rules({"display_name": "Incomplete"}, []).success, "Incomplete preview accepted")
	system.set_rules({"automatic_release": false})
	system.configure(_scenario())
	_expect(system.get_rules().automatic_release, "Reconfigure leaked previous session rules")


func _test_rejected_candidates_and_idle_events() -> void:
	var system: Variant = _system([{"id": &"d1", "definition_id": &"defense_medium_range", "position": Vector2(500, 500)}])
	var first: Variant = _track(&"T0001", Vector2(700, 500), &"unknown")
	var second: Variant = _track(&"T0002", Vector2(1900, 1000))
	system.process_tick(0.1, 0.1, [second, first])
	var decision: Dictionary = system.get_defenses()[0].last_decision
	_expect(decision.candidates[0].reason == "classification_too_low", "Declined track lacks classification explanation")
	_expect(decision.candidates[1].reason == "out_of_range", "Declined track lacks range explanation")
	_expect(system.get_events().back().type == &"assignment_declined", "Non-assignment event missing")
	var count: int = system.get_events().size()
	system.process_tick(0.1, 0.2, [first, second])
	_expect(system.get_events().size() == count, "Unchanged idle decisions flood event log")


func _test_protection_priorities_and_redundancy() -> void:
	var system: Variant = _system([
		{"id": &"d1", "definition_id": &"defense_medium_range", "position": Vector2(500, 500)},
		{"id": &"d2", "definition_id": &"defense_medium_range", "position": Vector2(500, 500)},
	])
	var track: Variant = _track(&"T0001", Vector2(700, 500))
	var rules: Dictionary = system.get_rules()
	var priorities: Dictionary = {}
	for entity in LoaderScript.new().instantiate_starting_entities(_scenario()):
		priorities[String(entity.id)] = 0.0
	rules.infrastructure_priorities = priorities
	var zero: Dictionary = system.preview_rules(rules, [track])
	_expect(is_zero_approx(zero.decisions[0].decision.urgency_score), "Zero protection priority retained protection score")
	_expect(zero.decisions[1].decision.result == "no_valid_track", "Redundant assignment bypassed disabled rule")
	rules.allow_redundant_engagement = true
	var redundant: Dictionary = system.preview_rules(rules, [track])
	_expect(redundant.decisions[1].decision.result == "assigned", "Redundant profile ignored")
	_expect(redundant.decisions[1].decision.duplicate_penalty > 0, "Redundant scoring omitted penalty")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
