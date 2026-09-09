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
var _jamming_sampler: Callable
var _decoy_return_provider: Callable


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


func set_electronic_warfare(jamming_sampler: Callable, decoy_return_provider: Callable) -> void:
	_jamming_sampler = jamming_sampler
	_decoy_return_provider = decoy_return_provider


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
	var sorted_threats := threats.duplicate()
	sorted_threats.sort_custom(func(a: ThreatState, b: ThreatState) -> bool: return a.id < b.id)
	for sensor_id in sensor_ids:
		var sensor := _sensors[sensor_id] as SensorState
		var definition := _definitions[sensor.definition_id] as SensorDefinition
		if not sensor.active or not sensor.operational or not sensor.powered:
			# Offline and relocating sensors do not accumulate retroactive scans.
			sensor.next_scan_time = maxf(sensor.next_scan_time, simulation_time + definition.update_interval)
			continue
		while sensor.next_scan_time <= simulation_time + TIME_EPSILON:
			created.append_array(_perform_scan(sensor, definition, sorted_threats, sensor.next_scan_time))
			sensor.scan_count += 1
			scan_completed.emit(sensor.id, sensor.next_scan_time)
			var scan_jamming := _sample_jamming(definition.id, sensor.position, sensor.position, sensor.next_scan_time)
			sensor.next_scan_time += definition.update_interval * (1.0 + scan_jamming * 2.0) / maxf(sensor.network_quality, 0.25)
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
	for threat in threats:
		if not threat.active or threat.resolved:
			continue
		var distance := sensor.position.distance_to(threat.position)
		if distance > definition.detection_range + TIME_EPSILON:
			continue
		var visibility := _sample_terrain_visibility(sensor.position, threat.position, definition.sensor_height)
		if visibility <= 0.0:
			continue
		var threat_definition := _get_threat_definition(threat.definition_id)
		if threat_definition == null:
			continue
		var distance_ratio := clampf(distance / definition.detection_range, 0.0, 1.0)
		var jamming := _sample_jamming(definition.id, sensor.position, threat.position, scan_time)
		var detection_score := (
			threat_definition.signature_strength * 0.75
			+ (1.0 - distance_ratio) * 0.35
			+ definition.resistance * 0.10
			+ _random.randf_range(-0.08, 0.08)
		) * visibility * (1.0 - jamming * 0.65)
		if detection_score < DETECTION_THRESHOLD:
			continue
		var measurement := _create_measurement(
			sensor,
			definition,
			threat,
			threat_definition,
			distance_ratio,
			visibility,
			jamming,
			scan_time
		)
		created.append(measurement)
		_all_measurements.append(measurement)
		measurement_created.emit(measurement)
	created.append_array(_create_decoy_measurements(sensor, definition, scan_time))
	return created


func _create_measurement(
	sensor: SensorState,
	definition: SensorDefinition,
	threat: ThreatState,
	threat_definition: ThreatDefinition,
	distance_ratio: float,
	visibility: float,
	jamming: float,
	scan_time: float
) -> SensorMeasurement:
	var terrain_error_multiplier := lerpf(2.5, 1.0, visibility)
	var maximum_error := definition.position_error * (0.25 + distance_ratio * 0.75) * terrain_error_multiplier * (1.0 + jamming * 2.0)
	var error_distance := sqrt(_random.randf()) * maximum_error
	var error_direction := _random.randf() * TAU
	var position_offset := Vector2.from_angle(error_direction) * error_distance
	var classification := clampf(
		definition.classification_strength
		* (0.4 + threat_definition.signature_strength * 0.6)
		* (1.0 - distance_ratio * 0.35)
		* sensor.network_quality
		* visibility
		* (1.0 - jamming * 0.8),
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
		threat.id,
		{"interference_level": jamming, "signal_consistency": clampf(1.0 - jamming * 0.45, 0.0, 1.0)}
	)
	_next_measurement_id += 1
	return measurement


func _create_decoy_measurements(sensor: SensorState, definition: SensorDefinition, scan_time: float) -> Array[SensorMeasurement]:
	var measurements: Array[SensorMeasurement] = []
	if not _decoy_return_provider.is_valid():
		return measurements
	var returns: Array = _decoy_return_provider.call(sensor.id, definition.id, sensor.position, definition.detection_range, scan_time)
	for return_data in returns:
		var position: Vector2 = return_data.position
		var jamming := _sample_jamming(definition.id, sensor.position, position, scan_time)
		var error := float(return_data.position_error) * (1.0 + jamming * 2.0)
		var classification := clampf(
			definition.classification_strength * float(return_data.signature_strength) * sensor.network_quality * (1.0 - jamming * 0.8),
			0.0,
			1.0
		)
		var measurement := SensorMeasurement.new(
			_next_measurement_id,
			sensor.id,
			position,
			error,
			scan_time,
			classification,
			StringName(return_data.source_id),
			{"interference_level": jamming, "signal_consistency": float(return_data.signal_consistency)}
		)
		_next_measurement_id += 1
		measurements.append(measurement)
		_all_measurements.append(measurement)
		measurement_created.emit(measurement)
	return measurements


func _sample_terrain_visibility(sensor_position: Vector2, threat_position: Vector2, sensor_height: float) -> float:
	if not _terrain_visibility_sampler.is_valid():
		return 1.0
	return clampf(float(_terrain_visibility_sampler.call(sensor_position, threat_position, sensor_height)), 0.0, 1.0)


func _sample_jamming(sensor_definition_id: StringName, sensor_position: Vector2, target_position: Vector2, scan_time: float) -> float:
	if not _jamming_sampler.is_valid():
		return 0.0
	return clampf(float(_jamming_sampler.call(sensor_definition_id, sensor_position, target_position, scan_time)), 0.0, 1.0)


func _get_threat_definition(definition_id: StringName) -> ThreatDefinition:
	return _threat_definitions.get(definition_id) as ThreatDefinition
