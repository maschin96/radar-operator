class_name EngagementRuleProfile
extends Resource

@export var profile_id: StringName = &"default"
@export var display_name: String = "Standard"
@export var minimum_classification: StringName = &"suspicious"
@export var automatic_release: bool = true
@export var allow_redundant_engagement: bool = false
@export var infrastructure_priorities: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"profile_id": String(profile_id),
		"display_name": display_name,
		"minimum_classification": String(minimum_classification),
		"automatic_release": automatic_release,
		"allow_redundant_engagement": allow_redundant_engagement,
		"infrastructure_priorities": infrastructure_priorities.duplicate(true),
	}


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.is_empty():
		errors.append("Regelprofil besitzt keine ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Regelprofil besitzt keinen Anzeigenamen.")
	if not DefenseSystem.CLASSIFICATION_RANK.has(minimum_classification):
		errors.append("Unbekannte Mindestklassifikation '%s'." % minimum_classification)
	for infrastructure_id in infrastructure_priorities:
		var priority := float(infrastructure_priorities[infrastructure_id])
		if priority < 0.0 or priority > 3.0:
			errors.append("Schutzpriorität für '%s' muss zwischen 0 und 3 liegen." % infrastructure_id)
	return errors
