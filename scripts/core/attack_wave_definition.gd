class_name AttackWaveDefinition
extends Resource

@export var id: StringName
@export var start_time: float = 5.0
@export var spawns: Array[Dictionary] = []


func get_validation_errors(definitions_by_id: Dictionary, world_size: Vector2) -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Attack wave has an empty id")
	if start_time < 0.0:
		errors.append("Attack wave '%s' has a negative start time" % id)
	var spawn_ids: Dictionary = {}
	for spawn in spawns:
		var spawn_id := StringName(spawn.get("id", ""))
		var definition_id := StringName(spawn.get("definition_id", ""))
		var route: Variant = spawn.get("route")
		var completion := StringName(spawn.get("completion", "target"))
		if spawn_id.is_empty() or spawn_ids.has(spawn_id):
			errors.append("Attack wave '%s' has an empty or duplicate spawn id '%s'" % [id, spawn_id])
		spawn_ids[spawn_id] = true
		if not definitions_by_id.has(definition_id):
			errors.append("Attack spawn '%s' references missing definition '%s'" % [spawn_id, definition_id])
		elif (definitions_by_id[definition_id] as EntityDefinition).category != EntityDefinition.Category.THREAT:
			errors.append("Attack spawn '%s' does not reference a threat definition" % spawn_id)
		if float(spawn.get("delay", 0.0)) < 0.0:
			errors.append("Attack spawn '%s' has a negative delay" % spawn_id)
		if not route is PackedVector2Array or route.size() < 2:
			errors.append("Attack spawn '%s' requires at least two route points" % spawn_id)
		else:
			for point in route:
				if point.x < 0.0 or point.y < 0.0 or point.x > world_size.x or point.y > world_size.y:
					errors.append("Attack spawn '%s' has a route point outside the map" % spawn_id)
					break
		if completion not in [&"target", &"exit"]:
			errors.append("Attack spawn '%s' has invalid completion '%s'" % [spawn_id, completion])
	return errors
