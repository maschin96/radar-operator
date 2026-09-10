class_name ReplayTimeline
extends RefCounted

var frames: Array = []
var events: Array = []
var time: float = 0.0
var duration: float = 0.0
var speed: float = 1.0
var playing: bool = false

func configure(recorded_frames: Array, recorded_events: Array) -> void:
	frames = recorded_frames.duplicate(true)
	frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.simulation_time) < float(b.simulation_time))
	events.clear()
	var classifications: Dictionary = {}
	for recorded in recorded_events:
		var event: Dictionary = recorded.duplicate(true)
		if event.type == &"track_created":
			classifications[String(event.data.get("track_id", ""))] = String(event.data.get("classification", ""))
		if event.type == &"track_updated":
			var id := String(event.data.get("track_id", ""))
			var classification := String(event.data.get("classification", ""))
			if classifications.get(id, "") == classification:
				continue
			classifications[id] = classification
			event.type = &"track_classified"
		elif event.type not in [&"track_created", &"track_lost", &"track_release_changed", &"track_priority_changed", &"defense_rules_changed", &"target_assigned", &"engagement_succeeded", &"engagement_failed", &"infrastructure_damaged", &"network_state_changed", &"relocation_started", &"relocation_completed", &"mission_message", &"mission_ended"]:
			continue
		events.append(event)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.simulation_time) == float(b.simulation_time):
			return int(a.index) < int(b.index)
		return float(a.simulation_time) < float(b.simulation_time))
	duration = float(frames[-1].simulation_time) if not frames.is_empty() else 0.0
	time = 0.0
	playing = false

func advance(delta: float) -> void:
	if playing:
		seek(time + maxf(delta, 0.0) * speed)
		if time >= duration:
			playing = false

func seek(value: float) -> void:
	time = clampf(value, 0.0, duration)

func get_frame() -> Dictionary:
	if frames.is_empty():
		return {}
	var low := 0
	var high := frames.size() - 1
	while low < high:
		var middle := (low + high + 1) / 2
		if float(frames[middle].simulation_time) <= time:
			low = middle
		else:
			high = middle - 1
	var result: Dictionary = frames[low].duplicate(true)
	if low + 1 < frames.size():
		var next: Dictionary = frames[low + 1]
		var blend := clampf((time - float(result.simulation_time)) / maxf(float(next.simulation_time) - float(result.simulation_time), 0.000001), 0.0, 1.0)
		for collection in ["tracks", "placements"]:
			var following: Dictionary = {}
			for item in next.get(collection, []):
				following[String(item.id)] = item
			var field := "estimated_position" if collection == "tracks" else "position"
			for item in result.get(collection, []):
				if following.has(String(item.id)):
					var position := point(item.get(field)).lerp(point(following[String(item.id)].get(field)), blend)
					item[field] = {"x": position.x, "y": position.y}
	return result

func event_position(event: Dictionary) -> Variant:
	var position: Variant = nested(event, "position")
	if position != null:
		return point(position)
	var frame := get_frame()
	for field in ["track_id", "entity_id", "target_id", "consumer_id", "source_id"]:
		var id: Variant = nested(event, field)
		if id == null:
			continue
		for collection in ["tracks", "placements", "infrastructure"]:
			for item in frame.get(collection, []):
				if String(item.id) == String(id):
					return point(item.get("estimated_position", item.get("position")))
	return null

static func point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
	return Vector2.ZERO

static func nested(value: Variant, key: String) -> Variant:
	if value is Dictionary:
		if value.has(key):
			return value[key]
		for child in value.values():
			var found: Variant = nested(child, key)
			if found != null:
				return found
	return null

static func label(event: Dictionary) -> String:
	if event.type == &"track_release_changed":
		return {0: "Automatische Regeln wiederhergestellt", 1: "Kontakt manuell freigegeben", 2: "Kontakt manuell gesperrt"}.get(int(event.data.get("release_status", 0)), "Freigabe geändert")
	return {
		&"track_created": "Kontakt erfasst", &"track_classified": "Klassifikation geändert",
		&"track_lost": "Kontakt verloren", &"track_release_changed": "Manuelle Freigabe/Sperre geändert",
		&"track_priority_changed": "Trackpriorität geändert", &"defense_rules_changed": "Einsatzregeln geändert",
		&"target_assigned": "Ziel zugewiesen", &"engagement_succeeded": "Abwehr erfolgreich",
		&"engagement_failed": "Abwehr fehlgeschlagen", &"infrastructure_damaged": "Infrastruktur getroffen",
		&"network_state_changed": "Netzzustand geändert", &"relocation_started": "Verlegung begonnen",
		&"relocation_completed": "Verlegung abgeschlossen", &"mission_message": String(event.get("data", {}).get("message", "Lagemeldung")),
		&"mission_ended": "Einsatz beendet",
	}.get(StringName(event.type), "Ereignis")
