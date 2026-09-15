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
	_expect(cards.size() >= 3, "Mission selection did not list both catalog missions")
	_expect(cards[0].unlocked, "Fresh profile did not unlock the tutorial entry")
	_expect(not cards[1].unlocked, "Fresh profile unexpectedly unlocked the second mission")
	_expect(app.launch_mission(&"tutorial_mission_1"), "Unlocked tutorial mission could not be launched")
	await process_frame
	_expect(app.get_current_view() == &"gameplay", "Mission launch did not enter gameplay")
	_expect(app.gameplay != null and app.gameplay.session.scenario.scenario_id == &"tutorial_mission_1", "Mission launch selected the wrong scenario")
	_expect(not app._menu_background.visible and not app._menu_panel.visible, "Menu layer still obscures the gameplay field")
	var gameplay: MainScreen = app.gameplay
	gameplay._close_briefing()
	gameplay.select_build_definition(&"sensor_early_warning")
	_expect(gameplay.place_selected_at(Vector2(880.0, 470.0)).success, "Campaign tutorial sensor placement failed")
	gameplay.select_build_definition(&"defense_short_range")
	_expect(gameplay.place_selected_at(Vector2(1120.0, 700.0)).success, "Campaign tutorial defense placement failed")
	_expect(gameplay.start_mission().success, "Campaign tutorial could not start")
	var session := gameplay.session
	for tick in 1500:
		if session.phase == GameSession.Phase.ENDED:
			break
		session.set_time_scale(1.0)
		session.advance(GameSession.TICK_DURATION)
	_expect(session.phase == GameSession.Phase.ENDED, "Real campaign mission did not reach debriefing")

	await process_frame
	_expect(app.get_current_view() == &"debriefing", "Finished mission did not enter the debriefing view")
	_expect(app.gameplay == null and app._menu_background.visible and app._menu_panel.visible, "Debriefing transition left gameplay active")
	_expect(app.get_debriefing_data().summary == session.scenario.victory_debriefing, "Debriefing did not retain its result data")
	var completed_cards: Array[Dictionary] = app.get_mission_cards()
	_expect(completed_cards[0].completed, "Debriefing did not persist mission completion")
	_expect(completed_cards[1].unlocked, "Debriefing did not unlock the next campaign mission")
	_expect(app.launch_mission(&"tutorial_mission_2"), "Debriefing could not transition into the next campaign mission")
	await process_frame
	_expect(app.get_current_view() == &"gameplay" and app.gameplay.session.scenario.scenario_id == &"tutorial_mission_2", "Next-mission transition selected the wrong scenario")
	app._on_mission_debriefing_ready({
		"scenario_id": &"tutorial_mission_2",
		"status": InfrastructureSystem.MissionStatus.DEFEAT,
		"summary": "Die Schutzgüter wurden nicht erhalten.",
		"metrics": {},
	})
	await process_frame
	_expect(app.get_current_view() == &"debriefing", "Defeat did not open debriefing")
	var repeat_button := app.get_viewport().gui_get_focus_owner() as Button
	_expect(repeat_button != null and repeat_button.text == "MISSION WIEDERHOLEN", "Debriefing did not focus the keyboard repeat action")
	if repeat_button != null:
		repeat_button.pressed.emit()
	await process_frame
	_expect(app.get_current_view() == &"gameplay", "Defeated mission could not be replayed")
	app.queue_free()
	await process_frame
	app = scene.instantiate()
	app.profile_path = profile_path
	app.settings_path = settings_path
	root.add_child(app)
	await process_frame
	var restored_cards: Array[Dictionary] = app.get_mission_cards()
	_expect(restored_cards[0].completed and restored_cards[1].unlocked, "App restart lost campaign progress")
	_expect(restored_cards[1].best_result == InfrastructureSystem.MissionStatus.DEFEAT, "App restart lost defeat result")
	app.queue_free()
	await process_frame
	var future: Dictionary = SettingsManager.new().get_defaults()
	future.format_version = SettingsManager.FORMAT_VERSION + 1
	var future_text := JSON.stringify(future)
	var settings_file := FileAccess.open(settings_path, FileAccess.WRITE)
	settings_file.store_string(future_text)
	settings_file.close()
	app = scene.instantiate()
	app.profile_path = profile_path
	app.settings_path = settings_path
	root.add_child(app)
	await process_frame
	_expect(app.get_current_view() == &"main_menu", "Future settings blocked app startup")
	_expect(app._status.text.contains("Originaldatei") and app._status.text.contains("umbenennen"), "Main menu hid settings recovery guidance")
	app.show_settings()
	app.settings_manager.update_draft({"high_contrast": true})
	app._commit_settings()
	_expect(app.get_current_view() == &"settings" and app._status.text.contains("Originaldatei"), "Failed settings commit hid recovery guidance")
	_expect(not app.settings_manager.settings.high_contrast, "Failed UI commit applied settings")
	app._reset_settings()
	_expect(FileAccess.get_file_as_string(settings_path) == future_text, "UI reset overwrote future settings")
	app.queue_free()
	await process_frame
	for path in [profile_path, settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("APP SHELL TESTS PASSED: 5 test cases")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
