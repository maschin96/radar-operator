class_name ScenarioDefinition
extends Resource

@export var scenario_id: StringName
@export var display_name: String
@export_multiline var briefing: String
@export var world_size := Vector2(2000.0, 1200.0)
@export var starting_budget: int = 2500
@export var seed: int = 1
@export var mission_duration: float = 180.0
@export var definitions: Array[Resource] = []
@export var starting_entities: Array[Dictionary] = []
@export var attack_waves: Array[Resource] = []
@export var placement_zones: Array[Rect2] = []
@export var blocked_zones: Array[Rect2] = []
@export var energy_connections: Array[Dictionary] = []
@export var mission_goals: Dictionary = {}
@export var tutorial_steps: Array[Dictionary] = []
