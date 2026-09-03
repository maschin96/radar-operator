class_name ScenarioDefinition
extends Resource

const CURRENT_CONTENT_VERSION := 1
const CURRENT_NETWORK_MODEL_VERSION := 1

@export_group("Catalog Metadata")
@export var content_version: int = CURRENT_CONTENT_VERSION
@export var scenario_id: StringName
@export var display_name: String
@export_multiline var summary: String
@export var campaign_order: int = 0
@export var unlock_requires: PackedStringArray = PackedStringArray()
@export_range(1, 240, 1) var expected_duration_minutes: int = 15
@export var learning_objectives: PackedStringArray = PackedStringArray()

@export_group("Mission")
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
@export_group("Network")
@export var network_model_version: int = CURRENT_NETWORK_MODEL_VERSION
@export var network_connections: Array[Dictionary] = []
@export var network_defaults: Dictionary = {
	"system_power_reserve": 8.0,
	"system_communication_reserve": 5.0,
	"degraded_fraction": 0.5,
	"recovery_duration": 2.0,
}
@export var engagement_profile: EngagementRuleProfile
@export var mission_goals: Dictionary = {}
@export var tutorial_steps: Array[Dictionary] = []
