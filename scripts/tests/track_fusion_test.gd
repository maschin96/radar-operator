extends SceneTree

const FusionScript := preload("res://scripts/systems/track_fusion_system.gd")
const MeasurementScript := preload("res://scripts/simulation/sensor_measurement.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_repeated_measurements_stabilize_one_track()
	_test_multiple_sensors_improve_track_quality()
	_test_uncertainty_grows_and_stale_track_is_removed()
	_test_near_contacts_from_same_scan_stay_separate()
	_test_classification_progresses()
	_test_reproducible_input_produces_reproducible_tracks()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("TEST FAILED: %s" % failure)
		quit(1)
		return
	print("TRACK FUSION TESTS PASSED: 6 test cases")
	quit(0)


func _measurement(
	id: int,
	sensor_id: StringName,
	position: Vector2,
	error_radius: float,
	time: float,
	evidence: float = 0.3
) -> Variant:
	return MeasurementScript.new(id, sensor_id, position, error_radius, time, evidence, &"debug_only")


func _test_repeated_measurements_stabilize_one_track() -> void:
	var fusion: Variant = FusionScript.new()
	fusion.process_measurements([_measurement(1, &"s1", Vector2(100.0, 100.0), 35.0, 0.0)], 0.0)
	fusion.process_measurements([_measurement(2, &"s1", Vector2(108.0, 101.0), 30.0, 1.0)], 1.0)
	fusion.process_measurements([_measurement(3, &"s1", Vector2(115.0, 102.0), 25.0, 2.0)], 2.0)
	var tracks: Array = fusion.get_active_tracks()
	_expect(tracks.size() == 1, "Repeated matching measurements did not stabilize one track")
	if tracks.size() == 1:
		_expect(tracks[0].measurement_count == 3, "Track did not count all measurements")
		_expect(not tracks[0].last_update_summary.is_empty(), "Track lacks last-update explanation")


func _test_multiple_sensors_improve_track_quality() -> void:
	var fusion: Variant = FusionScript.new()
	fusion.process_measurements([_measurement(1, &"s1", Vector2(300.0, 300.0), 60.0, 0.0)], 0.0)
	var before: float = fusion.get_active_tracks()[0].uncertainty_radius
	fusion.process_measurements([_measurement(2, &"s2", Vector2(304.0, 298.0), 35.0, 0.0)], 0.0)
	var track: Variant = fusion.get_active_tracks()[0]
	_expect(track.uncertainty_radius < before, "Second sensor did not reduce uncertainty")
	_expect(track.reporting_sensors.size() == 2, "Track did not retain both reporting sensors")


func _test_uncertainty_grows_and_stale_track_is_removed() -> void:
	var fusion: Variant = FusionScript.new()
	fusion.process_measurements([_measurement(1, &"s1", Vector2.ZERO, 20.0, 0.0)], 0.0)
	var initial_uncertainty: float = fusion.get_active_tracks()[0].uncertainty_radius
	fusion.process_measurements([], 5.0)
	_expect(fusion.get_active_tracks()[0].uncertainty_radius > initial_uncertainty, "Uncertainty did not grow without measurements")
	fusion.process_measurements([], 12.01)
	_expect(fusion.get_active_tracks().is_empty(), "Stale track was not removed")
	_expect(_has_event(fusion.get_events(), &"track_lost"), "Track loss event was not recorded")


func _test_near_contacts_from_same_scan_stay_separate() -> void:
	var fusion: Variant = FusionScript.new()
	var simultaneous := [
		_measurement(1, &"s1", Vector2(500.0, 500.0), 70.0, 0.0),
		_measurement(2, &"s1", Vector2(560.0, 500.0), 70.0, 0.0),
	]
	fusion.process_measurements(simultaneous, 0.0)
	_expect(fusion.get_active_tracks().size() == 2, "Two nearby same-scan contacts were merged")


func _test_classification_progresses() -> void:
	var fusion: Variant = FusionScript.new()
	for index in 6:
		fusion.process_measurements([
			_measurement(index + 1, &"s1", Vector2(700.0 + index, 200.0), 20.0, float(index), 0.75)
		], float(index))
	var track: Variant = fusion.get_active_tracks()[0]
	_expect(track.classification == &"hostile", "Strong repeated evidence did not reach hostile classification")


func _test_reproducible_input_produces_reproducible_tracks() -> void:
	var first: Variant = FusionScript.new()
	var second: Variant = FusionScript.new()
	for fusion in [first, second]:
		fusion.process_measurements([_measurement(1, &"a", Vector2(40.0, 70.0), 30.0, 0.0)], 0.0)
		fusion.process_measurements([_measurement(2, &"b", Vector2(44.0, 68.0), 20.0, 1.0)], 1.0)
	var first_data: Dictionary = first.get_active_tracks()[0].to_player_dictionary()
	var second_data: Dictionary = second.get_active_tracks()[0].to_player_dictionary()
	_expect(first_data == second_data, "Identical measurement input produced different tracks")


func _has_event(events: Array, type: StringName) -> bool:
	for event in events:
		if event.type == type:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
