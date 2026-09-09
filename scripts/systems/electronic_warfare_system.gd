class_name ElectronicWarfareSystem
extends RefCounted

const EPSILON := 0.000001

var _seed: int
var _zones: Array[Dictionary] = []
var _decoys: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _last_zone_levels: Dictionary = {}
var _emitted_slots: Dictionary = {}
var _total_decoy_returns: int = 0


func configure(scenario: ScenarioDefinition) -> void:
	_seed = scenario.seed ^ 0xE1EC7
	_zones = scenario.jamming_zones.duplicate(true)
	_decoys = scenario.decoy_emitters.duplicate(true)
	_events.clear()
	_last_zone_levels.clear()
	_emitted_slots.clear()
	_total_decoy_returns = 0


func process_tick(simulation_time: float) -> void:
	for zone in _zones:
		var id := String(zone.get("id", ""))
		var level := _curve_value(zone.get("strength_curve", []), simulation_time) * float(zone.get("strength", 0.0))
		var quantized := roundi(level * 1000.0)
		if int(_last_zone_levels.get(id, -1)) == quantized:
			continue
		_last_zone_levels[id] = quantized
		_events.append({
			"type": &"jamming_level_changed",
			"simulation_time": simulation_time,
			"zone_id": id,
			"level": quantized / 1000.0,
		})


func sample_jamming(sensor_definition_id: StringName, sensor_position: Vector2, target_position: Vector2, simulation_time: float) -> float:
	var strongest := 0.0
	for zone in _zones:
		if not _affects_sensor(zone, sensor_definition_id):
			continue
		var area: Rect2 = zone.get("area", Rect2())
		if not area.has_point(sensor_position) and not area.has_point(target_position):
			continue
		var strength := float(zone.get("strength", 0.0)) * _curve_value(zone.get("strength_curve", []), simulation_time)
		strongest = maxf(strongest, strength)
	return clampf(strongest, 0.0, 1.0)


func get_decoy_returns(sensor_id: StringName, sensor_definition_id: StringName, sensor_position: Vector2, sensor_range: float, scan_time: float) -> Array[Dictionary]:
	var returns: Array[Dictionary] = []
	for decoy in _decoys:
		if not _affects_sensor(decoy, sensor_definition_id):
			continue
		var start_time := float(decoy.get("start_time", 0.0))
		var end_time := float(decoy.get("end_time", start_time))
		if scan_time + EPSILON < start_time or scan_time - EPSILON > end_time:
			continue
		var interval := float(decoy.get("measurement_interval", 1.0))
		var slot := floori((scan_time - start_time + EPSILON) / interval)
		var emission_key := "%s:%s" % [String(decoy.get("id", "")), String(sensor_id)]
		if slot <= int(_emitted_slots.get(emission_key, -1)):
			continue
		_emitted_slots[emission_key] = slot
		var position := _position_on_route(decoy.get("route", PackedVector2Array()), start_time, end_time, scan_time)
		if sensor_position.distance_to(position) > sensor_range + EPSILON:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed ^ String(decoy.get("id", "")).hash() ^ String(sensor_id).hash() ^ slot * 7919
		var error_radius := float(decoy.get("position_error", 35.0))
		var jitter := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * error_radius
		var return_data := {
			"source_id": StringName("return_%08x" % abs(String(decoy.get("id", "")).hash())),
			"position": position + jitter,
			"position_error": error_radius,
			"signature_strength": float(decoy.get("signature_strength", 0.65)),
			"signal_consistency": clampf(float(decoy.get("signal_consistency", 0.45)) + rng.randf_range(-0.08, 0.08), 0.0, 1.0),
		}
		returns.append(return_data)
		_total_decoy_returns += 1
		_events.append({
			"type": &"anomalous_return_observed",
			"simulation_time": scan_time,
			"sensor_id": String(sensor_id),
			"position": return_data.position,
			"interference_level": sample_jamming(sensor_definition_id, sensor_position, position, scan_time),
		})
	return returns


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func get_player_state(simulation_time: float) -> Dictionary:
	var levels: Dictionary = {}
	for zone in _zones:
		levels[String(zone.get("id", ""))] = sample_zone_level(zone, simulation_time)
	return {"zone_levels": levels}


func get_persistence_state(simulation_time: float) -> Dictionary:
	return {
		"zone_levels": get_player_state(simulation_time).zone_levels,
		"emitted_slots": _emitted_slots.duplicate(true),
		"total_decoy_returns": _total_decoy_returns,
	}


func sample_zone_level(zone: Dictionary, simulation_time: float) -> float:
	return clampf(float(zone.get("strength", 0.0)) * _curve_value(zone.get("strength_curve", []), simulation_time), 0.0, 1.0)


func _curve_value(curve: Array, simulation_time: float) -> float:
	if curve.is_empty():
		return 1.0
	if simulation_time < float(curve[0].get("time", 0.0)):
		return 0.0
	for index in range(1, curve.size()):
		var right: Dictionary = curve[index]
		if simulation_time <= float(right.get("time", 0.0)):
			var left: Dictionary = curve[index - 1]
			var span := maxf(float(right.time) - float(left.time), EPSILON)
			return lerpf(float(left.strength), float(right.strength), clampf((simulation_time - float(left.time)) / span, 0.0, 1.0))
	return float(curve[-1].get("strength", 0.0))


func _position_on_route(route: PackedVector2Array, start_time: float, end_time: float, simulation_time: float) -> Vector2:
	if route.is_empty():
		return Vector2.ZERO
	if route.size() == 1:
		return route[0]
	var progress := clampf((simulation_time - start_time) / maxf(end_time - start_time, EPSILON), 0.0, 1.0)
	var total_distance := 0.0
	for index in range(1, route.size()):
		total_distance += route[index - 1].distance_to(route[index])
	var remaining := progress * total_distance
	for index in range(1, route.size()):
		var segment := route[index - 1].distance_to(route[index])
		if remaining <= segment:
			return route[index - 1].lerp(route[index], remaining / maxf(segment, EPSILON))
		remaining -= segment
	return route[-1]


func _affects_sensor(data: Dictionary, sensor_definition_id: StringName) -> bool:
	var affected: PackedStringArray = data.get("affected_sensor_ids", PackedStringArray())
	return affected.is_empty() or affected.has(String(sensor_definition_id))
