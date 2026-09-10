extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var settings := SettingsManager.new()
	var values := settings.get_defaults()
	values.alerts_volume = 0.0
	values.atmosphere_volume = 0.6
	settings.apply(values)
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "Effects were not muted independently")
	expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Atmosphere")), "Effects mute incorrectly muted atmosphere")
	var audio := AudioManager.new()
	root.add_child(audio)
	audio.apply_settings(values)
	var messages: Array[String] = []
	audio.radio_message.connect(func(message: String) -> void: messages.append(message))
	audio.handle_event({"type": &"infrastructure_damaged", "simulation_time": 1.0})
	expect(not messages.is_empty(), "Radio text unavailable without a system voice")
	expect(audio._players.Atmosphere.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Atmosphere does not loop")
	var map := TacticalMap.new()
	root.add_child(map)
	map.set_accessibility(true, true)
	map.present_event({"type": &"infrastructure_damaged", "data": {"position": Vector2(300, 200)}})
	expect(map._visual_events.size() == 1, "Reduced effects removed critical static feedback")
	map._process(1.3)
	expect(map._visual_events.is_empty(), "Event effects never expire")
	for index in 100:
		map.present_event({"type": &"track_created", "data": {"position": Vector2.ZERO}})
	expect(map._visual_events.size() == 32, "Visual effect queue is not bounded")
	audio.queue_free()
	map.queue_free()
	await process_frame
	settings.apply(settings.get_defaults())
	for failure in failures: push_error(failure)
	print("PRESENTATION TESTS PASSED: 3 test cases" if failures.is_empty() else "PRESENTATION TESTS FAILED")
	quit(0 if failures.is_empty() else 1)
func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
