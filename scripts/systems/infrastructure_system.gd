class_name InfrastructureSystem
extends RefCounted

signal infrastructure_damaged(event: Dictionary)
signal power_state_changed(event: Dictionary)
signal mission_ended(event: Dictionary)

enum MissionStatus {
	PREPARATION,
	RUNNING,
	VICTORY,
	DEFEAT,
}

var _definitions: Dictionary = {}
var _infrastructure: Dictionary = {}
var _threat_definitions: Dictionary = {}
var _energy_connections: Array[Dictionary] = []
var _resolved_threats: Dictionary = {}
var _events: Array[Dictionary] = []
var _mission_status: MissionStatus = MissionStatus.PREPARATION
var _mission_duration: float = 0.0
var _mission_goals: Dictionary = {}
var _end_event_emitted: bool = false


func configure(scenario: ScenarioDefinition) -> void:
	_definitions.clear()
	_infrastructure.clear()
	_threat_definitions.clear()
	_energy_connections.clear()
	_resolved_threats.clear()
	_events.clear()
	_mission_status = MissionStatus.PREPARATION
	_end_event_emitted = false
	_mission_duration = scenario.mission_duration
	_mission_goals = scenario.mission_goals.duplicate(true)
	for definition in scenario.definitions:
		if definition is InfrastructureDefinition:
			_definitions[definition.id] = definition
		elif definition is ThreatDefinition:
			_threat_definitions[definition.id] = definition
	for entity_data in scenario.starting_entities:
		var definition_id := StringName(entity_data.definition_id)
		if not _definitions.has(definition_id):
			continue
		var definition := _definitions[definition_id] as InfrastructureDefinition
		var state := InfrastructureState.new(
			StringName(entity_data.id),
			definition_id,
			entity_data.position,
			definition
		)
		_infrastructure[state.id] = state
	for connection in scenario.energy_connections:
		var runtime_connection := connection.duplicate(true)
		runtime_connection["reserve_remaining"] = float(connection.get("reserve_duration", 0.0))
		_energy_connections.append(runtime_connection)


func start_mission(simulation_time: float = 0.0) -> bool:
	if _mission_status != MissionStatus.PREPARATION:
		return false
	_mission_status = MissionStatus.RUNNING
	_record_event(&"mission_started", simulation_time)
	return true


func process_threat_events(events: Array, simulation_time: float) -> void:
	if _mission_status != MissionStatus.RUNNING:
		return
	for event in events:
		if event.type != &"threat_target_reached":
			continue
		var threat_id := StringName(event.threat_id)
		if _resolved_threats.has(threat_id):
			continue
		_resolved_threats[threat_id] = true
		_apply_threat_hit(event, simulation_time)
	_evaluate_mission(simulation_time)


func process_tick(delta: float, simulation_time: float) -> void:
	if _mission_status != MissionStatus.RUNNING:
		return
	_update_energy(delta, simulation_time)
	_evaluate_mission(simulation_time)


func get_infrastructure() -> Array[InfrastructureState]:
	var result: Array[InfrastructureState] = []
	for state in _infrastructure.values():
		result.append(state)
	result.sort_custom(func(a: InfrastructureState, b: InfrastructureState) -> bool: return a.id < b.id)
	return result


func get_state(entity_id: StringName) -> InfrastructureState:
	return _infrastructure.get(entity_id) as InfrastructureState


func get_mission_status() -> MissionStatus:
	return _mission_status


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func _apply_threat_hit(event: Dictionary, simulation_time: float) -> void:
	var target_id := StringName(event.get("target_id", ""))
	var definition_id := StringName(event.get("definition_id", ""))
	if not _infrastructure.has(target_id) or not _threat_definitions.has(definition_id):
		_record_event(&"invalid_threat_target", simulation_time, {"target_id": target_id, "definition_id": definition_id})
		return
	var target := _infrastructure[target_id] as InfrastructureState
	var threat_definition := _threat_definitions[definition_id] as ThreatDefinition
	var applied_damage := target.apply_damage(threat_definition.impact_damage)
	var damage_event := _record_event(&"infrastructure_damaged", simulation_time, {
		"target_id": target.id,
		"threat_id": StringName(event.threat_id),
		"damage": applied_damage,
		"integrity": target.integrity,
		"destroyed": target.status == InfrastructureState.Status.DESTROYED,
	})
	infrastructure_damaged.emit(damage_event)


func _update_energy(delta: float, simulation_time: float) -> void:
	for connection in _energy_connections:
		var source := _infrastructure.get(StringName(connection.source_id)) as InfrastructureState
		var consumer := _infrastructure.get(StringName(connection.consumer_id)) as InfrastructureState
		if source == null or consumer == null or consumer.status == InfrastructureState.Status.DESTROYED:
			continue
		var was_powered := consumer.powered
		if source.status != InfrastructureState.Status.DESTROYED:
			connection.reserve_remaining = float(connection.reserve_duration)
			consumer.powered = true
		else:
			connection.reserve_remaining = maxf(float(connection.reserve_remaining) - delta, 0.0)
			consumer.powered = float(connection.reserve_remaining) > 0.0
		if consumer.powered != was_powered:
			var event := _record_event(&"power_state_changed", simulation_time, {
				"consumer_id": consumer.id,
				"powered": consumer.powered,
				"source_id": source.id,
			})
			power_state_changed.emit(event)


func _evaluate_mission(simulation_time: float) -> void:
	if _mission_status != MissionStatus.RUNNING:
		return
	var required_survivors: PackedStringArray = _mission_goals.get("required_survivors", PackedStringArray())
	for required_id in required_survivors:
		var state := _infrastructure.get(StringName(required_id)) as InfrastructureState
		if state == null or state.status == InfrastructureState.Status.DESTROYED:
			_finish_mission(MissionStatus.DEFEAT, simulation_time, &"required_target_destroyed")
			return
	var survivor_count := 0
	for state in _infrastructure.values():
		survivor_count += int(state.status != InfrastructureState.Status.DESTROYED)
	var minimum_survivors := int(_mission_goals.get("minimum_survivors", 1))
	if survivor_count < minimum_survivors:
		_finish_mission(MissionStatus.DEFEAT, simulation_time, &"insufficient_survivors")
		return
	if simulation_time >= _mission_duration:
		_finish_mission(MissionStatus.VICTORY, simulation_time, &"duration_survived")


func _finish_mission(status: MissionStatus, simulation_time: float, reason: StringName) -> void:
	if _end_event_emitted:
		return
	_mission_status = status
	_end_event_emitted = true
	var event := _record_event(&"mission_ended", simulation_time, {
		"status": status,
		"reason": reason,
	})
	mission_ended.emit(event)


func _record_event(type: StringName, simulation_time: float, data: Dictionary = {}) -> Dictionary:
	var event := {"type": type, "simulation_time": simulation_time, "data": data.duplicate(true)}
	_events.append(event)
	return event
