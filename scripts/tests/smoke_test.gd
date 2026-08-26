extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/app/main.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_script := load(MAIN_SCRIPT_PATH) as Script
	if main_script == null:
		_fail("Could not parse main script: %s" % MAIN_SCRIPT_PATH)
		return

	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load main scene: %s" % MAIN_SCENE_PATH)
		return

	var main_screen := packed_scene.instantiate()
	if main_screen.get_script() == null:
		_fail("Main scene has no valid script attached")
		return
	root.add_child(main_screen)
	await process_frame

	if main_screen.name != "Main":
		_fail("Unexpected root node: %s" % main_screen.name)
		return

	var title := main_screen.get_node_or_null("Margin/Layout/Header/Title") as Label
	if title == null:
		_fail("Main scene title is missing")
		return
	if title.text != "RADAR OPERATOR":
		_fail("Main scene title text is unexpected")
		return
	var tactical_map := main_screen.get_node_or_null("Margin/Layout/Body/TacticalMap")
	if tactical_map == null:
		_fail("Main scene tactical map is missing")
		return

	print("SMOKE TEST PASSED: project and main scene initialized")
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE TEST FAILED: %s" % message)
	quit(1)
