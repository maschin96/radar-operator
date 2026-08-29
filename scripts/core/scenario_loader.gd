class_name ScenarioLoader
extends RefCounted

const VALID_FACTIONS: Array[StringName] = [&"player", &"hostile", &"neutral"]
const VALID_TUTORIAL_TRIGGERS: Array[StringName] = [
	&"briefing_closed",
	&"definition_selected",
	&"system_placed",
	&"mission_started",
	&"track_detected",
	&"track_selected",
	&"simulation_resumed",
	&"mission_finished",
]


func load_scenario(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"success": false, "errors": ["Scenario file does not exist: %s" % path]}
	var resource := ResourceLoader.load(path)
	if not resource is ScenarioDefinition:
		return {"success": false, "errors": ["Resource is not a ScenarioDefinition: %s" % path]}
	var errors := validate_scenario(resource)
	return {
		"success": errors.is_empty(),
		"errors": errors,
		"scenario": resource,
	}


func validate_scenario(scenario: ScenarioDefinition) -> Array[String]:
	var errors: Array[String] = []
	if scenario.content_version != ScenarioDefinition.CURRENT_CONTENT_VERSION:
		errors.append("Scenario content version %d is incompatible; supported version is %d" % [scenario.content_version, ScenarioDefinition.CURRENT_CONTENT_VERSION])
	if scenario.scenario_id.is_empty():
		errors.append("Scenario id is empty")
	if scenario.display_name.strip_edges().is_empty():
		errors.append("Scenario display name is empty")
	if scenario.summary.strip_edges().is_empty():
		errors.append("Scenario summary is empty")
	if scenario.campaign_order < 0:
		errors.append("Scenario campaign order cannot be negative")
	if scenario.expected_duration_minutes <= 0:
		errors.append("Scenario expected duration must be positive")
	if scenario.learning_objectives.is_empty():
		errors.append("Scenario must define at least one learning objective")
	if scenario.world_size.x <= 0.0 or scenario.world_size.y <= 0.0:
		errors.append("Scenario world size must be positive")
	if scenario.starting_budget < 0:
		errors.append("Scenario budget cannot be negative")
	if scenario.mission_duration <= 0.0:
		errors.append("Scenario duration must be positive")
	for zone in scenario.placement_zones:
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			errors.append("Scenario contains an empty placement zone")
		elif not Rect2(Vector2.ZERO, scenario.world_size).encloses(zone):
			errors.append("Scenario placement zone extends beyond the map")
	for zone in scenario.blocked_zones:
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			errors.append("Scenario contains an empty blocked zone")
		elif not Rect2(Vector2.ZERO, scenario.world_size).encloses(zone):
			errors.append("Scenario blocked zone extends beyond the map")

	var definitions_by_id: Dictionary = {}
	for resource in scenario.definitions:
		if not resource is EntityDefinition:
			errors.append("Scenario contains a resource that is not an EntityDefinition")
			continue
		var definition := resource as EntityDefinition
		if definitions_by_id.has(definition.id):
			errors.append("Duplicate definition id: %s" % definition.id)
		else:
			definitions_by_id[definition.id] = definition
		errors.append_array(definition.get_validation_errors())

	var entity_ids: Dictionary = {}
	for entity_data in scenario.starting_entities:
		_validate_starting_entity(entity_data, scenario.world_size, definitions_by_id, entity_ids, errors)
	for connection in scenario.energy_connections:
		var source_id := StringName(connection.get("source_id", ""))
		var consumer_id := StringName(connection.get("consumer_id", ""))
		if not entity_ids.has(source_id):
			errors.append("Energy connection references missing source '%s'" % source_id)
		if not entity_ids.has(consumer_id):
			errors.append("Energy connection references missing consumer '%s'" % consumer_id)
		if float(connection.get("reserve_duration", 0.0)) < 0.0:
			errors.append("Energy connection for '%s' has negative reserve duration" % consumer_id)
	for required_id in scenario.mission_goals.get("required_survivors", PackedStringArray()):
		if not entity_ids.has(StringName(required_id)):
			errors.append("Mission goal references missing required survivor '%s'" % required_id)
	if scenario.engagement_profile != null:
		errors.append_array(scenario.engagement_profile.get_validation_errors())
		for id in scenario.engagement_profile.infrastructure_priorities:
			if not entity_ids.has(StringName(id)):
				errors.append("Regelprofil verweist auf unbekannte Infrastruktur: %s" % id)
	var wave_ids: Dictionary = {}
	for resource in scenario.attack_waves:
		if not resource is AttackWaveDefinition:
			errors.append("Scenario contains a resource that is not an AttackWaveDefinition")
			continue
		var wave := resource as AttackWaveDefinition
		if wave_ids.has(wave.id):
			errors.append("Duplicate attack wave id: %s" % wave.id)
		wave_ids[wave.id] = true
		errors.append_array(wave.get_validation_errors(definitions_by_id, scenario.world_size))
	_validate_tutorial_steps(scenario.tutorial_steps, definitions_by_id, errors)
	return errors


func _validate_tutorial_steps(
	steps: Array[Dictionary],
	definitions_by_id: Dictionary,
	errors: Array[String]
) -> void:
	var step_ids: Dictionary = {}
	for step in steps:
		var step_id := StringName(step.get("id", ""))
		var trigger := StringName(step.get("trigger", ""))
		if step_id.is_empty() or step_ids.has(step_id):
			errors.append("Tutorial contains an empty or duplicate step id '%s'" % step_id)
		step_ids[step_id] = true
		if String(step.get("title", "")).strip_edges().is_empty():
			errors.append("Tutorial step '%s' has no title" % step_id)
		if String(step.get("instruction", "")).strip_edges().is_empty():
			errors.append("Tutorial step '%s' has no instruction" % step_id)
		if not VALID_TUTORIAL_TRIGGERS.has(trigger):
			errors.append("Tutorial step '%s' has invalid trigger '%s'" % [step_id, trigger])
		var definition_id := StringName(step.get("definition_id", ""))
		if not definition_id.is_empty() and not definitions_by_id.has(definition_id):
			errors.append("Tutorial step '%s' references missing definition '%s'" % [step_id, definition_id])


func instantiate_starting_entities(scenario: ScenarioDefinition) -> Array[EntityState]:
	var entities: Array[EntityState] = []
	for entity_data in scenario.starting_entities:
		entities.append(EntityState.new(
			StringName(entity_data.get("id", "")),
			StringName(entity_data.get("definition_id", "")),
			StringName(entity_data.get("faction", "neutral")),
			entity_data.get("position", Vector2.ZERO)
		))
	return entities


func _validate_starting_entity(
	entity_data: Dictionary,
	world_size: Vector2,
	definitions_by_id: Dictionary,
	entity_ids: Dictionary,
	errors: Array[String]
) -> void:
	var entity_id := StringName(entity_data.get("id", ""))
	var definition_id := StringName(entity_data.get("definition_id", ""))
	var faction := StringName(entity_data.get("faction", ""))
	var position: Variant = entity_data.get("position")

	if entity_id.is_empty():
		errors.append("Starting entity has an empty id")
	elif entity_ids.has(entity_id):
		errors.append("Duplicate starting entity id: %s" % entity_id)
	else:
		entity_ids[entity_id] = true
	if not definitions_by_id.has(definition_id):
		errors.append("Entity '%s' references missing definition '%s'" % [entity_id, definition_id])
	if not VALID_FACTIONS.has(faction):
		errors.append("Entity '%s' has invalid faction '%s'" % [entity_id, faction])
	if not position is Vector2:
		errors.append("Entity '%s' has no Vector2 position" % entity_id)
	elif position.x < 0.0 or position.y < 0.0 or position.x > world_size.x or position.y > world_size.y:
		errors.append("Entity '%s' is outside the scenario map" % entity_id)
