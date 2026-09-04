class_name TerrainVisibilitySystem
extends RefCounted

const VISIBILITY_SCALE := 1000
const TARGET_CLEARANCE := 80
const HEIGHT_PENALTY_RANGE := 240

var _world_size := Vector2.ZERO
var _cell_size: float = 50.0
var _columns: int = 0
var _rows: int = 0
var _height_grid := PackedInt32Array()
var _factor_grid := PackedInt32Array()
var _masks: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0
var _generated_cells: int = 0
var _last_generation_usec: int = 0


func configure(scenario: ScenarioDefinition) -> void:
	_world_size = scenario.world_size
	_cell_size = scenario.terrain_cell_size
	_columns = ceili(_world_size.x / _cell_size)
	_rows = ceili(_world_size.y / _cell_size)
	_height_grid.resize(_columns * _rows)
	_factor_grid.resize(_columns * _rows)
	_height_grid.fill(roundi(scenario.terrain_default_height))
	_factor_grid.fill(VISIBILITY_SCALE)
	_masks.clear()
	_cache_hits = 0
	_cache_misses = 0
	_generated_cells = 0
	_last_generation_usec = 0
	for zone in scenario.terrain_zones:
		_apply_area(zone)
	for blocker in scenario.visibility_blockers:
		_apply_area(blocker)


func prepare_visibility_mask(origin: Vector2, maximum_range: float, sensor_height: float = 20.0) -> Dictionary:
	var origin_cell := _world_to_cell(origin)
	var mask_origin := _cell_center(origin_cell)
	var range_cells := ceili(maximum_range / _cell_size)
	var key := "%d:%d:%d:%d" % [origin_cell.x, origin_cell.y, roundi(maximum_range * 1000.0), roundi(sensor_height * 1000.0)]
	if _masks.has(key):
		_cache_hits += 1
		return (_masks[key] as Dictionary).duplicate(true)
	_cache_misses += 1
	var started := Time.get_ticks_usec()
	var min_x := maxi(origin_cell.x - range_cells, 0)
	var max_x := mini(origin_cell.x + range_cells, _columns - 1)
	var min_y := maxi(origin_cell.y - range_cells, 0)
	var max_y := mini(origin_cell.y + range_cells, _rows - 1)
	var width := max_x - min_x + 1
	var height := max_y - min_y + 1
	var values := PackedInt32Array()
	values.resize(width * height)
	var range_squared := maximum_range * maximum_range
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			var value := 0
			if mask_origin.distance_squared_to(_cell_center(cell)) <= range_squared:
				value = _trace_visibility(origin_cell, cell, roundi(sensor_height))
			values[(y - min_y) * width + x - min_x] = value
	_generated_cells += values.size()
	_last_generation_usec = Time.get_ticks_usec() - started
	var mask := {
		"origin": mask_origin,
		"cell_size": _cell_size,
		"offset": Vector2i(min_x, min_y),
		"width": width,
		"height": height,
		"maximum_range": maximum_range,
		"sensor_height": sensor_height,
		"values": values,
	}
	_masks[key] = mask
	return mask.duplicate(true)


func sample_visibility(origin: Vector2, target: Vector2, sensor_height: float = 20.0) -> float:
	var origin_cell := _world_to_cell(origin)
	var target_cell := _world_to_cell(target)
	for mask in _masks.values():
		if _world_to_cell(mask.origin) != origin_cell:
			continue
		if not is_equal_approx(float(mask.sensor_height), sensor_height):
			continue
		var offset: Vector2i = mask.offset
		var local := target_cell - offset
		if local.x >= 0 and local.y >= 0 and local.x < int(mask.width) and local.y < int(mask.height):
			return float(mask.values[local.y * int(mask.width) + local.x]) / VISIBILITY_SCALE
	return float(_trace_visibility(origin_cell, target_cell, roundi(sensor_height))) / VISIBILITY_SCALE


func get_cache_stats() -> Dictionary:
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"mask_count": _masks.size(),
		"generated_cells": _generated_cells,
		"last_generation_usec": _last_generation_usec,
	}


func get_cell_data(cell: Vector2i) -> Dictionary:
	if not _cell_in_bounds(cell):
		return {}
	var index := _index(cell)
	return {"height": _height_grid[index], "visibility_factor": float(_factor_grid[index]) / VISIBILITY_SCALE}


func _apply_area(data: Dictionary) -> void:
	var area: Rect2 = data.area
	var start := _world_to_cell(area.position)
	var end := _world_to_cell(area.end - Vector2(0.0001, 0.0001))
	var height := roundi(float(data.get("height", 0.0)))
	var factor := clampi(roundi(float(data.get("visibility_factor", 1.0)) * VISIBILITY_SCALE), 0, VISIBILITY_SCALE)
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if not _cell_in_bounds(cell):
				continue
			var index := _index(cell)
			_height_grid[index] = maxi(_height_grid[index], height)
			_factor_grid[index] = mini(_factor_grid[index], factor)


func _trace_visibility(origin: Vector2i, target: Vector2i, sensor_height: int) -> int:
	var x := origin.x
	var y := origin.y
	var dx := absi(target.x - origin.x)
	var sx := 1 if origin.x < target.x else -1
	var dy := -absi(target.y - origin.y)
	var sy := 1 if origin.y < target.y else -1
	var error := dx + dy
	var visibility := VISIBILITY_SCALE
	var observer_height := _height_grid[_index(origin)] + sensor_height
	var target_height := _height_grid[_index(target)] + TARGET_CLEARANCE
	var total_steps := maxi(dx, -dy)
	var step := 0
	while true:
		var cell := Vector2i(x, y)
		if _cell_in_bounds(cell):
			var index := _index(cell)
			visibility = mini(visibility, _factor_grid[index])
			if step > 0 and step < total_steps:
				var expected_height := observer_height
				if total_steps > 0:
					expected_height += int((target_height - observer_height) * step / total_steps)
				var excess := maxi(_height_grid[index] - expected_height, 0)
				var height_factor := clampi(VISIBILITY_SCALE - excess * VISIBILITY_SCALE / HEIGHT_PENALTY_RANGE, 100, VISIBILITY_SCALE)
				visibility = mini(visibility, height_factor)
		if x == target.x and y == target.y:
			break
		var doubled := 2 * error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy
		step += 1
	return visibility


func _world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(position.x / _cell_size), 0, _columns - 1),
		clampi(floori(position.y / _cell_size), 0, _rows - 1)
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * _cell_size, (cell.y + 0.5) * _cell_size)


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _columns and cell.y < _rows


func _index(cell: Vector2i) -> int:
	return cell.y * _columns + cell.x
