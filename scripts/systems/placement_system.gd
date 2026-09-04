class_name PlacementSystem
extends RefCounted

signal placement_added(entity: EntityState)
signal placement_moved(entity: EntityState)
signal placement_removed(entity_id: StringName)
signal deployment_started

const MINIMUM_SPACING := 30.0

var _definitions: Dictionary = {}
var _placements: Dictionary = {}
var _costs_by_entity: Dictionary = {}
var _world_bounds: Rect2
var _placement_zones: Array[Rect2] = []
var _blocked_zones: Array[Rect2] = []
var _budget: int = 0
var _initial_budget: int = 0
var _next_entity_number: int = 1
var _preparation_active: bool = true


func configure(scenario: ScenarioDefinition) -> void:
	_definitions.clear()
	_placements.clear()
	_costs_by_entity.clear()
	_world_bounds = Rect2(Vector2.ZERO, scenario.world_size)
	_placement_zones = scenario.placement_zones.duplicate()
	if _placement_zones.is_empty():
		_placement_zones.append(_world_bounds)
	_blocked_zones = scenario.blocked_zones.duplicate()
	_budget = scenario.starting_budget
	_initial_budget = scenario.starting_budget
	_next_entity_number = 1
	_preparation_active = true
	for definition in scenario.definitions:
		if definition is SensorDefinition or definition is DefenseDefinition:
			_definitions[definition.id] = definition


func preview_placement(definition_id: StringName, position: Vector2, ignored_entity_id: StringName = &"") -> Dictionary:
	var reasons: Array[String] = []
	if not _preparation_active:
		reasons.append("deployment_started")
	if not _definitions.has(definition_id):
		reasons.append("unknown_definition")
		return {"valid": false, "reasons": reasons, "range": 0.0, "cost": 0}
	var definition := _definitions[definition_id] as EntityDefinition
	if definition.purchase_cost > _budget and ignored_entity_id.is_empty():
		reasons.append("insufficient_budget")
	if not _world_bounds.has_point(position):
		reasons.append("outside_map")
	if not _is_in_allowed_zone(position):
		reasons.append("outside_placement_zone")
	if _is_in_blocked_zone(position):
		reasons.append("blocked_zone")
	for entity in _placements.values():
		if entity.id != ignored_entity_id and entity.position.distance_to(position) < MINIMUM_SPACING:
			reasons.append("too_close_to_system")
			break
	return {
		"valid": reasons.is_empty(),
		"reasons": reasons,
		"range": get_definition_range(definition_id),
		"cost": definition.purchase_cost,
	}


func place(definition_id: StringName, position: Vector2) -> Dictionary:
	var preview := preview_placement(definition_id, position)
	if not preview.valid:
		return {"success": false, "reasons": preview.reasons}
	var entity_id := StringName("placed_%04d" % _next_entity_number)
	_next_entity_number += 1
	var definition := _definitions[definition_id] as EntityDefinition
	var entity: EntityState
	if definition is SensorDefinition:
		entity = SensorState.new(entity_id, definition_id, position)
	elif definition is DefenseDefinition:
		entity = DefenseState.new(entity_id, definition_id, position, definition.ammunition)
	else:
		entity = EntityState.new(entity_id, definition_id, &"player", position)
	_placements[entity_id] = entity
	_costs_by_entity[entity_id] = definition.purchase_cost
	_budget -= definition.purchase_cost
	placement_added.emit(entity)
	return {"success": true, "entity": entity}


func move(entity_id: StringName, position: Vector2) -> Dictionary:
	if not _placements.has(entity_id):
		return {"success": false, "reasons": ["unknown_entity"]}
	var entity := _placements[entity_id] as EntityState
	var preview := preview_placement(entity.definition_id, position, entity_id)
	if not preview.valid:
		return {"success": false, "reasons": preview.reasons}
	entity.position = position
	placement_moved.emit(entity)
	return {"success": true, "entity": entity}


func remove(entity_id: StringName) -> bool:
	if not _preparation_active or not _placements.has(entity_id):
		return false
	_budget += int(_costs_by_entity.get(entity_id, 0))
	_placements.erase(entity_id)
	_costs_by_entity.erase(entity_id)
	placement_removed.emit(entity_id)
	return true


func start_deployment() -> bool:
	if not _preparation_active:
		return false
	_preparation_active = false
	deployment_started.emit()
	return true


func get_budget() -> int:
	return _budget


func get_initial_budget() -> int:
	return _initial_budget


func spend_budget(amount: int) -> bool:
	if amount < 0 or amount > _budget:
		return false
	_budget -= amount
	return true


func is_preparation_active() -> bool:
	return _preparation_active


func get_placements() -> Array[EntityState]:
	var result: Array[EntityState] = []
	for entity in _placements.values():
		result.append(entity)
	result.sort_custom(func(a: EntityState, b: EntityState) -> bool: return a.id < b.id)
	return result


func get_placement(entity_id: StringName) -> EntityState:
	return _placements.get(entity_id) as EntityState


func get_catalog() -> Array[EntityDefinition]:
	var result: Array[EntityDefinition] = []
	for definition in _definitions.values():
		result.append(definition)
	result.sort_custom(func(a: EntityDefinition, b: EntityDefinition) -> bool: return a.purchase_cost < b.purchase_cost)
	return result


func get_definition_range(definition_id: StringName) -> float:
	var definition := _definitions.get(definition_id) as EntityDefinition
	if definition is SensorDefinition:
		return definition.detection_range
	if definition is DefenseDefinition:
		return definition.engagement_range
	return 0.0


func _is_in_allowed_zone(position: Vector2) -> bool:
	for zone in _placement_zones:
		if zone.has_point(position):
			return true
	return false


func _is_in_blocked_zone(position: Vector2) -> bool:
	for zone in _blocked_zones:
		if zone.has_point(position):
			return true
	return false
