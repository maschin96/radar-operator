extends SceneTree

const CatalogScript := preload("res://scripts/core/scenario_catalog.gd")
const ProfileScript := preload("res://scripts/systems/profile_manager.gd")
const TEST_PATH := "user://profile_manager_test.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var catalog: Variant = CatalogScript.new()
	_expect(catalog.discover().success, "Test catalog failed to load")
	var manager: Variant = ProfileScript.new()
	manager.create_default(catalog)
	_expect(manager.is_unlocked(&"tutorial_mission_1"), "Default profile did not unlock entry mission")
	_expect(not manager.is_unlocked(&"mvp_test_scenario"), "Default profile unlocked dependent mission")
	_expect(not manager.reset(catalog, false).success, "Profile reset did not require confirmation")
	manager.record_mission_result(&"tutorial_mission_1", InfrastructureSystem.MissionStatus.VICTORY, catalog)
	_expect(manager.is_completed(&"tutorial_mission_1"), "Victory was not recorded")
	_expect(manager.is_unlocked(&"mvp_test_scenario"), "Victory did not unlock dependent mission")
	var progress: Dictionary = manager.get_campaign_progress(catalog)
	_expect(progress.completed == 1 and progress.total == 2, "Campaign progress did not reflect completion")
	var next_scenario: ScenarioDefinition = manager.get_next_unlocked_scenario(&"tutorial_mission_1", catalog)
	_expect(next_scenario != null and next_scenario.scenario_id == &"mvp_test_scenario", "Next unlocked campaign mission was not resolved")
	_expect(manager.get_mission_result(&"tutorial_mission_1") == InfrastructureSystem.MissionStatus.VICTORY, "Best mission result was not exposed")
	manager.record_mission_result(&"tutorial_mission_1", InfrastructureSystem.MissionStatus.DEFEAT, catalog)
	_expect(manager.get_mission_result(&"tutorial_mission_1") == InfrastructureSystem.MissionStatus.VICTORY, "A later defeat replaced the best victory result")
	_expect(manager.save(TEST_PATH).success, "Profile could not be saved")
	var restored: Variant = ProfileScript.new()
	_expect(restored.load_or_create(TEST_PATH, catalog).success, "Saved profile could not be loaded")
	_expect(restored.is_completed(&"tutorial_mission_1") and restored.is_unlocked(&"mvp_test_scenario"), "Profile state changed after restart")
	_test_four_mission_campaign_flow()
	_cleanup()
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("PROFILE MANAGER TESTS PASSED: 3 test cases")
	quit(0)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_PATH + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _test_four_mission_campaign_flow() -> void:
	var source: ScenarioDefinition = load("res://data/scenarios/tutorial_mission_1.tres")
	var scenarios: Array[ScenarioDefinition] = []
	for index in 4:
		var scenario := source.duplicate(true) as ScenarioDefinition
		scenario.scenario_id = StringName("campaign_%d" % (index + 1))
		scenario.display_name = "Campaign %d" % (index + 1)
		scenario.campaign_order = index + 1
		scenario.unlock_requires = PackedStringArray() if index == 0 else PackedStringArray(["campaign_%d" % index])
		scenarios.append(scenario)
	var four_mission_catalog: Variant = CatalogScript.new()
	var result: Dictionary = four_mission_catalog.build_from_scenarios(scenarios)
	_expect(result.success, "Synthetic four-mission campaign was rejected: " + str(result.errors))
	var campaign_profile: Variant = ProfileScript.new()
	campaign_profile.create_default(four_mission_catalog)
	for index in 3:
		var current_id := StringName("campaign_%d" % (index + 1))
		var next_id := StringName("campaign_%d" % (index + 2))
		_expect(campaign_profile.is_unlocked(current_id), "Campaign mission was not unlocked in sequence")
		campaign_profile.record_mission_result(current_id, InfrastructureSystem.MissionStatus.VICTORY, four_mission_catalog)
		_expect(campaign_profile.is_unlocked(next_id), "Campaign victory did not unlock the following mission")
	var progress: Dictionary = campaign_profile.get_campaign_progress(four_mission_catalog)
	_expect(progress.completed == 3 and progress.total == 4, "Four-mission campaign progress was calculated incorrectly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
