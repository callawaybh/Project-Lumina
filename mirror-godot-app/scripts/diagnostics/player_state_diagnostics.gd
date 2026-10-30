extends RefCounted
## Local fault reports; no credentials or command-line arguments.
static func invalid_reason(values: Dictionary) -> String:
	for key in values:
		var value = values[key]
		var valid := true
		if value is float:
			valid = is_finite(value)
			if str(key).begins_with("positive_"):
				valid = valid and value > 0.0
		elif value is Vector2 or value is Vector3 or value is Basis:
			valid = value.is_finite()
		elif value is Transform3D:
			valid = value.is_finite() and absf(value.basis.determinant()) > 0.0000000001
		if not valid:
			return str(key)
	return ""

static func snapshot(stage: String, values: Dictionary) -> Dictionary:
	var rendered := {}
	for key in values:
		# Preserve NaN/Infinity as strings, since they are invalid JSON numbers.
		rendered[str(key)] = str(values[key])
	return {"stage": stage, "ticks_ms": Time.get_ticks_msec(), "values": rendered}

static func save_report(player: Node, stage: String, values: Dictionary, history: Array, role: String) -> String:
	var directory := "res://.lumina-bridge/diagnostics"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := "%s/player-fault-%s-%s.json" % [directory, OS.get_process_id(), Time.get_ticks_usec()]
	var report := {
		"time_utc": Time.get_datetime_string_from_system(true),
		"process_id": OS.get_process_id(), "role": role,
		"player_path": str(player.get_path()), "invalid_field": invalid_reason(values),
		"fault": snapshot(stage, values), "preceding_checks": history, "stack": get_stack()
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "report write failed: " + str(FileAccess.get_open_error())
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return ProjectSettings.globalize_path(path)
