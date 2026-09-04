class_name InfrastructureSystem
extends RefCounted

signal infrastructure_damaged(event: Dictionary)
signal power_state_changed(event: Dictionary)
signal network_state_changed(event: Dictionary)
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
var _network_connections: Array[Dictionary] = []
var _system_nodes: Dictionary = {}
var _network_defaults: Dictionary = {}
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
	_network_connections.clear()
	_system_nodes.clear()
	_network_defaults = scenario.network_defaults.duplicate(true)
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
	for connection in scenario.network_connections:
		_add_connection(connection)
	for index in scenario.energy_connections.size():
		var legacy := scenario.energy_connections[index].duplicate(true)
		legacy["id"] = StringName("legacy_energy_%02d" % index)
		legacy["kind"] = &"energy"
		_add_connection(legacy)
	_refresh_consumer_states()


func register_systems(systems: Array) -> void:
	_system_nodes.clear()
	_network_connections = _network_connections.filter(func(connection: Dictionary) -> bool:
		return not bool(connection.get("automatic", false))
	)
	var sorted_systems := systems.duplicate()
	sorted_systems.sort_custom(func(a: EntityState, b: EntityState) -> bool: return String(a.id) < String(b.id))
	for entity in sorted_systems:
		_system_nodes[entity.id] = _new_node_state(entity.id, entity.position)
		_add_automatic_connection(entity, &"energy")
		_add_automatic_connection(entity, &"communication")
	_refresh_consumer_states()


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
	_update_network(delta, simulation_time)
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


func get_network_state(entity_id: StringName) -> Dictionary:
	if _system_nodes.has(entity_id):
		return (_system_nodes[entity_id] as Dictionary).duplicate(true)
	var infrastructure_state := get_state(entity_id)
	if infrastructure_state == null:
		return {}
	return {
		"id": String(infrastructure_state.id),
		"energy_status": infrastructure_state.energy_status,
		"communication_status": infrastructure_state.communication_status,
		"reserves": infrastructure_state.network_reserves.duplicate(true),
		"sources": infrastructure_state.network_sources.duplicate(true),
		"causes": infrastructure_state.network_causes.duplicate(true),
	}


func get_network_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection in _network_connections:
		var data := connection.duplicate(true)
		data["source_position"] = _node_position(StringName(connection.source_id))
		data["consumer_position"] = _node_position(StringName(connection.consumer_id))
		result.append(data)
	return result


func update_system_position(entity_id: StringName, position: Vector2) -> void:
	if _system_nodes.has(entity_id):
		(_system_nodes[entity_id] as Dictionary).position = position


func get_network_persistence_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection in _network_connections:
		result.append({
			"id": String(connection.id),
			"kind": String(connection.kind),
			"source_id": String(connection.source_id),
			"consumer_id": String(connection.consumer_id),
			"reserve_duration": float(connection.reserve_duration),
			"reserve_remaining": float(connection.reserve_remaining),
			"recovery_duration": float(connection.recovery_duration),
			"recovery_remaining": float(connection.recovery_remaining),
			"enabled": bool(connection.enabled),
			"automatic": bool(connection.automatic),
			"supplied": bool(connection.supplied),
			"status": int(connection.status),
			"cause": String(connection.cause),
		})
	return result


func set_connection_enabled(connection_id: StringName, enabled: bool, simulation_time: float) -> Dictionary:
	for connection in _network_connections:
		if StringName(connection.id) != connection_id:
			continue
		if bool(connection.enabled) == enabled:
			return {"success": true, "connection_id": connection_id, "enabled": enabled}
		connection.enabled = enabled
		var event := _record_event(&"network_connection_changed", simulation_time, {
			"connection_id": String(connection_id),
			"kind": String(connection.kind),
			"source_id": String(connection.source_id),
			"consumer_id": String(connection.consumer_id),
			"enabled": enabled,
		})
		network_state_changed.emit(event)
		return {"success": true, "connection_id": connection_id, "enabled": enabled}
	return {"success": false, "connection_id": connection_id, "reason": "connection_not_found"}


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


func _update_network(delta: float, simulation_time: float) -> void:
	for connection in _network_connections:
		var previous_status := int(connection.status)
		var supplied := bool(connection.enabled) and _source_available(StringName(connection.source_id), StringName(connection.kind))
		if supplied:
			connection.reserve_remaining = float(connection.reserve_duration)
			if not bool(connection.supplied) and float(connection.recovery_duration) > 0.0:
				connection.recovery_remaining = float(connection.recovery_duration)
			connection.recovery_remaining = maxf(float(connection.recovery_remaining) - delta, 0.0)
			connection.status = InfrastructureState.NetworkStatus.DEGRADED if float(connection.recovery_remaining) > 0.0 else InfrastructureState.NetworkStatus.ONLINE
			connection.cause = "recovering" if float(connection.recovery_remaining) > 0.0 else ""
		else:
			connection.recovery_remaining = 0.0
			connection.reserve_remaining = maxf(float(connection.reserve_remaining) - delta, 0.0)
			var degraded_at := float(connection.reserve_duration) * float(_network_defaults.get("degraded_fraction", 0.5))
			if float(connection.reserve_remaining) > degraded_at:
				connection.status = InfrastructureState.NetworkStatus.RESERVE
			elif float(connection.reserve_remaining) > 0.0:
				connection.status = InfrastructureState.NetworkStatus.DEGRADED
			else:
				connection.status = InfrastructureState.NetworkStatus.OFFLINE
			connection.cause = "connection_disabled" if not bool(connection.enabled) else "source_unavailable"
		connection.supplied = supplied
		if int(connection.status) != previous_status:
			var event := _record_event(&"network_state_changed", simulation_time, {
				"connection_id": String(connection.id),
				"kind": String(connection.kind),
				"consumer_id": String(connection.consumer_id),
				"source_id": String(connection.source_id),
				"previous_status": previous_status,
				"status": int(connection.status),
				"reserve_remaining": float(connection.reserve_remaining),
				"cause": String(connection.cause),
			})
			network_state_changed.emit(event)
	_refresh_consumer_states(simulation_time)


func _add_connection(data: Dictionary) -> void:
	var runtime := data.duplicate(true)
	runtime["id"] = StringName(runtime.get("id", "network_%04d" % (_network_connections.size() + 1)))
	runtime["kind"] = StringName(runtime.get("kind", "energy"))
	runtime["source_id"] = StringName(runtime.get("source_id", ""))
	runtime["consumer_id"] = StringName(runtime.get("consumer_id", ""))
	runtime["reserve_duration"] = float(runtime.get("reserve_duration", 0.0))
	runtime["reserve_remaining"] = float(runtime.reserve_duration)
	runtime["recovery_duration"] = float(runtime.get("recovery_duration", _network_defaults.get("recovery_duration", 2.0)))
	runtime["recovery_remaining"] = 0.0
	runtime["enabled"] = bool(runtime.get("enabled", true))
	runtime["automatic"] = bool(runtime.get("automatic", false))
	runtime["supplied"] = true
	runtime["status"] = InfrastructureState.NetworkStatus.ONLINE
	runtime["cause"] = ""
	_network_connections.append(runtime)


func _add_automatic_connection(entity: EntityState, kind: StringName) -> void:
	var source := _nearest_source(entity.position, kind)
	if source == null:
		return
	var reserve_key := "system_power_reserve" if kind == &"energy" else "system_communication_reserve"
	_add_connection({
		"id": StringName("auto_%s_%s" % [kind, entity.id]),
		"kind": kind,
		"source_id": source.id,
		"consumer_id": entity.id,
		"reserve_duration": float(_network_defaults.get(reserve_key, 0.0)),
		"recovery_duration": float(_network_defaults.get("recovery_duration", 2.0)),
		"automatic": true,
	})


func _nearest_source(position: Vector2, kind: StringName) -> InfrastructureState:
	var best: InfrastructureState
	var best_distance := INF
	for state in _infrastructure.values():
		var definition := _definitions.get(state.definition_id) as InfrastructureDefinition
		if definition == null:
			continue
		var provides_kind := definition.power_output > 0.0 if kind == &"energy" else definition.infrastructure_type == &"command"
		if not provides_kind:
			continue
		var distance := position.distance_squared_to(state.position)
		if distance < best_distance:
			best = state
			best_distance = distance
	return best


func _new_node_state(entity_id: StringName, position: Vector2) -> Dictionary:
	return {
		"id": String(entity_id),
		"position": position,
		"energy_status": InfrastructureState.NetworkStatus.ONLINE,
		"communication_status": InfrastructureState.NetworkStatus.ONLINE,
		"reserves": {"energy": 0.0, "communication": 0.0},
		"sources": {"energy": "", "communication": ""},
		"causes": {"energy": "", "communication": ""},
	}


func _refresh_consumer_states(simulation_time: float = -1.0) -> void:
	var consumer_ids: Dictionary = {}
	for connection in _network_connections:
		consumer_ids[StringName(connection.consumer_id)] = true
	for consumer_id in consumer_ids:
		for kind in [&"energy", &"communication"]:
			var aggregate := _aggregate_consumer_kind(StringName(consumer_id), kind)
			_apply_consumer_kind(StringName(consumer_id), kind, aggregate, simulation_time)


func _aggregate_consumer_kind(consumer_id: StringName, kind: StringName) -> Dictionary:
	var best_status := InfrastructureState.NetworkStatus.OFFLINE
	var best_reserve := 0.0
	var best_source := ""
	var cause := "no_connection"
	var found := false
	for connection in _network_connections:
		if StringName(connection.consumer_id) != consumer_id or StringName(connection.kind) != kind:
			continue
		found = true
		var status := int(connection.status)
		if status < best_status or status == best_status and float(connection.reserve_remaining) > best_reserve:
			best_status = status
			best_reserve = float(connection.reserve_remaining)
			best_source = String(connection.source_id)
			cause = String(connection.cause)
	if not found:
		best_status = InfrastructureState.NetworkStatus.ONLINE
		cause = ""
	return {"status": best_status, "reserve": best_reserve, "source": best_source, "cause": cause}


func _apply_consumer_kind(consumer_id: StringName, kind: StringName, aggregate: Dictionary, simulation_time: float) -> void:
	var infrastructure_state := get_state(consumer_id)
	var previous_status := InfrastructureState.NetworkStatus.ONLINE
	if infrastructure_state != null:
		previous_status = infrastructure_state.energy_status if kind == &"energy" else infrastructure_state.communication_status
		if kind == &"energy":
			infrastructure_state.energy_status = int(aggregate.status) as InfrastructureState.NetworkStatus
			infrastructure_state.powered = int(aggregate.status) != InfrastructureState.NetworkStatus.OFFLINE
		else:
			infrastructure_state.communication_status = int(aggregate.status) as InfrastructureState.NetworkStatus
			infrastructure_state.communication_online = int(aggregate.status) != InfrastructureState.NetworkStatus.OFFLINE
		infrastructure_state.network_reserves[String(kind)] = float(aggregate.reserve)
		infrastructure_state.network_sources[String(kind)] = String(aggregate.source)
		infrastructure_state.network_causes[String(kind)] = String(aggregate.cause)
	elif _system_nodes.has(consumer_id):
		var node := _system_nodes[consumer_id] as Dictionary
		var status_key := "%s_status" % String(kind)
		previous_status = int(node[status_key])
		node[status_key] = int(aggregate.status)
		node.reserves[String(kind)] = float(aggregate.reserve)
		node.sources[String(kind)] = String(aggregate.source)
		node.causes[String(kind)] = String(aggregate.cause)
	if simulation_time >= 0.0 and kind == &"energy" and infrastructure_state != null:
		var was_powered := previous_status != InfrastructureState.NetworkStatus.OFFLINE
		if infrastructure_state.powered != was_powered:
			var event := _record_event(&"power_state_changed", simulation_time, {
				"consumer_id": consumer_id,
				"powered": infrastructure_state.powered,
				"source_id": String(aggregate.source),
				"cause": String(aggregate.cause),
			})
			power_state_changed.emit(event)


func _source_available(source_id: StringName, kind: StringName) -> bool:
	var state := get_state(source_id)
	if state != null:
		if state.status == InfrastructureState.Status.DESTROYED or not state.active:
			return false
		return state.energy_status != InfrastructureState.NetworkStatus.OFFLINE if kind == &"energy" else state.communication_status != InfrastructureState.NetworkStatus.OFFLINE
	if _system_nodes.has(source_id):
		return int((_system_nodes[source_id] as Dictionary)["%s_status" % String(kind)]) != InfrastructureState.NetworkStatus.OFFLINE
	return false


func _node_position(entity_id: StringName) -> Vector2:
	var state := get_state(entity_id)
	if state != null:
		return state.position
	if _system_nodes.has(entity_id):
		return (_system_nodes[entity_id] as Dictionary).position
	return Vector2.ZERO


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
