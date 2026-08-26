class_name ThreatMovementSystem
extends RefCounted

signal threat_entered(event: Dictionary)
signal threat_target_reached(event: Dictionary)
signal threat_exited(event: Dictionary)

var _definitions: Dictionary = {}
var _scheduled_spawns: Array[Dictionary] = []
var _active_threats: Dictionary = {}
var _events: Array[Dictionary] = []
var _next_spawn_index: int = 0


func configure(scenario: ScenarioDefinition) -> void:
	_definitions.clear()
	_scheduled_spawns.clear()
	_active_threats.clear()
	_events.clear()
	_next_spawn_index = 0

	for definition in scenario.definitions:
		if definition is ThreatDefinition:
			_definitions[definition.id] = definition
	for resource in scenario.attack_waves:
		if not resource is AttackWaveDefinition:
			continue
		var wave := resource as AttackWaveDefinition
		for spawn in wave.spawns:
			var scheduled_spawn := spawn.duplicate(true)
			scheduled_spawn["spawn_time"] = wave.start_time + float(spawn.get("delay", 0.0))
			_scheduled_spawns.append(scheduled_spawn)
	_scheduled_spawns.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a.spawn_time), float(b.spawn_time)):
				return float(a.spawn_time) < float(b.spawn_time)
			return String(a.id) < String(b.id)
	)


func process_tick(delta: float, simulation_time: float) -> void:
	_spawn_due_threats(simulation_time)
	var ids: Array = _active_threats.keys()
	ids.sort()
	for threat_id in ids:
		var threat := _active_threats[threat_id] as ThreatState
		_move_threat(threat, delta, simulation_time)


func get_debug_threat_states() -> Array[ThreatState]:
	var result: Array[ThreatState] = []
	for threat in _active_threats.values():
		result.append(threat)
	return result


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func has_pending_or_active_threats() -> bool:
	return _next_spawn_index < _scheduled_spawns.size() or not _active_threats.is_empty()


func neutralize_threat(threat_id: StringName, simulation_time: float) -> bool:
	if not _active_threats.has(threat_id):
		return false
	var threat := _active_threats[threat_id] as ThreatState
	threat.resolved = true
	threat.active = false
	_active_threats.erase(threat_id)
	_record_event(&"threat_neutralized", threat, simulation_time)
	return true


func _spawn_due_threats(simulation_time: float) -> void:
	while _next_spawn_index < _scheduled_spawns.size():
		var spawn: Dictionary = _scheduled_spawns[_next_spawn_index]
		if float(spawn.spawn_time) > simulation_time + 0.000000001:
			break
		_next_spawn_index += 1
		var definition_id := StringName(spawn.definition_id)
		if not _definitions.has(definition_id):
			continue
		var definition := _definitions[definition_id] as ThreatDefinition
		var route: PackedVector2Array = spawn.route
		var threat := ThreatState.new(
			StringName(spawn.id),
			definition_id,
			route[0],
			route,
			StringName(spawn.get("target_id", "")),
			StringName(spawn.get("completion", "target")),
			definition.durability,
			float(spawn.spawn_time)
		)
		_active_threats[threat.id] = threat
		var event := _record_event(&"threat_entered", threat, simulation_time)
		threat_entered.emit(event)


func _move_threat(threat: ThreatState, delta: float, simulation_time: float) -> void:
	var definition := _definitions[threat.definition_id] as ThreatDefinition
	var active_delta := minf(delta, maxf(simulation_time - threat.spawn_time, 0.0))
	var remaining_distance := definition.movement_speed * active_delta
	while remaining_distance > 0.0 and not threat.resolved:
		var destination := threat.route[threat.next_waypoint_index]
		var distance := threat.position.distance_to(destination)
		if distance <= remaining_distance + 0.000000001:
			threat.position = destination
			remaining_distance -= distance
			threat.next_waypoint_index += 1
			if threat.next_waypoint_index >= threat.route.size():
				_resolve_route(threat, simulation_time)
		else:
			threat.position = threat.position.move_toward(destination, remaining_distance)
			remaining_distance = 0.0


func _resolve_route(threat: ThreatState, simulation_time: float) -> void:
	if threat.resolved:
		return
	threat.resolved = true
	_active_threats.erase(threat.id)
	if threat.completion == &"exit":
		var exit_event := _record_event(&"threat_exited", threat, simulation_time)
		threat_exited.emit(exit_event)
	else:
		var target_event := _record_event(&"threat_target_reached", threat, simulation_time)
		threat_target_reached.emit(target_event)


func _record_event(type: StringName, threat: ThreatState, simulation_time: float) -> Dictionary:
	var event := {
		"type": type,
		"threat_id": threat.id,
		"definition_id": threat.definition_id,
		"target_id": threat.target_id,
		"position": threat.position,
		"simulation_time": simulation_time,
	}
	_events.append(event)
	return event
