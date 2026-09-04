class_name AppShell
extends Control

const CatalogScript := preload("res://scripts/core/scenario_catalog.gd")
const ProfileScript := preload("res://scripts/systems/profile_manager.gd")
const SettingsScript := preload("res://scripts/systems/settings_manager.gd")
const GameplayScene := preload("res://scenes/app/main.tscn")
const RadarTheme := preload("res://data/ui/radar_theme.tres")
const PROFILE_PATH := "user://radar_operator_profile.json"
const SETTINGS_PATH := "user://radar_operator_settings.json"

var catalog: Variant
var profile_manager: Variant
var settings_manager: Variant
var gameplay: Variant
var profile_path := PROFILE_PATH
var settings_path := SETTINGS_PATH
var _view: StringName = &"boot"
var _content: VBoxContainer
var _status: Label
var _menu_panel: CenterContainer
var _menu_background: ColorRect
var _pending_binding_action: StringName
var _pending_binding_button: Button
var _debriefing_data: Dictionary = {}


func _ready() -> void:
	theme = RadarTheme
	_build_shell()
	catalog = CatalogScript.new()
	var catalog_result: Dictionary = catalog.discover()
	if not catalog_result.success:
		_show_error("Inhaltskatalog konnte nicht geladen werden:\n" + "\n".join(catalog_result.errors))
		return
	profile_manager = ProfileScript.new()
	var profile_result: Dictionary = profile_manager.load_or_create(profile_path, catalog)
	if not profile_result.success:
		var recovery_path := profile_path + ".corrupt"
		if FileAccess.file_exists(profile_path):
			DirAccess.rename_absolute(profile_path, recovery_path)
		profile_manager.create_default(catalog)
		profile_manager.save(profile_path)
		_status.text = "Beschädigtes Profil wurde als .corrupt gesichert; ein neues Profil ist aktiv."
	settings_manager = SettingsScript.new()
	var settings_result: Dictionary = settings_manager.load_or_defaults(settings_path)
	if settings_result.recovered:
		_status.text = "Ungültige Einstellungen wurden durch sichere Standardwerte ersetzt."
	show_main_menu()


func get_current_view() -> StringName:
	return _view


func get_mission_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if catalog == null or profile_manager == null:
		return cards
	for scenario in catalog.scenarios:
		cards.append({
			"scenario_id": scenario.scenario_id,
			"display_name": scenario.display_name,
			"summary": scenario.summary,
			"duration": scenario.expected_duration_minutes,
			"learning_objectives": scenario.learning_objectives,
			"unlocked": profile_manager.is_unlocked(scenario.scenario_id),
			"completed": profile_manager.is_completed(scenario.scenario_id),
			"best_result": profile_manager.get_mission_result(scenario.scenario_id),
		})
	return cards


func show_main_menu() -> void:
	_clear_content()
	_view = &"main_menu"
	_add_heading("RADAR OPERATOR", "TAKTISCHE LUFTLAGE-SIMULATION")
	var continue_button := _add_button("FORTSETZEN", _continue_last_mission)
	continue_button.disabled = String(profile_manager.profile.get("last_played_mission", "")).is_empty()
	var missions_button := _add_button("MISSIONEN", show_missions)
	_add_button("EINSTELLUNGEN", show_settings)
	_add_button("MITWIRKENDE", show_credits)
	var quit_button := _add_button("BEENDEN", _quit_application)
	quit_button.visible = not DisplayServer.get_name().contains("headless")
	(continue_button if not continue_button.disabled else missions_button).grab_focus()


func show_missions() -> void:
	_clear_content()
	_view = &"missions"
	var progress: Dictionary = profile_manager.get_campaign_progress(catalog)
	_add_heading("MISSIONEN", "MINI-KAMPAGNE  ·  %d/%d ABGESCHLOSSEN" % [progress.completed, progress.total])
	for card in get_mission_cards():
		var state := "ABGESCHLOSSEN" if card.completed else ("VERFÜGBAR" if card.unlocked else "GESPERRT")
		var result_label := _mission_result_label(int(card.best_result))
		var button := _add_button("%02d  %s  ·  %s%s  ·  ca. %d min\n%s" % [
			catalog.get_scenario(card.scenario_id).campaign_order,
			card.display_name,
			state,
			" · " + result_label if not result_label.is_empty() else "",
			card.duration,
			card.summary,
		], launch_mission.bind(card.scenario_id))
		button.disabled = not card.unlocked
		button.tooltip_text = "Lernziele: " + ", ".join(card.learning_objectives)
	_add_button("ZURÜCK", show_main_menu)


func show_settings() -> void:
	_clear_content()
	_view = &"settings"
	_add_heading("EINSTELLUNGEN", "Änderungen werden erst mit ÜBERNEHMEN dauerhaft angewendet.")
	var draft: Dictionary = settings_manager.begin_edit()
	var fullscreen := CheckButton.new()
	fullscreen.text = "Vollbild"
	fullscreen.button_pressed = draft.window_mode == "fullscreen"
	fullscreen.toggled.connect(func(enabled: bool) -> void: settings_manager.update_draft({"window_mode": "fullscreen" if enabled else "windowed"}))
	_content.add_child(fullscreen)
	_add_setting_toggle("Hoher Kontrast", "high_contrast", bool(draft.high_contrast))
	_add_setting_toggle("Reduzierte Effekte", "reduced_effects", bool(draft.reduced_effects))
	_add_setting_toggle("Warntöne", "alerts_enabled", bool(draft.alerts_enabled))
	_add_volume_slider("Gesamtlautstärke", "master_volume", float(draft.master_volume))
	_add_volume_slider("Warnlautstärke", "alerts_volume", float(draft.alerts_volume))
	_add_volume_slider("Meldungslautstärke", "voice_volume", float(draft.voice_volume))
	var bindings_title := Label.new()
	bindings_title.text = "TASTENBELEGUNG"
	bindings_title.add_theme_color_override("font_color", Color(0.36, 0.93, 0.65))
	_content.add_child(bindings_title)
	for action in SettingsManager.ACTIONS:
		_add_binding_button(StringName(action), int(draft.action_bindings[action]))
	_add_button("ÜBERNEHMEN", _commit_settings)
	_add_button("ABBRECHEN", _cancel_settings)
	_add_button("STANDARDWERTE", _reset_settings)


func show_credits() -> void:
	_clear_content()
	_view = &"credits"
	_add_heading("MITWIRKENDE", "Radar Operator\nEin freies Projekt unter GPL-3.0-or-later.\nAlle Systeme und Werte sind fiktiv und abstrahiert.")
	_add_button("ZURÜCK", show_main_menu)


func launch_mission(scenario_id: StringName) -> bool:
	if catalog == null or profile_manager == null or not profile_manager.is_unlocked(scenario_id):
		_status.text = "Mission ist nicht freigeschaltet."
		return false
	var scenario: Variant = catalog.get_scenario(scenario_id)
	if scenario == null:
		_status.text = "Mission '%s' fehlt im Inhaltskatalog." % scenario_id
		return false
	_view = &"gameplay"
	_menu_background.visible = false
	_menu_panel.visible = false
	gameplay = GameplayScene.instantiate()
	gameplay.initial_scenario = scenario
	gameplay.request_main_menu.connect(_leave_gameplay)
	%GameplayHost.add_child(gameplay)
	gameplay.apply_settings(settings_manager.settings)
	gameplay.mission_debriefing_ready.connect(_on_mission_debriefing_ready)
	profile_manager.profile["last_played_mission"] = String(scenario_id)
	profile_manager.save(profile_path)
	return true


func _continue_last_mission() -> void:
	launch_mission(StringName(profile_manager.profile.get("last_played_mission", "")))


func _leave_gameplay() -> void:
	if gameplay != null:
		gameplay.queue_free()
		gameplay = null
	_menu_background.visible = true
	_menu_panel.visible = true
	show_main_menu()


func _on_mission_debriefing_ready(data: Dictionary) -> void:
	var scenario_id := StringName(data.get("scenario_id", ""))
	var status := int(data.get("status", InfrastructureSystem.MissionStatus.DEFEAT))
	profile_manager.record_mission_result(scenario_id, status, catalog)
	profile_manager.save(profile_path)
	show_debriefing(data)


func show_debriefing(data: Dictionary) -> void:
	_debriefing_data = data.duplicate(true)
	if gameplay != null:
		gameplay.queue_free()
		gameplay = null
	_menu_background.visible = true
	_menu_panel.visible = true
	_clear_content()
	_view = &"debriefing"
	var scenario_id := StringName(data.get("scenario_id", ""))
	var scenario: ScenarioDefinition = catalog.get_scenario(scenario_id)
	var status := int(data.get("status", InfrastructureSystem.MissionStatus.DEFEAT))
	var metrics: Dictionary = data.get("metrics", {})
	var outcome := "MISSION ERFÜLLT" if status == InfrastructureSystem.MissionStatus.VICTORY else "MISSION VERFEHLT"
	_add_heading(outcome, scenario.display_name if scenario != null else String(scenario_id))
	var report := Label.new()
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.custom_minimum_size.y = 150.0
	report.text = "%s\n\nBedrohungen: %d · neutralisiert: %d · Ziel erreicht: %d\nAbwehr erfolgreich: %d · fehlgeschlagen: %d\nInfrastruktur erhalten: %d · zerstört: %d" % [
		String(data.get("summary", "Keine missionsspezifische Auswertung hinterlegt.")),
		int(metrics.get("threats_entered", 0)), int(metrics.get("threats_neutralized", 0)), int(metrics.get("targets_reached", 0)),
		int(metrics.get("engagements_succeeded", 0)), int(metrics.get("engagements_failed", 0)),
		int(metrics.get("infrastructure_survived", 0)), int(metrics.get("infrastructure_destroyed", 0)),
	]
	_content.add_child(report)
	_add_button("MISSION WIEDERHOLEN", launch_mission.bind(scenario_id))
	var next_scenario: ScenarioDefinition = profile_manager.get_next_unlocked_scenario(scenario_id, catalog)
	if next_scenario != null:
		_add_button("WEITER: %s" % next_scenario.display_name.to_upper(), launch_mission.bind(next_scenario.scenario_id))
	_add_button("ZUR MISSIONSÜBERSICHT", show_missions)
	_add_button("ZUM HAUPTMENÜ", show_main_menu)


func get_debriefing_data() -> Dictionary:
	return _debriefing_data.duplicate(true)


func _mission_result_label(status: int) -> String:
	if status == InfrastructureSystem.MissionStatus.VICTORY:
		return "BESTES ERGEBNIS: SIEG"
	if status == InfrastructureSystem.MissionStatus.DEFEAT:
		return "BESTES ERGEBNIS: NIEDERLAGE"
	return ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if not _pending_binding_action.is_empty():
		var result: Dictionary = settings_manager.set_draft_binding(_pending_binding_action, event.physical_keycode)
		if result.success:
			_pending_binding_button.text = "%s: %s" % [_action_label(_pending_binding_action), OS.get_keycode_string(event.physical_keycode)]
			_status.text = "Tastenbelegung aktualisiert. Mit ÜBERNEHMEN speichern."
		else:
			_status.text = "Tastenkonflikt: " + "; ".join(result.errors)
		_pending_binding_action = &""
		_pending_binding_button = null
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE:
		return
	match _view:
		&"gameplay": _leave_gameplay()
		&"missions", &"settings", &"credits", &"debriefing": show_main_menu()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color(0.012, 0.027, 0.023, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_menu_background = background
	var center := CenterContainer.new()
	center.name = "MenuPanel"
	center.unique_name_in_owner = true
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_menu_panel = center
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720.0, 520.0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.8, 0.72, 0.42))
	_status.custom_minimum_size.y = 40.0
	_content.add_child(_status)


func _clear_content() -> void:
	for child in _content.get_children():
		if child != _status:
			child.queue_free()
	_status.text = ""


func _add_heading(title: String, subtitle: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.36, 0.93, 0.65))
	_content.add_child(heading)
	var subheading := Label.new()
	subheading.text = subtitle
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subheading.custom_minimum_size.y = 54.0
	_content.add_child(subheading)


func _add_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 46.0
	button.pressed.connect(callback)
	_content.add_child(button)
	return button


func _add_setting_toggle(label: String, key: String, value: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = value
	toggle.toggled.connect(func(enabled: bool) -> void: settings_manager.update_draft({key: enabled}))
	_content.add_child(toggle)


func _add_volume_slider(label: String, key: String, value: float) -> void:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 220.0
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(next_value: float) -> void: settings_manager.update_draft({key: next_value}))
	row.add_child(slider)
	_content.add_child(row)


func _add_binding_button(action: StringName, keycode: int) -> void:
	var button := Button.new()
	button.text = "%s: %s" % [_action_label(action), OS.get_keycode_string(keycode)]
	button.custom_minimum_size.y = 42.0
	button.pressed.connect(func() -> void:
		_pending_binding_action = action
		_pending_binding_button = button
		_status.text = "Neue Taste für %s drücken …" % _action_label(action)
	)
	_content.add_child(button)


func _action_label(action: StringName) -> String:
	return {
		&"simulation_pause": "Pause/Fortsetzen",
		&"simulation_speed_1": "Geschwindigkeit 1×",
		&"simulation_speed_2": "Geschwindigkeit 2×",
		&"simulation_speed_4": "Geschwindigkeit 4×",
		&"toggle_briefing": "Briefing",
	}.get(action, String(action))


func _commit_settings() -> void:
	var result: Dictionary = settings_manager.commit_draft(settings_path)
	if not result.success:
		_status.text = "Einstellungen ungültig: " + "; ".join(result.errors)
		return
	show_main_menu()


func _cancel_settings() -> void:
	settings_manager.cancel_draft()
	show_main_menu()


func _reset_settings() -> void:
	settings_manager.reset_draft()
	var result: Dictionary = settings_manager.commit_draft(settings_path)
	if not result.success:
		_status.text = "Standardwerte konnten nicht gespeichert werden: " + "; ".join(result.errors)
		return
	show_settings()


func _show_error(message: String) -> void:
	_clear_content()
	_view = &"error"
	_add_heading("STARTFEHLER", message)


func _quit_application() -> void:
	get_tree().quit()
