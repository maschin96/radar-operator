class_name AudioManager
extends Node

signal radio_message(text: String)

const SAMPLE_RATE := 22050
const RADIO_LINES := {
	&"track_created": "Leitstand: Neuer Kontakt erfasst.",
	&"engagement_failed": "Abwehr: Kontakt besteht weiter.",
	&"infrastructure_damaged": "Alarm: Infrastruktur getroffen.",
	&"network_state_changed": "Technik: Versorgungszustand geändert.",
	&"relocation_completed": "Einheit: Verlegung abgeschlossen.",
}
var alerts_enabled: bool = true
var _players: Dictionary = {}
var _cache: Dictionary = {}
var _last_alert: Dictionary = {}
var _last_radio: float = -100.0
var _voice: String = ""
var _voice_volume: float = 0.64

func _ready() -> void:
	for category in ["Effects", "Atmosphere"]:
		SettingsManager.ensure_audio_bus(category)
		var player := AudioStreamPlayer.new()
		player.bus = category
		add_child(player)
		_players[category] = player
	if DisplayServer.get_name() != "headless":
		var voices := DisplayServer.tts_get_voices_for_language("de")
		if not voices.is_empty():
			_voice = voices[0]
	var atmosphere := _create_tone(55.0, 2.0, true)
	_players.Atmosphere.stream = atmosphere
	_players.Atmosphere.volume_db = -28.0
	if DisplayServer.get_name() != "headless":
		_players.Atmosphere.play()

func _exit_tree() -> void:
	for player in _players.values():
		player.stop()
		player.stream = null
	if not _voice.is_empty():
		DisplayServer.tts_stop()

func apply_settings(settings: Dictionary) -> void:
	alerts_enabled = bool(settings.get("alerts_enabled", true))
	_voice_volume = float(settings.get("voice_volume", 0.8)) * float(settings.get("master_volume", 0.8))
	if _voice_volume <= 0.0 and not _voice.is_empty():
		DisplayServer.tts_stop()

func handle_event(event: Dictionary) -> void:
	var type := StringName(event.get("type", ""))
	var now := Time.get_ticks_msec() / 1000.0
	var priority := _event_priority(type)
	if alerts_enabled and priority > 0 and now - float(_last_alert.get(priority, -100.0)) >= (0.3 if priority == 3 else 0.8):
		_last_alert[priority] = now
		_play_cue("alarm" if priority == 3 else "contact" if priority == 2 else "success")
	var line := String(event.get("data", {}).get("message", "")) if type == &"mission_message" else String(RADIO_LINES.get(type, ""))
	if not line.is_empty() and (now - _last_radio >= 5.0 or type in [&"infrastructure_damaged", &"mission_message"]):
		_last_radio = now
		radio_message.emit(line)
		if alerts_enabled and not _voice.is_empty() and _voice_volume > 0.0:
			DisplayServer.tts_speak(line, _voice, int(_voice_volume * 100.0), 0.95, 1.0, 0, true)

func play_ui_feedback() -> void:
	_play_cue("ui")

func _play_cue(cue: String) -> void:
	if not _players.has("Effects"):
		return
	if not _cache.has(cue):
		var frequency: float = {"ui": 1040.0, "contact": 560.0, "success": 740.0, "alarm": 880.0}[cue]
		_cache[cue] = _create_tone(frequency, 0.04 if cue == "ui" else 0.26 if cue == "alarm" else 0.12)
	_players.Effects.stream = _cache[cue]
	if DisplayServer.get_name() != "headless":
		_players.Effects.play()

func set_alert_volume(linear_value: float) -> void:
	SettingsManager.set_bus_volume("Effects", linear_value)

func _event_priority(type: StringName) -> int:
	match type:
		&"mission_ended", &"infrastructure_damaged", &"power_state_changed": return 3
		&"track_created", &"engagement_failed", &"network_state_changed": return 2
		&"engagement_succeeded", &"relocation_completed": return 1
		_: return 0

func _create_tone(frequency: float, duration: float, loop: bool = false) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var t := float(index) / SAMPLE_RATE
		var envelope := 1.0 if loop else minf(t / 0.006, 1.0) * pow(1.0 - float(index) / sample_count, 2.0)
		var wave := sin(TAU * frequency * t) * 0.8 + sin(TAU * frequency * 2.0 * t) * 0.2
		var sample := int(wave * 5000.0 * envelope)
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream
