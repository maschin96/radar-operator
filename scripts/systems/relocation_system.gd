class_name RelocationSystem
extends RefCounted

signal relocation_event(event: Dictionary)

const MINIMUM_SPACING := PlacementSystem.MINIMUM_SPACING
const EPSILON := 0.000001

var _definitions: Dictionary = {}
var _world_bounds := Rect2()
var _placement_zones: Array[Rect2] = []
var _blocked_zones: Array[Rect2] = []
var _cell_size: float = 50.0
var _events: Array[Dictionary] = []
var _next_command_id: int = 1


func configure(scenario: ScenarioDefinition) -> void:
	_definitions.clear()
	_events.clear()
	_next_command_id = 1
	_world_bounds = Rect2(Vector2.ZERO, scenario.world_size)
	_placement_zones = scenario.placement_zones.duplicate()
	if _placement_zones.is_empty():
		_placement_zones.append(_world_bounds)
	_blocked_zones = scenario.blocked_zones.duplicate()
	_cell_size = maxf(scenario.terrain_cell_size, 10.0)
	for definition in scenario.definitions:
		if definition is SensorDefinition or definition is DefenseDefinition:
			_definitions[definition.id] = definition


func preview_relocation(entity: EntityState, target: Vector2, placements: Array, phase_name: StringName, budget: int) -> Dictionary:
	var reasons: Array[String] = []
	if entity == null:
		return {"success": false, "reasons": ["unknown_entity"]}
	var definition := _definitions.get(entity.definition_id) as EntityDefinition
	if definition == null:
		return {"success": false, "reasons": ["unknown_definition"]}
	if not entity.active or entity.damage >= 1.0:
		reasons.append("system_failed")
	if not definition.mobile:
		reasons.append("not_mobile")
	if entity.mobility_status != EntityState.MobilityStatus.STATIONARY:
		reasons.append("relocation_in_progress")
	if not definition.relocation_allowed_phases.has(String(phase_name)):
		reasons.append("phase_not_allowed")
	if definition.relocation_cost > budget:
		reasons.append("insufficient_budget")
	if not _world_bounds.has_point(target):
		reasons.append("outside_map")
	if not _is_in_allowed_zone(target):
		reasons.append("outside_placement_zone")
	if _is_blocked(target):
		reasons.append("blocked_zone")
	for other in placements:
		if other.id == entity.id:
			continue
		if other.mobility_status != EntityState.MobilityStatus.STATIONARY and other.relocation_target.distance_to(target) < MINIMUM_SPACING:
			reasons.append("target_reserved")
			break
		if other.position.distance_to(target) < MINIMUM_SPACING:
			reasons.append("too_close_to_system")
			break
	var path := PackedVector2Array()
	if reasons.is_empty():
		path = _build_route(entity.position, target)
		if path.is_empty():
			reasons.append("route_blocked")
	var travel_distance := _path_distance(path)
	return {
		"success": reasons.is_empty(),
		"reasons": reasons,
		"path": path,
		"cost": definition.relocation_cost,
		"duration": definition.teardown_duration + travel_distance / maxf(definition.relocation_speed, EPSILON) + definition.setup_duration,
	}


func begin_relocation(entity: EntityState, preview: Dictionary, simulation_time: float) -> Dictionary:
	if entity == null or not bool(preview.get("success", false)):
		return {"success": false, "reasons": preview.get("reasons", ["invalid_preview"])}
	var definition := _definitions[entity.definition_id] as EntityDefinition
	var path: PackedVector2Array = preview.path
	entity.relocation_origin = entity.position
	entity.relocation_target = path[-1]
	entity.relocation_path = path
	entity.relocation_path_index = 1
	entity.relocation_command_id = _next_command_id
	_next_command_id += 1
	entity.mobility_status = EntityState.MobilityStatus.TEARDOWN
	entity.relocation_remaining = definition.teardown_duration
	_record_event(&"relocation_started", entity, simulation_time, {
		"origin": entity.relocation_origin,
		"target": entity.relocation_target,
		"cost": definition.relocation_cost,
		"duration": float(preview.duration),
	})
	return {"success": true, "entity_id": entity.id, "command_id": entity.relocation_command_id}


func cancel_relocation(entity: EntityState, simulation_time: float) -> Dictionary:
	if entity == null:
		return {"success": false, "reason": "unknown_entity"}
	if entity.mobility_status == EntityState.MobilityStatus.STATIONARY:
		return {"success": false, "reason": "no_relocation"}
	var definition := _definitions[entity.definition_id] as EntityDefinition
	var previous_status := entity.mobility_status
	if previous_status == EntityState.MobilityStatus.TEARDOWN:
		entity.position = entity.relocation_origin
		_finish(entity)
	elif previous_status == EntityState.MobilityStatus.MOVING:
		entity.relocation_target = entity.position
		entity.relocation_path = PackedVector2Array([entity.position])
		entity.relocation_path_index = 1
		entity.mobility_status = EntityState.MobilityStatus.SETUP
		entity.relocation_remaining = definition.setup_duration
	else:
		entity.relocation_target = entity.position
	_record_event(&"relocation_cancelled", entity, simulation_time, {"previous_status": previous_status})
	return {"success": true, "entity_id": entity.id}


func process_tick(delta: float, simulation_time: float, placements: Array) -> void:
	for entity in placements:
		if entity.mobility_status == EntityState.MobilityStatus.STATIONARY:
			continue
		if not entity.active or entity.damage >= 1.0:
			_record_event(&"relocation_failed", entity, simulation_time, {"reason": "system_failed"})
			_finish(entity)
			continue
		_advance_entity(entity, delta, simulation_time)


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func _advance_entity(entity: EntityState, delta: float, simulation_time: float) -> void:
	var definition := _definitions[entity.definition_id] as EntityDefinition
	var remaining_delta := delta
	for _transition in 4:
		match entity.mobility_status:
			EntityState.MobilityStatus.TEARDOWN:
				var consumed := minf(entity.relocation_remaining, remaining_delta)
				entity.relocation_remaining = maxf(entity.relocation_remaining - consumed, 0.0)
				remaining_delta -= consumed
				if entity.relocation_remaining > EPSILON:
					return
				entity.mobility_status = EntityState.MobilityStatus.MOVING
				entity.relocation_remaining = _remaining_path_distance(entity) / definition.relocation_speed
				_record_event(&"relocation_phase_changed", entity, simulation_time, {"phase": "moving"})
			EntityState.MobilityStatus.MOVING:
				remaining_delta = _advance_path(entity, definition.relocation_speed, remaining_delta)
				entity.relocation_remaining = _remaining_path_distance(entity) / definition.relocation_speed
				if entity.relocation_path_index < entity.relocation_path.size():
					return
				entity.position = entity.relocation_target
				entity.mobility_status = EntityState.MobilityStatus.SETUP
				entity.relocation_remaining = definition.setup_duration
				_record_event(&"relocation_phase_changed", entity, simulation_time, {"phase": "setup"})
			EntityState.MobilityStatus.SETUP:
				var consumed := minf(entity.relocation_remaining, remaining_delta)
				entity.relocation_remaining = maxf(entity.relocation_remaining - consumed, 0.0)
				remaining_delta -= consumed
				if entity.relocation_remaining > EPSILON:
					return
				var target := entity.position
				_finish(entity)
				_record_event(&"relocation_completed", entity, simulation_time, {"target": target})
				return
			_:
				return


func _advance_path(entity: EntityState, speed: float, delta: float) -> float:
	var distance_budget := speed * delta
	while entity.relocation_path_index < entity.relocation_path.size() and distance_budget > EPSILON:
		var waypoint := entity.relocation_path[entity.relocation_path_index]
		var distance := entity.position.distance_to(waypoint)
		if distance <= distance_budget + EPSILON:
			entity.position = waypoint
			entity.relocation_path_index += 1
			distance_budget -= distance
		else:
			entity.position = entity.position.move_toward(waypoint, distance_budget)
			distance_budget = 0.0
	return distance_budget / speed


func _finish(entity: EntityState) -> void:
	entity.mobility_status = EntityState.MobilityStatus.STATIONARY
	entity.relocation_origin = Vector2.ZERO
	entity.relocation_target = Vector2.ZERO
	entity.relocation_path = PackedVector2Array()
	entity.relocation_path_index = 0
	entity.relocation_remaining = 0.0


func _build_route(origin: Vector2, target: Vector2) -> PackedVector2Array:
	var width := maxi(1, ceili(_world_bounds.size.x / _cell_size))
	var height := maxi(1, ceili(_world_bounds.size.y / _cell_size))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2.ONE * _cell_size
	grid.offset = Vector2.ONE * (_cell_size * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var center := grid.offset + Vector2(cell) * grid.cell_size
			var cell_area := Rect2(center - grid.cell_size * 0.5, grid.cell_size)
			var blocked := not _world_bounds.has_point(center) or not _is_in_allowed_zone(center)
			for zone in _blocked_zones:
				blocked = blocked or cell_area.intersects(zone, true)
			if blocked:
				grid.set_point_solid(cell, true)
	var start := Vector2i(floori(origin.x / _cell_size), floori(origin.y / _cell_size))
	var finish := Vector2i(floori(target.x / _cell_size), floori(target.y / _cell_size))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(finish):
		return PackedVector2Array()
	grid.set_point_solid(start, false)
	grid.set_point_solid(finish, false)
	var grid_path := grid.get_point_path(start, finish)
	if grid_path.is_empty():
		return PackedVector2Array()
	var result := PackedVector2Array([origin])
	for index in range(1, grid_path.size() - 1):
		result.append(grid_path[index])
	result.append(target)
	for index in range(1, result.size()):
		if not _segment_is_allowed(result[index - 1], result[index]):
			return PackedVector2Array()
	return result


# Clip complete segments so narrow obstacles between raster points cannot be skipped.
func _segment_rect_interval(start: Vector2, finish: Vector2, area: Rect2) -> Vector2:
	var interval := Vector2(0.0, 1.0)
	var direction := finish - start
	for axis in 2:
		if absf(direction[axis]) <= EPSILON:
			if start[axis] < area.position[axis] or start[axis] > area.end[axis]:
				return Vector2(1.0, -1.0)
		else:
			var first := (area.position[axis] - start[axis]) / direction[axis]
			var last := (area.end[axis] - start[axis]) / direction[axis]
			interval.x = maxf(interval.x, minf(first, last))
			interval.y = minf(interval.y, maxf(first, last))
	return interval


func _segment_is_allowed(start: Vector2, finish: Vector2) -> bool:
	for zone in _blocked_zones:
		var interval := _segment_rect_interval(start, finish, zone)
		if interval.x <= interval.y:
			return false
	var intervals: Array[Vector2] = []
	for zone in _placement_zones:
		var interval := _segment_rect_interval(start, finish, zone)
		if interval.x <= interval.y:
			intervals.append(interval)
	intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var covered := 0.0
	for interval in intervals:
		if interval.x > covered + EPSILON:
			return false
		covered = maxf(covered, interval.y)
	return covered >= 1.0 - EPSILON


func _remaining_path_distance(entity: EntityState) -> float:
	var distance := 0.0
	var previous := entity.position
	for index in range(entity.relocation_path_index, entity.relocation_path.size()):
		distance += previous.distance_to(entity.relocation_path[index])
		previous = entity.relocation_path[index]
	return distance


func _path_distance(path: PackedVector2Array) -> float:
	var distance := 0.0
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance


func _is_in_allowed_zone(position: Vector2) -> bool:
	for zone in _placement_zones:
		if zone.has_point(position):
			return true
	return false


func _is_blocked(position: Vector2) -> bool:
	for zone in _blocked_zones:
		if zone.has_point(position):
			return true
	return false


func _record_event(type: StringName, entity: EntityState, simulation_time: float, data: Dictionary = {}) -> void:
	var event := {
		"type": type,
		"simulation_time": simulation_time,
		"entity_id": String(entity.id),
		"command_id": entity.relocation_command_id,
	}
	event.merge(data, true)
	_events.append(event)
	relocation_event.emit(event)
