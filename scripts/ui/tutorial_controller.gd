class_name TutorialController
extends RefCounted

signal step_changed(step: Dictionary, index: int, total: int)
signal tutorial_completed

var _steps: Array[Dictionary] = []
var _current_index: int = 0
var _active: bool = false


func initialize(steps: Array[Dictionary]) -> void:
	_steps.clear()
	for step in steps:
		_steps.append(step.duplicate(true))
	_current_index = 0
	_active = not _steps.is_empty()
	if _active:
		step_changed.emit(get_current_step(), _current_index, _steps.size())


func notify(action: StringName, data: Dictionary = {}) -> Dictionary:
	if not _active:
		return {"advanced": false}
	var step := get_current_step()
	if StringName(step.get("trigger", "")) != action or not _matches(step, data):
		return {"advanced": false}
	return _advance(step)


func update_from_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _active:
		return {"advanced": false}
	var trigger := StringName(get_current_step().get("trigger", ""))
	match trigger:
		&"track_detected":
			if not (snapshot.get("tracks", []) as Array).is_empty():
				return notify(&"track_detected")
		&"mission_finished":
			if int(snapshot.get("phase", GameSession.Phase.PREPARATION)) == GameSession.Phase.ENDED:
				return notify(&"mission_finished")
	return {"advanced": false}


func skip() -> void:
	if not _active:
		return
	_active = false
	_current_index = _steps.size()
	tutorial_completed.emit()


func is_active() -> bool:
	return _active


func get_current_index() -> int:
	return _current_index


func get_step_count() -> int:
	return _steps.size()


func get_current_step() -> Dictionary:
	if not _active or _current_index < 0 or _current_index >= _steps.size():
		return {}
	return _steps[_current_index].duplicate(true)


func _matches(step: Dictionary, data: Dictionary) -> bool:
	var expected_definition := StringName(step.get("definition_id", ""))
	if not expected_definition.is_empty() and StringName(data.get("definition_id", "")) != expected_definition:
		return false
	var expected_kind := StringName(step.get("object_kind", ""))
	if not expected_kind.is_empty() and StringName(data.get("object_kind", "")) != expected_kind:
		return false
	var minimum_scale := float(step.get("minimum_scale", 0.0))
	if minimum_scale > 0.0 and float(data.get("time_scale", 0.0)) < minimum_scale:
		return false
	return true


func _advance(completed_step: Dictionary) -> Dictionary:
	_current_index += 1
	if _current_index >= _steps.size():
		_active = false
		tutorial_completed.emit()
	else:
		step_changed.emit(get_current_step(), _current_index, _steps.size())
	return {
		"advanced": true,
		"completed_step": completed_step.duplicate(true),
		"completed": not _active,
	}
