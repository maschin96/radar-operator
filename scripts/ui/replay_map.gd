class_name ReplayMap
extends Control

var frame: Dictionary = {}
var colorblind_mode: bool = false
var world_size := Vector2(2000, 1200)
var focus_position: Variant = null

func _ready() -> void:
	clip_contents = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07120f"))
	var scale_factor := minf(size.x / world_size.x, size.y / world_size.y)
	var center := world_size * 0.5
	if focus_position != null:
		center = focus_position
		scale_factor *= 1.6
	for connection in frame.get("network_connections", []):
		var from := (ReplayTimeline.point(connection.get("source_position")) - center) * scale_factor + size * 0.5
		var to := (ReplayTimeline.point(connection.get("consumer_position")) - center) * scale_factor + size * 0.5
		draw_line(from, to, Color("39715d") if int(connection.get("status", 0)) == 0 else Color("e9b84d"), 1.0)
	for collection in ["infrastructure", "placements", "tracks"]:
		for item in frame.get(collection, []):
			var position := (ReplayTimeline.point(item.get("estimated_position", item.get("position"))) - center) * scale_factor + size * 0.5
			var color := Color("78d5b1")
			if collection == "tracks":
				color = RadarSymbols.contact_color(StringName(item.get("classification", "unknown")), colorblind_mode)
				RadarSymbols.contact(self, position, StringName(item.get("classification", "unknown")), color, int(item.get("release_status", 0)) == 2)
				draw_arc(position, maxf(6.0, float(item.get("uncertainty_radius", 0.0)) * scale_factor), 0, TAU, 24, Color(color, 0.3))
			else:
				color = Color("6d8178") if not bool(item.get("active", true)) else color
				draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 8)), color, collection == "infrastructure")
			draw_string(ThemeDB.fallback_font, position + Vector2(7, -5), String(item.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if focus_position != null:
		draw_arc(size * 0.5, 14.0, 0, TAU, 32, Color.WHITE, 2.0)
