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
	return validate_data(to_dictionary())


static func validate_data(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["profile_id", "display_name", "minimum_classification", "automatic_release", "allow_redundant_engagement", "infrastructure_priorities"]:
		if not data.has(key):
			errors.append("Unvollständiges Profil: '%s' fehlt." % key)
	if not errors.is_empty():
		return errors
	for key in ["profile_id", "display_name", "minimum_classification"]:
		if not (data[key] is String or data[key] is StringName) or String(data[key]).strip_edges().is_empty():
			errors.append("Profilname, Kennung und Mindestklassifikation dürfen nicht leer sein.")
	if not ["unknown", "air_contact", "suspicious", "hostile"].has(data.minimum_classification):
		errors.append("Unbekannte Mindestklassifikation.")
	for key in ["automatic_release", "allow_redundant_engagement"]:
		if not data[key] is bool:
			errors.append("Freigabe und redundante Einsätze benötigen Ja/Nein-Werte.")
	if not errors.is_empty():
		return errors
	if data.automatic_release == true and data.minimum_classification == "unknown":
		errors.append("Automatische Freigabe für unbekannte Kontakte ist unsicher. Wählen Sie mindestens Luftkontakt oder manuelle Freigabe.")
	if not data.infrastructure_priorities is Dictionary:
		errors.append("Schutzprioritäten müssen als Zuordnung vorliegen.")
	else:
		for id in data.infrastructure_priorities:
			var value: Variant = data.infrastructure_priorities[id]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 3.0:
				errors.append("Schutzpriorität für '%s' muss eine endliche Zahl zwischen 0 und 3 sein." % id)
	return errors
