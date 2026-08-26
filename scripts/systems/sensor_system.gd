class_name SensorSystem
extends RefCounted

signal measurement_created(measurement: SensorMeasurement)
signal scan_completed(sensor_id: StringName, scan_time: float)

const DETECTION_THRESHOLD := 0.55
const TIME_EPSILON := 0.000000001

var _definitions: Dictionary = {}
var _threat_definitions: Dictionary = {}
var _sensors: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _next_measurement_id: int = 1
var _all_measurements: Array[SensorMeasurement] = []
var _terrain_visibility_sampler: Callable


func configure(scenario: ScenarioDefinition) -> void:
	_definitions.clear()
	_threat_definitions.clear()
	_sensors.clear()
	_all_measurements.clear()
	_next_measurement_id = 1
	_random.seed = scenario.seed ^ 0x5E4502
	for definition in scenario.definitions:
		if definition is SensorDefinition:
			_definitions[definition.id] = definition
		elif definition is ThreatDefinition:
			_threat_definitions[definition.id] = definition


func set_terrain_visibility_sampler(sampler: Callable) -> void:
	_terrain_visibility_sampler = sampler


func add_sensor(sensor: SensorState) -> bool:
	if _sensors.has(sensor.id):
		push_warning("Duplicate sensor entity id: %s" % sensor.id)
		return false
	if not _definitions.has(sensor.definition_id):
		push_warning("Unknown sensor definition: %s" % sensor.definition_id)
		return false
	_sensors[sensor.id] = sensor
	return true


func process_tick(simulation_time: float, threats: Array) -> Array[SensorMeasurement]:
	var created: Array[SensorMeasurement] = []
	var sensor_ids: Array = _sensors.keys()
	sensor_ids.sort()
	for sensor_id in sensor_ids:
		var sensor := _sensors[sensor_id] as SensorState
		if not sensor.active or not sensor.operational or not sensor.powered:
			continue
		var definition := _definitions[sensor.definition_id] as SensorDefinition
		while sensor.next_scan_time <= simulation_time + TIME_EPSILON:
			created.append_array(_perform_scan(sensor, definition, threats, sensor.next_scan_time))
			sensor.scan_count += 1
			scan_completed.emit(sensor.id, sensor.next_scan_time)
			sensor.next_scan_time += definition.update_interval
	return created


func get_measurements() -> Array[SensorMeasurement]:
	return _all_measurements.duplicate()


func get_sensors() -> Array[SensorState]:
	var result: Array[SensorState] = []
	for sensor in _sensors.values():
		result.append(sensor)
	result.sort_custom(func(a: SensorState, b: SensorState) -> bool: return a.id < b.id)
	return result


func _perform_scan(
	sensor: SensorState,
	definition: SensorDefinition,
	threats: Array,
	scan_time: float
) -> Array[SensorMeasurement]:
	var created: Array[SensorMeasurement] = []
	var sorted_threats := threats.duplicate()
	sorted_threats.sort_custom(func(a: ThreatState, b: ThreatState) -> bool: return a.id < b.id)
	for threat in sorted_threats:
		if not threat.active or threat.resolved:
			continue
		var distance := sensor.position.distance_to(threat.position)
		if distance > definition.detection_range + TIME_EPSILON:
			continue
		var visibility := _sample_terrain_visibility(sensor.position, threat.position)
		if visibility <= 0.0:
			continue
		var threat_definition := _get_threat_definition(threat.definition_id)
		if threat_definition == null:
			continue
		var distance_ratio := clampf(distance / definition.detection_range, 0.0, 1.0)
		var detection_score := (
			threat_definition.signature_strength * 0.75
			+ (1.0 - distance_ratio) * 0.35
			+ definition.resistance * 0.10
			+ _random.randf_range(-0.08, 0.08)
		) * visibility
		if detection_score < DETECTION_THRESHOLD:
			continue
		var measurement := _create_measurement(
			sensor,
			definition,
			threat,
			threat_definition,
			distance_ratio,
			scan_time
		)
		created.append(measurement)
		_all_measurements.append(measurement)
		measurement_created.emit(measurement)
	return created


func _create_measurement(
	sensor: SensorState,
	definition: SensorDefinition,
	threat: ThreatState,
	threat_definition: ThreatDefinition,
	distance_ratio: float,
	scan_time: float
) -> SensorMeasurement:
	var maximum_error := definition.position_error * (0.25 + distance_ratio * 0.75)
	var error_distance := sqrt(_random.randf()) * maximum_error
	var error_direction := _random.randf() * TAU
	var position_offset := Vector2.from_angle(error_direction) * error_distance
	var classification := clampf(
		definition.classification_strength
		* (0.4 + threat_definition.signature_strength * 0.6)
		* (1.0 - distance_ratio * 0.35),
		0.0,
		1.0
	)
	var measurement := SensorMeasurement.new(
		_next_measurement_id,
		sensor.id,
		threat.position + position_offset,
		maximum_error,
		scan_time,
		classification,
		threat.id
	)
	_next_measurement_id += 1
	return measurement


func _sample_terrain_visibility(sensor_position: Vector2, threat_position: Vector2) -> float:
	if not _terrain_visibility_sampler.is_valid():
		return 1.0
	return clampf(float(_terrain_visibility_sampler.call(sensor_position, threat_position)), 0.0, 1.0)


func _get_threat_definition(definition_id: StringName) -> ThreatDefinition:
	return _threat_definitions.get(definition_id) as ThreatDefinition
