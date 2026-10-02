class_name RadarSymbols
extends RefCounted

static func contact(canvas: CanvasItem, position: Vector2, classification: StringName, color: Color, blocked: bool = false) -> void:
	if classification == &"hostile":
		canvas.draw_colored_polygon(PackedVector2Array([position + Vector2(0, -7), position + Vector2(7, 6), position + Vector2(-7, 6)]), color)
	elif classification == &"friendly":
		canvas.draw_rect(Rect2(position - Vector2(5, 5), Vector2(10, 10)), color, false, 2.0)
	else:
		canvas.draw_arc(position, 6.0, 0, TAU, 20, color, 2.0)
	if blocked:
		canvas.draw_line(position + Vector2(-8, -8), position + Vector2(8, 8), Color.WHITE, 2.0)

static func contact_color(classification: StringName, colorblind: bool = false) -> Color:
	if colorblind:
		return Color("ffb454") if classification == &"hostile" else Color("75cfff")
	return Color("f16e58") if classification == &"hostile" else Color("78d5b1")
