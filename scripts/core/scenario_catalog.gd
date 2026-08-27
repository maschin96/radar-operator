class_name ScenarioCatalog
extends RefCounted

const ScenarioLoaderScript := preload("res://scripts/core/scenario_loader.gd")
const DEFAULT_SCENARIO_DIRECTORY := "res://data/scenarios"

var scenarios: Array[ScenarioDefinition] = []
var errors: Array[String] = []
var _by_id: Dictionary = {}


func discover(directory_path: String = DEFAULT_SCENARIO_DIRECTORY) -> Dictionary:
	scenarios.clear()
	errors.clear()
	_by_id.clear()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		errors.append("Scenario catalog directory does not exist: %s" % directory_path)
		return _result()
	var paths: PackedStringArray = []
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "tres":
			paths.append(directory_path.path_join(file_name))
	paths.sort()
	var loaded_scenarios: Array[ScenarioDefinition] = []
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource is ScenarioDefinition:
			loaded_scenarios.append(resource as ScenarioDefinition)
	return build_from_scenarios(loaded_scenarios)


func build_from_scenarios(source_scenarios: Array[ScenarioDefinition]) -> Dictionary:
	scenarios.clear()
	errors.clear()
	_by_id.clear()
	var loader := ScenarioLoaderScript.new()
	var campaign_orders: Dictionary = {}
	for scenario in source_scenarios:
		for error in loader.validate_scenario(scenario):
			errors.append("Scenario '%s': %s" % [scenario.scenario_id, error])
		if _by_id.has(scenario.scenario_id):
			errors.append("Duplicate scenario id: %s" % scenario.scenario_id)
		else:
			_by_id[scenario.scenario_id] = scenario
		if campaign_orders.has(scenario.campaign_order):
			errors.append("Duplicate campaign order %d: '%s' and '%s'" % [
				scenario.campaign_order,
				campaign_orders[scenario.campaign_order],
				scenario.scenario_id,
			])
		else:
			campaign_orders[scenario.campaign_order] = scenario.scenario_id
	for scenario in source_scenarios:
		for required_id in scenario.unlock_requires:
			if not _by_id.has(StringName(required_id)):
				errors.append("Scenario '%s' unlock references missing scenario '%s'" % [scenario.scenario_id, required_id])
	if not errors.is_empty():
		return _result()
	scenarios.assign(source_scenarios)
	scenarios.sort_custom(func(left: ScenarioDefinition, right: ScenarioDefinition) -> bool:
		if left.campaign_order == right.campaign_order:
			return String(left.scenario_id) < String(right.scenario_id)
		return left.campaign_order < right.campaign_order
	)
	return _result()


func get_scenario(scenario_id: StringName) -> ScenarioDefinition:
	return _by_id.get(scenario_id) as ScenarioDefinition


func _result() -> Dictionary:
	return {
		"success": errors.is_empty(),
		"errors": errors.duplicate(),
		"scenarios": scenarios.duplicate(),
	}
