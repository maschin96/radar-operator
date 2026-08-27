extends SceneTree

const APP_SHELL_PATH := "res://scenes/app/app_shell.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile_path := "user://app_shell_test_profile.json"
	var settings_path := "user://app_shell_test_settings.json"
	for path in [profile_path, settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var scene := load(APP_SHELL_PATH) as PackedScene
	var app: Variant = scene.instantiate()
	app.profile_path = profile_path
	app.settings_path = settings_path
	root.add_child(app)
	await process_frame
	_expect(app.get_current_view() == &"main_menu", "Application did not start in the main menu")
	app.show_missions()
	await process_frame
	var cards: Array[Dictionary] = app.get_mission_cards()
	_expect(cards.size() == 2, "Mission selection did not list both catalog missions")
	_expect(cards[0].unlocked, "Fresh profile did not unlock the tutorial entry")
	_expect(not cards[1].unlocked, "Fresh profile unexpectedly unlocked the second mission")
	_expect(app.launch_mission(&"tutorial_mission_1"), "Unlocked tutorial mission could not be launched")
	await process_frame
	_expect(app.get_current_view() == &"gameplay", "Mission launch did not enter gameplay")
	_expect(app.gameplay != null and app.gameplay.session.scenario.scenario_id == &"tutorial_mission_1", "Mission launch selected the wrong scenario")
	_expect(not app._menu_background.visible and not app._menu_panel.visible, "Menu layer still obscures the gameplay field")
	for path in [profile_path, settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("APP SHELL TESTS PASSED: 1 test case")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
