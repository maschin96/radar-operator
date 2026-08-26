class_name AudioManager
extends Node

const SAMPLE_RATE := 22050
const TONE_DURATION := 0.09

var alerts_enabled: bool = true
var _player: AudioStreamPlayer
var _last_alert_time: float = -100.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -16.0
	add_child(_player)


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null


func handle_event(event: Dictionary) -> void:
	if not alerts_enabled:
		return
	var priority := _event_priority(StringName(event.get("type", "")))
	if priority <= 0:
		return
	var event_time := float(event.get("simulation_time", 0.0))
	var cooldown := 0.2 if priority >= 3 else 0.6
	if event_time - _last_alert_time < cooldown:
		return
	_last_alert_time = event_time
	var frequency := 880.0 if priority >= 3 else 560.0
	_player.stream = _create_tone(frequency, TONE_DURATION)
	_player.play()


func set_alert_volume(linear_value: float) -> void:
	if _player != null:
		_player.volume_db = linear_to_db(clampf(linear_value, 0.0001, 1.0))


func _event_priority(type: StringName) -> int:
	match type:
		&"mission_ended", &"infrastructure_damaged", &"power_state_changed":
			return 3
		&"threat_entered", &"track_created", &"engagement_failed":
			return 2
		&"engagement_succeeded":
			return 1
		_:
			return 0


func _create_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var envelope := 1.0 - float(index) / sample_count
		var sample := int(sin(TAU * frequency * index / SAMPLE_RATE) * 7000.0 * envelope)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
