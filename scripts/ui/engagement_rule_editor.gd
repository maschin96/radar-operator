class_name EngagementRuleEditor
extends ConfirmationDialog

const PRESETS := [
	preload("res://data/rules/standard.tres"),
	preload("res://data/rules/manual.tres"),
	preload("res://data/rules/confirmed.tres"),
]
const CLASSIFICATIONS := ["unknown", "air_contact", "suspicious", "hostile"]

var session: GameSession
var profile_name := LineEdit.new()
var minimum := OptionButton.new()
var automatic := CheckButton.new()
var redundant := CheckButton.new()
var preview_button := Button.new()
var explanation := RichTextLabel.new()
var priorities := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _priority_inputs: Dictionary = {}
var _profile_id: String = "custom"
var _previous_speed: float = 0.0
var _previewed: bool = false


func _ready() -> void:
	title = "Einsatzregel-Profil"
	size = Vector2i(620, 620)
	get_ok_button().text = "AKTIVIEREN"
	get_cancel_button().text = "VERWERFEN"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	_scroll.add_child(layout)
	var preset_picker := OptionButton.new()
	preset_picker.add_item("Vorlage wählen …")
	for preset in PRESETS:
		preset_picker.add_item(preset.display_name)
	preset_picker.item_selected.connect(func(index: int) -> void:
		if index > 0:
			set_draft(PRESETS[index - 1].to_dictionary())
	)
	layout.add_child(preset_picker)
	_add_label(layout, "Profilname – wird zusammen mit dem Spielstand gespeichert")
	profile_name.placeholder_text = "Name des eigenen Profils"
	layout.add_child(profile_name)
	profile_name.text_changed.connect(func(_text: String) -> void: _invalidate_preview())
	_add_label(layout, "Mindestklassifikation – gilt auch bei manueller Freigabe")
	for label in ["Unbekannt", "Luftkontakt", "Verdächtig", "Feindlich"]:
		minimum.add_item(label)
	layout.add_child(minimum)
	minimum.item_selected.connect(func(_index: int) -> void: _invalidate_preview())
	automatic.text = "Automatische Freigabe"
	layout.add_child(automatic)
	automatic.toggled.connect(func(_enabled: bool) -> void: _invalidate_preview())
	_add_label(layout, "Ohne Automatik muss jeder Track freigegeben werden. Sperren und Einsatzgrenzen gelten immer.")
	redundant.text = "Mehrere Systeme pro Track erlauben"
	layout.add_child(redundant)
	redundant.toggled.connect(func(_enabled: bool) -> void: _invalidate_preview())
	_add_label(layout, "Schutzprioritäten: 0 = kein Bonus, 1 = normal, 3 = höchster Bonus. Andere Bewertungsanteile bleiben aktiv.")
	layout.add_child(priorities)
	preview_button.text = "PRÜFEN UND VORSCHAU"
	preview_button.pressed.connect(preview_draft)
	layout.add_child(preview_button)
	explanation.custom_minimum_size = Vector2(0, 140)
	explanation.fit_content = true
	explanation.scroll_active = false
	layout.add_child(explanation)
	confirmed.connect(apply_draft)
	canceled.connect(_resume)


func open_for_session(value: GameSession) -> void:
	session = value
	_previous_speed = session.simulation.get_time_scale()
	session.set_time_scale(0.0)
	set_draft(session.defenses.get_rules())
	popup_centered(Vector2i(620, 620))


func set_draft(rules: Dictionary) -> void:
	_profile_id = String(rules.get("profile_id", "custom"))
	profile_name.text = String(rules.get("display_name", ""))
	minimum.select(CLASSIFICATIONS.find(String(rules.get("minimum_classification", ""))))
	automatic.set_pressed_no_signal(bool(rules.get("automatic_release", false)))
	redundant.set_pressed_no_signal(bool(rules.get("allow_redundant_engagement", false)))
	for child in priorities.get_children():
		priorities.remove_child(child)
		child.queue_free()
	_priority_inputs.clear()
	for entity in session.infrastructure.get_infrastructure():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(entity.id)
		for definition in session.scenario.definitions:
			if definition.id == entity.definition_id:
				label.text = definition.display_name
		label.tooltip_text = String(entity.id)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var input := SpinBox.new()
		input.min_value = 0
		input.max_value = 3
		input.step = 0.5
		input.value = float(rules.get("infrastructure_priorities", {}).get(String(entity.id), 1.0))
		input.value_changed.connect(func(_value: float) -> void: _invalidate_preview())
		row.add_child(input)
		priorities.add_child(row)
		_priority_inputs[String(entity.id)] = input
	_invalidate_preview()
	_profile_id = String(rules.get("profile_id", "custom"))


func get_draft() -> Dictionary:
	var weights: Dictionary = {}
	for id in _priority_inputs:
		weights[id] = _priority_inputs[id].value
	return {
		"profile_id": _profile_id,
		"display_name": profile_name.text.strip_edges(),
		"minimum_classification": CLASSIFICATIONS[minimum.selected] if minimum.selected >= 0 else "",
		"automatic_release": automatic.button_pressed,
		"allow_redundant_engagement": redundant.button_pressed,
		"infrastructure_priorities": weights,
	}


func preview_draft() -> Dictionary:
	var result := session.preview_defense_rules(get_draft())
	_previewed = result.success and session.phase != GameSession.Phase.ENDED
	get_ok_button().disabled = not _previewed
	if not result.success:
		explanation.text = "Profil kann nicht aktiviert werden:\n" + "\n".join(result.errors)
	else:
		explanation.text = "Vorschau – keine Befehle ausgeführt.\n"
		if result.decisions.is_empty():
			explanation.text += "Noch keine aktiven Abwehrsysteme. Die Regeln gelten nach Einsatzstart."
		for item in result.decisions:
			explanation.text += "\n%s\n%s\n" % [item.defense_id, DefenseSystem.describe_decision(item.decision)]
	_scroll.ensure_control_visible.call_deferred(explanation)
	return result


func apply_draft() -> Dictionary:
	if not _previewed:
		return {"success": false, "errors": ["Bitte zuerst die Vorschau prüfen."]}
	var result := session.set_defense_rules(get_draft())
	_resume()
	return result


func _invalidate_preview() -> void:
	_profile_id = "custom"
	_previewed = false
	get_ok_button().disabled = true
	explanation.text = "Entwurf: Erst prüfen, dann aktivieren. Die Simulation ist während der Bearbeitung pausiert."


func _resume() -> void:
	if session != null and session.phase != GameSession.Phase.ENDED:
		session.set_time_scale(_previous_speed)
		session.state_changed.emit()


func _add_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
