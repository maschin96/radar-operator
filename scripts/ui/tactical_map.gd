class_name TacticalMap
extends Control

signal camera_changed(world_position: Vector2, zoom_level: float)
signal map_clicked(world_position: Vector2)
signal map_hovered(world_position: Vector2)
signal object_selected(kind: StringName, object_id: StringName)

const MIN_ZOOM := 0.45
const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.2
const KEYBOARD_PAN_SPEED := 620.0
const GRID_STEP := 100.0

const LAYER_TERRAIN := &"terrain"
const LAYER_INFRASTRUCTURE := &"infrastructure"
const LAYER_SYSTEMS := &"systems"
const LAYER_TRACKS := &"tracks"
const LAYER_RANGES := &"ranges"
const LAYER_SELECTION := &"selection"

@export var world_size := Vector2(2000.0, 1200.0):
	set(value):
		world_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_clamp_camera()
		queue_redraw()

var camera_world_position := Vector2(1000.0, 600.0)
var zoom_level: float = 0.7
var _is_panning := false
var _infrastructure_states: Array = []
var _placement_states: Array = []
var _track_states: Array = []
var _placement_zones: Array[Rect2] = []
var _blocked_zones: Array[Rect2] = []
var _preview_position := Vector2.ZERO
var _preview_range: float = 0.0
var _preview_visible: bool = false
var _preview_valid: bool = false
var _selected_kind: StringName
var _selected_id: StringName
var high_contrast: bool = false
var reduced_effects: bool = false
var _layers: Dictionary = {
	LAYER_TERRAIN: true,
	LAYER_INFRASTRUCTURE: true,
	LAYER_SYSTEMS: true,
	LAYER_TRACKS: true,
	LAYER_RANGES: true,
	LAYER_SELECTION: true,
}


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	resized.connect(_on_resized)
	_clamp_camera()
	queue_redraw()


func _process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO and has_focus():
		pan_by_screen_delta(-direction * KEYBOARD_PAN_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mouse_button.pressed
			if mouse_button.pressed:
				grab_focus()
			accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mouse_button.position, ZOOM_STEP)
			accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mouse_button.position, 1.0 / ZOOM_STEP)
			accept_event()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_select_or_click(mouse_button.position)
			accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		var mouse_motion := event as InputEventMouseMotion
		pan_by_screen_delta(mouse_motion.relative)
		accept_event()
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		map_hovered.emit(screen_to_world(mouse_motion.position))


func world_to_screen(world_position: Vector2) -> Vector2:
	return (world_position - camera_world_position) * zoom_level + size * 0.5


func screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - size * 0.5) / zoom_level + camera_world_position


func pan_by_screen_delta(screen_delta: Vector2) -> void:
	camera_world_position -= screen_delta / zoom_level
	_clamp_camera()
	_notify_camera_changed()


func zoom_at(screen_position: Vector2, factor: float) -> void:
	var anchored_world_position := screen_to_world(screen_position)
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, MAX_ZOOM)
	camera_world_position = anchored_world_position - (screen_position - size * 0.5) / zoom_level
	_clamp_camera()
	_notify_camera_changed()


func set_camera(world_position: Vector2, new_zoom: float = -1.0) -> void:
	camera_world_position = world_position
	if new_zoom > 0.0:
		zoom_level = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	_clamp_camera()
	_notify_camera_changed()


func set_layer_visible(layer: StringName, visible: bool) -> bool:
	if not _layers.has(layer):
		push_warning("Unknown tactical map layer: %s" % layer)
		return false
	_layers[layer] = visible
	queue_redraw()
	return true


func is_layer_visible(layer: StringName) -> bool:
	return bool(_layers.get(layer, false))


func get_debug_text() -> String:
	return "MAP %.0f, %.0f  //  ZOOM %.0f%%" % [
		camera_world_position.x,
		camera_world_position.y,
		zoom_level * 100.0,
	]


func set_world_state(infrastructure_states: Array, placement_states: Array, track_states: Array) -> void:
	_infrastructure_states = infrastructure_states
	_placement_states = placement_states
	_track_states = track_states
	queue_redraw()


func set_mission_geometry(new_world_size: Vector2, placement_zones: Array[Rect2], blocked_zones: Array[Rect2]) -> void:
	world_size = new_world_size
	_placement_zones = placement_zones.duplicate()
	_blocked_zones = blocked_zones.duplicate()
	set_camera(new_world_size * 0.5, zoom_level)
	queue_redraw()


func set_placement_preview(position: Vector2, range_value: float, valid: bool) -> void:
	_preview_position = position
	_preview_range = range_value
	_preview_valid = valid
	_preview_visible = true
	queue_redraw()


func clear_placement_preview() -> void:
	_preview_visible = false
	queue_redraw()


func set_selected_object(kind: StringName, object_id: StringName) -> void:
	_selected_kind = kind
	_selected_id = object_id
	queue_redraw()


func set_accessibility(high_contrast_enabled: bool, reduced_effects_enabled: bool) -> void:
	high_contrast = high_contrast_enabled
	reduced_effects = reduced_effects_enabled
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07120f"), true)
	if is_layer_visible(LAYER_TERRAIN):
		_draw_terrain()
	if is_layer_visible(LAYER_RANGES):
		_draw_ranges()
	if is_layer_visible(LAYER_INFRASTRUCTURE):
		_draw_infrastructure()
	if is_layer_visible(LAYER_SYSTEMS):
		_draw_systems()
	if is_layer_visible(LAYER_TRACKS):
		_draw_tracks()
	if is_layer_visible(LAYER_SELECTION):
		_draw_selection()
	_draw_frame_and_debug()


func _draw_terrain() -> void:
	var map_rect := Rect2(world_to_screen(Vector2.ZERO), world_size * zoom_level)
	draw_rect(map_rect, Color("0b2119"), true)
	draw_rect(map_rect, Color("39745a"), false, 2.0)

	var start_world := screen_to_world(Vector2.ZERO)
	var end_world := screen_to_world(size)
	var first_x := floorf(maxf(start_world.x, 0.0) / GRID_STEP) * GRID_STEP
	var first_y := floorf(maxf(start_world.y, 0.0) / GRID_STEP) * GRID_STEP
	var line_color := Color(0.16, 0.37, 0.28, 0.42)
	var x := first_x
	while x <= minf(end_world.x, world_size.x):
		draw_line(world_to_screen(Vector2(x, 0.0)), world_to_screen(Vector2(x, world_size.y)), line_color, 1.0)
		x += GRID_STEP
	var y := first_y
	while y <= minf(end_world.y, world_size.y):
		draw_line(world_to_screen(Vector2(0.0, y)), world_to_screen(Vector2(world_size.x, y)), line_color, 1.0)
		y += GRID_STEP
	for zone in _placement_zones:
		var screen_rect := Rect2(world_to_screen(zone.position), zone.size * zoom_level)
		draw_rect(screen_rect, Color(0.30, 0.83, 0.55, 0.055), true)
		draw_rect(screen_rect, Color(0.35, 0.93, 0.63, 0.55), false, 1.5)
	for zone in _blocked_zones:
		var screen_rect := Rect2(world_to_screen(zone.position), zone.size * zoom_level)
		draw_rect(screen_rect, Color(0.92, 0.24, 0.20, 0.10), true)
		draw_rect(screen_rect, Color(0.95, 0.34, 0.28, 0.7), false, 1.5)


func _draw_ranges() -> void:
	if _preview_visible:
		var center := world_to_screen(_preview_position)
		var color := Color("72e2a5") if _preview_valid else Color("f16e58")
		draw_circle(center, _preview_range * zoom_level, Color(color, 0.08))
		draw_arc(center, _preview_range * zoom_level, 0.0, TAU, 80, Color(color, 0.65), 1.5)


func _draw_infrastructure() -> void:
	for state in _infrastructure_states:
		var color := Color("f0c86a") if state.active else Color("77463f")
		_draw_diamond(world_to_screen(state.position), 10.0, color)


func _draw_systems() -> void:
	for state in _placement_states:
		var position: Vector2 = world_to_screen(state.position)
		draw_circle(position, 7.0, Color("72e2a5"))
		draw_line(position + Vector2(-11.0, 0.0), position + Vector2(11.0, 0.0), Color("72e2a5"), 1.0)
		draw_line(position + Vector2(0.0, -11.0), position + Vector2(0.0, 11.0), Color("72e2a5"), 1.0)


func _draw_tracks() -> void:
	for track in _track_states:
		var position: Vector2 = world_to_screen(track.estimated_position)
		var radius: float = maxf(track.uncertainty_radius * zoom_level, 5.0)
		var color := Color("ff5d4a") if track.classification == &"hostile" else Color("8fffd1")
		if not high_contrast:
			color = Color("f16e58") if track.classification == &"hostile" else Color("78d5b1")
		draw_circle(position, radius, Color(color, 0.10))
		draw_arc(position, radius, 0.0, TAU, 40, Color(color, 0.8), 1.5)
		if not reduced_effects:
			draw_line(position, position + track.estimated_velocity * zoom_level * 0.5, color, 2.0)


func _draw_selection() -> void:
	var selected_position: Variant = _find_object_position(_selected_kind, _selected_id)
	if selected_position != null:
		draw_arc(world_to_screen(selected_position), 18.0, 0.0, TAU, 24, Color("eafbd7"), 1.5)


func _draw_frame_and_debug() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("39745a"), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(14.0, size.y - 14.0),
		get_debug_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color("6cae8d")
	)


func _draw_diamond(position: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		position + Vector2(0.0, -radius),
		position + Vector2(radius, 0.0),
		position + Vector2(0.0, radius),
		position + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)


func _select_or_click(screen_position: Vector2) -> void:
	var closest_distance := 18.0
	var closest_kind: StringName
	var closest_id: StringName
	for state in _infrastructure_states:
		var distance: float = world_to_screen(state.position).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_kind = &"infrastructure"
			closest_id = state.id
	for state in _placement_states:
		var distance: float = world_to_screen(state.position).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_kind = &"system"
			closest_id = state.id
	for track in _track_states:
		var distance: float = world_to_screen(track.estimated_position).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_kind = &"track"
			closest_id = track.id
	if not closest_id.is_empty():
		set_selected_object(closest_kind, closest_id)
		object_selected.emit(closest_kind, closest_id)
	else:
		map_clicked.emit(screen_to_world(screen_position))


func _find_object_position(kind: StringName, object_id: StringName) -> Variant:
	var collection: Array
	match kind:
		&"infrastructure":
			collection = _infrastructure_states
		&"system":
			collection = _placement_states
		&"track":
			collection = _track_states
		_:
			return null
	for object in collection:
		if object.id == object_id:
			return object.estimated_position if kind == &"track" else object.position
	return null


func _clamp_camera() -> void:
	if not is_node_ready() and size == Vector2.ZERO:
		return
	var visible_half := size * 0.5 / zoom_level
	if visible_half.x * 2.0 >= world_size.x:
		camera_world_position.x = world_size.x * 0.5
	else:
		camera_world_position.x = clampf(camera_world_position.x, visible_half.x, world_size.x - visible_half.x)
	if visible_half.y * 2.0 >= world_size.y:
		camera_world_position.y = world_size.y * 0.5
	else:
		camera_world_position.y = clampf(camera_world_position.y, visible_half.y, world_size.y - visible_half.y)


func _notify_camera_changed() -> void:
	queue_redraw()
	camera_changed.emit(camera_world_position, zoom_level)


func _on_resized() -> void:
	_clamp_camera()
	queue_redraw()
