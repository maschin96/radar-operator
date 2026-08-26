class_name MainScreen
extends Control

const Log := preload("res://scripts/core/app_log.gd")
const Loader := preload("res://scripts/core/scenario_loader.gd")
const Session := preload("res://scripts/app/game_session.gd")
const Report := preload("res://scripts/systems/mission_report.gd")
const Saves := preload("res://scripts/systems/save_manager.gd")
const Tutorial := preload("res://scripts/ui/tutorial_controller.gd")
const SCENARIO_PATH := "res://data/scenarios/tutorial_mission_1.tres"
const SAVE_PATH := "user://radar_operator_save.json"

@onready var _map: TacticalMap = %TacticalMap
@onready var _catalog: VBoxContainer = %Catalog
@onready var _phase_label: Label = %Phase
@onready var _budget_label: Label = %Budget
@onready var _time_label: Label = %Time
@onready var _status_label: Label = %BuildStatus
@onready var _details: RichTextLabel = %Details
@onready var _remove_button: Button = %RemoveSelected
@onready var _event_list: ItemList = %EventList
@onready var _start_button: Button = %StartMission
@onready var _auto_release: CheckButton = %AutoRelease
@onready var _restart_same: Button = %RestartSame
@onready var _restart_new: Button = %RestartNew
@onready var _save_button: Button = %SaveGame
@onready var _load_button: Button = %LoadGame
@onready var _audio: AudioManager = %AudioManager
@onready var _briefing_shade: ColorRect = %BriefingShade
@onready var _briefing_panel: PanelContainer = %BriefingPanel
@onready var _briefing_title: Label = %BriefingTitle
@onready var _briefing_text: Label = %BriefingText
@onready var _tutorial_panel: PanelContainer = %TutorialPanel
@onready var _tutorial_progress: Label = %TutorialProgress
@onready var _tutorial_title: Label = %TutorialTitle
@onready var _tutorial_instruction: Label = %TutorialInstruction

var session: GameSession
var mission_report: MissionReport
var tutorial: TutorialController
var _selected_definition_id: StringName
var _selected_object_kind: StringName
var _selected_object_id: StringName
var _catalog_buttons: Dictionary = {}


func _ready() -> void:
	var result: Dictionary = Loader.new().load_scenario(SCENARIO_PATH)
	if not result.success:
		_status_label.text = "Szenariofehler: " + str(result.errors)
		push_error(_status_label.text)
		return
	_create_session(result.scenario)
	_configure_briefing(result.scenario)
	_setup_tutorial(result.scenario)
	_map.map_clicked.connect(_on_map_clicked)
	_map.map_hovered.connect(_on_map_hovered)
	_map.object_selected.connect(_on_object_selected)
	_start_button.pressed.connect(start_mission)
	%Pause.pressed.connect(_set_time_scale.bind(0.0))
	%Speed1.pressed.connect(_set_time_scale.bind(1.0))
	%Speed2.pressed.connect(_set_time_scale.bind(2.0))
	%Speed4.pressed.connect(_set_time_scale.bind(4.0))
	_remove_button.pressed.connect(_remove_selected)
	_auto_release.toggled.connect(_on_auto_release_toggled)
	_restart_same.pressed.connect(restart_mission.bind(true))
	_restart_new.pressed.connect(restart_mission.bind(false))
	_save_button.pressed.connect(save_game)
	_load_button.pressed.connect(load_game)
	%Close.pressed.connect(_close_briefing)
	%TutorialSkip.pressed.connect(_skip_tutorial)
	%HighContrast.toggled.connect(_on_accessibility_changed)
	%ReducedEffects.toggled.connect(_on_accessibility_changed)
	%AlertsEnabled.toggled.connect(func(enabled: bool) -> void: _audio.alerts_enabled = enabled)
	_build_catalog()
	_refresh_ui()
	Log.info("Main", "Playable control room initialized")


func _process(delta: float) -> void:
	if session != null:
		session.advance(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or session == null:
		return
	match event.keycode:
		KEY_SPACE: _set_time_scale(0.0 if session.simulation.get_time_scale() > 0.0 else 1.0)
		KEY_1: _set_time_scale(1.0)
		KEY_2: _set_time_scale(2.0)
		KEY_4: _set_time_scale(4.0)
		KEY_B: _set_briefing_visible(not _briefing_panel.visible)


func select_build_definition(definition_id: StringName) -> bool:
	if session == null or not _catalog_buttons.has(definition_id):
		return false
	_selected_definition_id = definition_id
	_selected_object_id = &""
	for id in _catalog_buttons:
		(_catalog_buttons[id] as Button).button_pressed = id == definition_id
	_status_label.text = "Platz für %s wählen." % _definition(definition_id).display_name
	_notify_tutorial(&"definition_selected", {"definition_id": definition_id})
	return true


func place_selected_at(world_position: Vector2) -> Dictionary:
	if _selected_definition_id.is_empty():
		return {"success": false, "reasons": ["no_selection"]}
	var result := session.place_system(_selected_definition_id, world_position)
	_status_label.text = "%s platziert." % _definition(_selected_definition_id).display_name if result.success else "Ungültige Position: " + ", ".join(result.reasons)
	if result.success:
		_notify_tutorial(&"system_placed", {"definition_id": _selected_definition_id})
	return result


func start_mission() -> Dictionary:
	if session == null:
		return {"success": false, "reason": "no_session"}
	var result := session.start_mission()
	if not result.success:
		_status_label.text = "Mindestens ein Sensor und ein Abwehrsystem werden benötigt."
	else:
		_selected_definition_id = &""
		_map.clear_placement_preview()
		_status_label.text = "Einsatz läuft. Kontakte werden ausgewertet."
		_notify_tutorial(&"mission_started")
	_refresh_ui()
	return result


func get_ui_state() -> Dictionary:
	return {
		"catalog_count": _catalog_buttons.size(),
		"phase_text": _phase_label.text,
		"budget_text": _budget_label.text,
		"event_count": _event_list.item_count,
		"tutorial_active": tutorial != null and tutorial.is_active(),
		"tutorial_step": tutorial.get_current_index() if tutorial != null else -1,
		"tutorial_steps": tutorial.get_step_count() if tutorial != null else 0,
	}


func restart_mission(same_seed: bool) -> void:
	var next_scenario := session.scenario.duplicate(true) as ScenarioDefinition
	if not same_seed:
		next_scenario.seed += 1
	_event_list.clear()
	_selected_definition_id = &""
	_selected_object_id = &""
	mission_report = null
	_create_session(next_scenario)
	_configure_briefing(next_scenario)
	_setup_tutorial(next_scenario)
	_build_catalog()
	_restart_same.visible = false
	_restart_new.visible = false
	_set_briefing_visible(true)
	_refresh_ui()


func save_game(path: String = SAVE_PATH) -> Dictionary:
	var result := Saves.new().save_session(session, path)
	_status_label.text = "Spielstand gespeichert." if result.success else "Speichern fehlgeschlagen: " + str(result.errors)
	return result


func load_game(path: String = SAVE_PATH) -> Dictionary:
	var result := Saves.new().load_session(path)
	if not result.success:
		_status_label.text = "Laden fehlgeschlagen: " + str(result.errors)
		return result
	_event_list.clear()
	_selected_definition_id = &""
	_selected_object_id = &""
	mission_report = null
	session = result.session
	session.state_changed.connect(_refresh_ui)
	session.event_added.connect(_on_event_added)
	session.mission_finished.connect(_on_mission_finished)
	_configure_briefing(session.scenario)
	_setup_tutorial(session.scenario)
	if session.phase != GameSession.Phase.PREPARATION or not session.placement.get_placements().is_empty():
		tutorial.skip()
	_build_catalog()
	_status_label.text = "Spielstand geladen."
	_refresh_ui()
	return result


func _build_catalog() -> void:
	for child in _catalog.get_children():
		child.queue_free()
	_catalog_buttons.clear()
	for definition in session.placement.get_catalog():
		var button := Button.new()
		button.toggle_mode = true
		button.text = "%s\n%d" % [definition.display_name, definition.purchase_cost]
		button.tooltip_text = "%s\nReichweite: %.0f" % [definition.description, session.placement.get_definition_range(definition.id)]
		button.pressed.connect(select_build_definition.bind(definition.id))
		_catalog.add_child(button)
		_catalog_buttons[definition.id] = button


func _refresh_ui() -> void:
	if session == null:
		return
	var snapshot := session.get_snapshot()
	_phase_label.text = ["VORBEREITUNG", "EINSATZ", "AUSWERTUNG"][int(snapshot.phase)]
	_budget_label.text = "BUDGET %04d" % int(snapshot.budget)
	var total_seconds := int(snapshot.simulation_time)
	_time_label.text = "T+%02d:%02d  %.0f×" % [total_seconds / 60, total_seconds % 60, float(snapshot.time_scale)]
	_start_button.disabled = snapshot.phase != GameSession.Phase.PREPARATION
	for button in _catalog_buttons.values():
		button.disabled = snapshot.phase != GameSession.Phase.PREPARATION
	_map.set_world_state(snapshot.infrastructure, snapshot.placements, snapshot.tracks)
	_refresh_details(snapshot)
	_update_tutorial_from_snapshot(snapshot)


func _on_map_clicked(world_position: Vector2) -> void:
	place_selected_at(world_position)


func _on_map_hovered(world_position: Vector2) -> void:
	if session == null or _selected_definition_id.is_empty() or session.phase != GameSession.Phase.PREPARATION:
		return
	var preview := session.placement.preview_placement(_selected_definition_id, world_position)
	_map.set_placement_preview(world_position, float(preview.range), bool(preview.valid))


func _on_object_selected(kind: StringName, object_id: StringName) -> void:
	_selected_definition_id = &""
	_selected_object_kind = kind
	_selected_object_id = object_id
	_map.clear_placement_preview()
	_notify_tutorial(&"track_selected", {"object_kind": kind, "object_id": object_id})
	_refresh_ui()


func _refresh_details(snapshot: Dictionary) -> void:
	_remove_button.disabled = true
	if _selected_object_id.is_empty():
		_details.text = "Kein Objekt ausgewählt.\n\nTracks zeigen geschätzte Position und Unsicherheit, nicht die wahre Zielposition."
		return
	var collection: Array
	match _selected_object_kind:
		&"track": collection = snapshot.tracks
		&"system": collection = snapshot.placements
		&"infrastructure": collection = snapshot.infrastructure
	for object in collection:
		if object.id != _selected_object_id:
			continue
		if _selected_object_kind == &"track":
			_details.text = "[b]%s[/b]\nKlassifikation: %s\nKonfidenz: %.0f%%\nUnsicherheit: %.1f\nMessungen: %d\nSensoren: %d\n\nLetzte Fusion:\n%s" % [object.id, object.classification, object.classification_confidence * 100.0, object.uncertainty_radius, object.measurement_count, object.reporting_sensors.size(), str(object.last_update_summary)]
		elif _selected_object_kind == &"system":
			var definition := _definition(object.definition_id)
			_details.text = "[b]%s[/b]\nTyp: %s\nPosition: %.0f / %.0f\nReichweite: %.0f" % [object.id, definition.display_name, object.position.x, object.position.y, session.placement.get_definition_range(object.definition_id)]
			_remove_button.disabled = session.phase != GameSession.Phase.PREPARATION
		else:
			_details.text = "[b]%s[/b]\nIntegrität: %.0f / %.0f\nEnergie: %s\nStatus: %s" % [object.id, object.integrity, object.maximum_integrity, "ONLINE" if object.powered else "AUS", InfrastructureState.Status.keys()[object.status]]
		return
	_selected_object_id = &""
	_details.text = "Objekt nicht mehr verfügbar."


func _remove_selected() -> void:
	if _selected_object_kind == &"system" and session.remove_system(_selected_object_id):
		_selected_object_id = &""
		_map.set_selected_object(&"", &"")
		_refresh_ui()


func _on_auto_release_toggled(enabled: bool) -> void:
	if session != null:
		session.set_defense_rules({"automatic_release": enabled})


func _on_event_added(event: Dictionary) -> void:
	_audio.handle_event(event)
	var seconds := int(event.simulation_time)
	_event_list.add_item("%02d:%02d  %-14s  %s" % [seconds / 60, seconds % 60, event.category, event.type])
	while _event_list.item_count > 80:
		_event_list.remove_item(0)
	_event_list.select(_event_list.item_count - 1)
	_event_list.ensure_current_is_visible()


func _set_briefing_visible(visible: bool) -> void:
	_briefing_panel.visible = visible
	_briefing_shade.visible = visible
	if not visible:
		_map.grab_focus()


func _close_briefing() -> void:
	_set_briefing_visible(false)
	_notify_tutorial(&"briefing_closed")


func _set_time_scale(scale: float) -> void:
	if session == null:
		return
	session.set_time_scale(scale)
	if scale > 0.0:
		_notify_tutorial(&"simulation_resumed", {"time_scale": scale})
	_refresh_ui()


func _on_accessibility_changed(_enabled: bool) -> void:
	_map.set_accessibility(%HighContrast.button_pressed, %ReducedEffects.button_pressed)


func _on_mission_finished(_status: int) -> void:
	_notify_tutorial(&"mission_finished")
	mission_report = Report.new()
	mission_report.build(session.scenario, session.events, session.replay_frames, session.infrastructure.get_infrastructure())
	var metrics := mission_report.get_metrics()
	_details.text = "[b]MISSIONSAUSWERTUNG[/b]\nBedrohungen: %d\nNeutralisiert: %d\nZiel erreicht: %d\nAbwehr erfolgreich: %d\nAbwehr fehlgeschlagen: %d\nInfrastruktur erhalten: %d\nInfrastruktur zerstört: %d\n\nEreignisse können in der Zeitleiste ausgewählt und gefiltert werden." % [metrics.threats_entered, metrics.threats_neutralized, metrics.targets_reached, metrics.engagements_succeeded, metrics.engagements_failed, metrics.infrastructure_survived, metrics.infrastructure_destroyed]
	_restart_same.visible = true
	_restart_new.visible = true


func _create_session(scenario_definition: ScenarioDefinition) -> void:
	session = Session.new()
	session.initialize(scenario_definition)
	session.state_changed.connect(_refresh_ui)
	session.event_added.connect(_on_event_added)
	session.mission_finished.connect(_on_mission_finished)


func _configure_briefing(scenario_definition: ScenarioDefinition) -> void:
	_map.set_mission_geometry(
		scenario_definition.world_size,
		scenario_definition.placement_zones,
		scenario_definition.blocked_zones
	)
	_briefing_title.text = scenario_definition.display_name.to_upper()
	_briefing_text.text = "AUFTRAG\n%s\n\nZIEL\nSchützen Sie die markierte kritische Infrastruktur bis T+%02d:%02d.\n\nBEDIENUNG\nMittlere Maustaste: Karte verschieben · Mausrad: Zoom · Leertaste: Pause · 1/2/4: Zeitfaktor · B: Briefing" % [
		scenario_definition.briefing,
		int(scenario_definition.mission_duration) / 60,
		int(scenario_definition.mission_duration) % 60,
	]


func _setup_tutorial(scenario_definition: ScenarioDefinition) -> void:
	tutorial = Tutorial.new()
	tutorial.step_changed.connect(_on_tutorial_step_changed)
	tutorial.tutorial_completed.connect(_on_tutorial_completed)
	tutorial.initialize(scenario_definition.tutorial_steps)
	_tutorial_panel.visible = tutorial.is_active()


func _notify_tutorial(action: StringName, data: Dictionary = {}) -> void:
	if tutorial == null:
		return
	_handle_tutorial_result(tutorial.notify(action, data))


func _update_tutorial_from_snapshot(snapshot: Dictionary) -> void:
	if tutorial == null:
		return
	_handle_tutorial_result(tutorial.update_from_snapshot(snapshot))


func _handle_tutorial_result(result: Dictionary) -> void:
	if not bool(result.get("advanced", false)):
		return
	var completed_step: Dictionary = result.get("completed_step", {})
	if bool(completed_step.get("pause_on_complete", false)) and session.phase == GameSession.Phase.RUNNING:
		session.set_time_scale(0.0)
		_status_label.text = "Tutorial-Pause: Wählen Sie den neu erkannten Track aus."


func _on_tutorial_step_changed(step: Dictionary, index: int, total: int) -> void:
	_tutorial_panel.visible = true
	_tutorial_progress.text = "TUTORIAL MISSION 1  ·  SCHRITT %d/%d" % [index + 1, total]
	_tutorial_title.text = String(step.get("title", "Lernziel"))
	_tutorial_instruction.text = String(step.get("instruction", ""))


func _on_tutorial_completed() -> void:
	_tutorial_panel.visible = false


func _skip_tutorial() -> void:
	if tutorial != null:
		tutorial.skip()
	_status_label.text = "Tutorial-Hinweise ausgeblendet. Die Mission bleibt aktiv."


func _definition(definition_id: StringName) -> EntityDefinition:
	for definition in session.scenario.definitions:
		if definition is EntityDefinition and definition.id == definition_id:
			return definition
	return null
