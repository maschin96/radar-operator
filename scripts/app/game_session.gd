class_name GameSession
extends RefCounted

signal state_changed
signal event_added(event: Dictionary)
signal mission_finished(status: int)

enum Phase { PREPARATION, RUNNING, ENDED }

const TICK_DURATION := 0.1

var scenario: ScenarioDefinition
var phase: Phase = Phase.PREPARATION
var placement: PlacementSystem
var infrastructure: InfrastructureSystem
var movement: ThreatMovementSystem
var sensors: SensorSystem
var fusion: TrackFusionSystem
var defenses: DefenseSystem
var simulation: SimulationCore
var events: Array[Dictionary] = []
var replay_frames: Array[Dictionary] = []

var _event_cursors: Dictionary = {}
var _next_replay_time: float = 0.0


func initialize(scenario_definition: ScenarioDefinition) -> void:
	scenario = scenario_definition
	phase = Phase.PREPARATION
	events.clear()
	replay_frames.clear()
	_event_cursors.clear()
	_next_replay_time = 0.0
	placement = PlacementSystem.new()
	placement.configure(scenario)
	infrastructure = InfrastructureSystem.new()
	infrastructure.configure(scenario)
	movement = ThreatMovementSystem.new()
	movement.configure(scenario)
	sensors = SensorSystem.new()
	sensors.configure(scenario)
	fusion = TrackFusionSystem.new()
	defenses = DefenseSystem.new()
	defenses.configure(scenario, infrastructure.get_infrastructure())
	simulation = SimulationCore.new(scenario.seed, TICK_DURATION)
	simulation.tick_completed.connect(_on_simulation_tick)
	movement.threat_target_reached.connect(_on_threat_target_reached)
	defenses.track_neutralized.connect(_on_track_neutralized)
	infrastructure.mission_ended.connect(_on_mission_ended)
	_append_event(&"session_initialized", 0.0, {"scenario_id": scenario.scenario_id})


func advance(real_delta: float) -> int:
	if phase != Phase.RUNNING:
		return 0
	return simulation.advance(real_delta)


func set_time_scale(scale: float) -> bool:
	return simulation.set_time_scale(scale)


func set_defense_rules(rules: Dictionary) -> void:
	defenses.set_rules(rules)
	_append_event(&"defense_rules_changed", float(simulation.get_snapshot().simulation_time), {"rules": defenses.get_rules()})


func place_system(definition_id: StringName, position: Vector2) -> Dictionary:
	if phase != Phase.PREPARATION:
		return {"success": false, "reasons": ["not_in_preparation"]}
	var result := placement.place(definition_id, position)
	if result.success:
		_append_event(&"system_placed", 0.0, {
			"entity_id": result.entity.id,
			"definition_id": result.entity.definition_id,
			"position": result.entity.position,
		})
		state_changed.emit()
	return result


func remove_system(entity_id: StringName) -> bool:
	var removed := placement.remove(entity_id)
	if removed:
		_append_event(&"system_removed", 0.0, {"entity_id": entity_id})
		state_changed.emit()
	return removed


func start_mission() -> Dictionary:
	if phase != Phase.PREPARATION:
		return {"success": false, "reason": "invalid_phase"}
	var sensor_count := 0
	var defense_count := 0
	for entity in placement.get_placements():
		var definition := _definition(entity.definition_id)
		if definition is SensorDefinition:
			sensors.add_sensor(entity as SensorState)
			sensor_count += 1
		elif definition is DefenseDefinition:
			defenses.add_defense(entity)
			defense_count += 1
	if sensor_count == 0 or defense_count == 0:
		return {"success": false, "reason": "requires_sensor_and_defense"}
	placement.start_deployment()
	infrastructure.start_mission()
	phase = Phase.RUNNING
	_append_event(&"mission_started", 0.0, {"sensor_count": sensor_count, "defense_count": defense_count})
	state_changed.emit()
	return {"success": true}


func get_snapshot() -> Dictionary:
	var simulation_snapshot := simulation.get_snapshot()
	return {
		"phase": phase,
		"simulation_time": simulation_snapshot.simulation_time,
		"tick": simulation_snapshot.tick,
		"time_scale": simulation_snapshot.time_scale,
		"budget": placement.get_budget(),
		"placements": placement.get_placements(),
		"infrastructure": infrastructure.get_infrastructure(),
		"tracks": fusion.get_active_tracks(),
		"defenses": defenses.get_defenses(),
		"mission_status": infrastructure.get_mission_status(),
		"events": events,
	}


func get_persistence_snapshot() -> Dictionary:
	var placement_data: Array[Dictionary] = []
	for entity in placement.get_placements():
		placement_data.append(entity.to_dictionary())
	var infrastructure_data: Array[Dictionary] = []
	for state in infrastructure.get_infrastructure():
		infrastructure_data.append(state.to_dictionary())
	var track_data: Array[Dictionary] = []
	for track in fusion.get_active_tracks():
		track_data.append(track.to_player_dictionary())
	var threat_data: Array[Dictionary] = []
	for threat in movement.get_debug_threat_states():
		threat_data.append({
			"id": str(threat.id),
			"definition_id": str(threat.definition_id),
			"position": {"x": threat.position.x, "y": threat.position.y},
			"next_waypoint_index": threat.next_waypoint_index,
			"durability": threat.durability,
		})
	var sensor_data: Array[Dictionary] = []
	for sensor in sensors.get_sensors():
		sensor_data.append({
			"id": str(sensor.id),
			"next_scan_time": sensor.next_scan_time,
			"scan_count": sensor.scan_count,
			"powered": sensor.powered,
		})
	var defense_data: Array[Dictionary] = []
	for defense in defenses.get_defenses():
		defense_data.append({
			"id": str(defense.id),
			"status": defense.status,
			"ammunition": defense.ammunition,
			"assigned_track_id": str(defense.assigned_track_id),
			"tracking_remaining": defense.tracking_remaining,
			"reload_remaining": defense.reload_remaining,
		})
	var simulation_data := simulation.get_snapshot()
	return {
		"phase": phase,
		"tick": simulation_data.tick,
		"simulation_time": simulation_data.simulation_time,
		"time_scale": simulation_data.time_scale,
		"budget": placement.get_budget(),
		"placements": placement_data,
		"infrastructure": infrastructure_data,
		"tracks": track_data,
		"threats": threat_data,
		"sensors": sensor_data,
		"defenses": defense_data,
		"defense_rules": defenses.get_rules(),
		"mission_status": infrastructure.get_mission_status(),
		"event_count": events.size(),
	}


func _on_simulation_tick(_tick: int) -> void:
	var simulation_time: float = simulation.get_snapshot().simulation_time
	movement.process_tick(TICK_DURATION, simulation_time)
	var measurements := sensors.process_tick(simulation_time, movement.get_debug_threat_states())
	fusion.process_measurements(measurements, simulation_time)
	defenses.process_tick(TICK_DURATION, simulation_time, fusion.get_active_tracks())
	infrastructure.process_tick(TICK_DURATION, simulation_time)
	_collect_events(simulation_time)
	_record_replay_frame(simulation_time)
	state_changed.emit()


func _on_threat_target_reached(event: Dictionary) -> void:
	if phase == Phase.RUNNING:
		infrastructure.process_threat_events([event], float(event.simulation_time))


func _on_track_neutralized(track_id: StringName) -> void:
	var track := fusion.get_track(track_id)
	if track == null:
		return
	var simulation_time := float(simulation.get_snapshot().simulation_time)
	for source_id in track.debug_source_entities:
		movement.neutralize_threat(StringName(source_id), simulation_time)
	fusion.remove_track(track_id, simulation_time, &"neutralized")


func _on_mission_ended(event: Dictionary) -> void:
	phase = Phase.ENDED
	simulation.set_time_scale(0.0)
	_collect_events(float(event.simulation_time))
	mission_finished.emit(infrastructure.get_mission_status())
	state_changed.emit()


func _collect_events(simulation_time: float) -> void:
	_collect_source(&"movement", movement.get_events(), simulation_time)
	_collect_source(&"fusion", fusion.get_events(), simulation_time)
	_collect_source(&"defense", defenses.get_events(), simulation_time)
	_collect_source(&"infrastructure", infrastructure.get_events(), simulation_time)


func _collect_source(source: StringName, source_events: Array, fallback_time: float) -> void:
	var cursor := int(_event_cursors.get(source, 0))
	while cursor < source_events.size():
		var source_event: Dictionary = source_events[cursor]
		var data := source_event.duplicate(true)
		var event_type := StringName(data.get("type", "event"))
		data.erase("type")
		var event_time := float(data.get("simulation_time", fallback_time))
		data.erase("simulation_time")
		_append_event(event_type, event_time, data, source)
		cursor += 1
	_event_cursors[source] = cursor


func _append_event(
	type: StringName,
	simulation_time: float,
	data: Dictionary = {},
	category: StringName = &"session"
) -> void:
	var event := {
		"index": events.size(),
		"type": type,
		"category": category,
		"simulation_time": simulation_time,
		"data": data.duplicate(true),
	}
	events.append(event)
	event_added.emit(event)


func _record_replay_frame(simulation_time: float) -> void:
	if simulation_time + 0.000000001 < _next_replay_time:
		return
	var track_data: Array[Dictionary] = []
	for track in fusion.get_active_tracks():
		track_data.append(track.to_player_dictionary())
	var infrastructure_data: Array[Dictionary] = []
	for state in infrastructure.get_infrastructure():
		infrastructure_data.append(state.to_dictionary())
	replay_frames.append({
		"simulation_time": simulation_time,
		"tracks": track_data,
		"infrastructure": infrastructure_data,
	})
	_next_replay_time = floorf(simulation_time) + 1.0


func _definition(definition_id: StringName) -> EntityDefinition:
	for definition in scenario.definitions:
		if definition is EntityDefinition and definition.id == definition_id:
			return definition
	return null
