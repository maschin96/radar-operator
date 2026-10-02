extends SceneTree

const TEST_PATH := "user://migration_test.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var catalog := ScenarioCatalog.new()
	expect(catalog.discover().success, "Catalog failed")
	var profile := ProfileManager.new()
	write_text(FileAccess.get_file_as_string("res://scripts/tests/fixtures/profile_v1.json"))
	expect(profile.load_or_create(TEST_PATH, catalog).success, "v1 profile load failed")
	expect(profile.is_completed(&"tutorial_mission_1") and profile.is_unlocked(&"tutorial_mission_2"), "Migration lost victory or next mission")
	var once := profile.profile.duplicate(true)
	expect(profile.migrate(once, catalog).profile == once, "Profile migration is not idempotent")
	expect(profile.save(TEST_PATH).success, "Migrated profile save failed")
	expect(profile.load_or_create(TEST_PATH, catalog).success and profile.profile == once, "Profile roundtrip changed progress")
	var settings := SettingsManager.new()
	write_text(FileAccess.get_file_as_string("res://scripts/tests/fixtures/settings_v1.json"))
	expect(not settings.load_or_defaults(TEST_PATH).recovered, "v1 settings rejected")
	expect(settings.settings.high_contrast and settings.settings.master_volume == 0.35 and settings.settings.atmosphere_volume == 0.35, "Settings migration lost values/defaults")
	expect(settings.migrate(settings.settings).settings == settings.settings, "Settings migration is not idempotent")
	expect(settings.save(TEST_PATH).success, "Settings migration save failed")
	expect(not settings.load_or_defaults(TEST_PATH).recovered, "Settings reload failed")
	var session := GameSession.new()
	session.initialize(load("res://data/scenarios/mvp_test_scenario.tres"))
	session.place_system(&"sensor_early_warning", Vector2(1500, 380))
	session.place_system(&"defense_medium_range", Vector2(1320, 520))
	session.start_mission()
	for tick in 75: session.advance(0.1)
	var saves := SaveManager.new()
	DirAccess.remove_absolute(TEST_PATH)
	expect(saves.save_session(session, TEST_PATH).success, "Save fixture failed")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/fixtures/save_v5.json"))
	write_text(JSON.stringify(legacy))
	var result := saves.load_session(TEST_PATH)
	expect(result.success, "v5 save migration failed: " + str(result.get("errors")))
	if result.success:
		expect(saves.snapshots_match(session.get_persistence_snapshot(), result.session.get_persistence_snapshot()), "Migration lost running mission state")
		for tick in 50:
			session.advance(0.1)
			result.session.advance(0.1)
		expect(saves.snapshots_match(session.get_persistence_snapshot(), result.session.get_persistence_snapshot()), "Migrated save continuation diverged")
		var saved := saves.save_session(result.session, TEST_PATH)
		var reloaded := saves.load_session(TEST_PATH)
		expect(saved.success and reloaded.success, "Migrated save did not roundtrip: " + str(saved) + " / " + str(reloaded.get("errors")))
	var migrated: Dictionary = saves.migrate(legacy).data
	expect(saves.migrate(migrated).data == migrated, "Save migration is not idempotent")
	for text in ['{"format_version":999}', '{broken', '[]']:
		write_text(text)
		profile.create_default(catalog)
		expect(not profile.save(TEST_PATH).success, "Protected profile overwritten")
		expect(not saves.save_session(session, TEST_PATH).success, "Protected save overwritten")
		expect(FileAccess.get_file_as_string(TEST_PATH) == text, "Protected file changed")
	for field in ["tick", "phase", "scenario_path", "placements", "player_commands"]:
		var malformed := migrated.duplicate(true)
		malformed[field] = [null]
		write_text(JSON.stringify(malformed))
		expect(not saves.load_session(TEST_PATH).success, "Malformed save accepted: " + field)
	var malformed := migrated.duplicate(true)
	malformed.player_commands = [{"tick": 0, "type": "relocate_system", "data": {"entity_id": "x", "target": {}}}]
	write_text(JSON.stringify(malformed))
	expect(not saves.load_session(TEST_PATH).success, "Malformed command accepted")
	malformed = migrated.duplicate(true)
	malformed.scenario_content_version = 999
	write_text(JSON.stringify(malformed))
	expect(not saves.load_session(TEST_PATH).success, "Future content accepted")
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix): DirAccess.remove_absolute(TEST_PATH + suffix)
	for failure in failures: push_error(failure)
	print("MIGRATION TESTS PASSED: 6 test cases" if failures.is_empty() else "MIGRATION TESTS FAILED")
	quit(0 if failures.is_empty() else 1)

func write_text(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
