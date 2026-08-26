class_name AppLog
extends RefCounted


static func info(context: StringName, message: String) -> void:
	print("[INFO] [%s] %s" % [context, message])


static func warning(context: StringName, message: String) -> void:
	push_warning("[%s] %s" % [context, message])


static func error(context: StringName, message: String) -> void:
	push_error("[%s] %s" % [context, message])
