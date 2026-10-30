extends SceneTree

const Diagnostics = preload("C:/Dev/LuminaClient/mirror-godot-app/scripts/diagnostics/player_state_diagnostics.gd")

func _function_source(source: String, method: String) -> String:
	var result := ""
	var collecting := false
	for line in source.split("\n"):
		if line.begins_with("func " + method + "("):
			collecting = true
		elif collecting and not line.is_empty() and not line.begins_with("\t"):
			break
		if collecting:
			result += line + "\n"
	assert(not result.is_empty())
	return result

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Diagnostics.invalid_reason({"body": Transform3D.IDENTITY, "velocity": Vector3.ZERO, "delta": 0.0}).is_empty())
	assert(Diagnostics.invalid_reason({"position": Vector3(NAN, 0, 0)}) == "position")
	assert(Diagnostics.invalid_reason({"alpha": INF}) == "alpha")
	assert(Diagnostics.invalid_reason({"positive_delta": 0.0}) == "positive_delta")
	assert(Diagnostics.invalid_reason({"positive_scale": -1.0}) == "positive_scale")
	assert(Diagnostics.invalid_reason({"body": Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)}) == "body")
	var snapshot: Dictionary = Diagnostics.snapshot("test", {"position": Vector3(NAN, 0, 0)})
	assert(JSON.parse_string(JSON.stringify(snapshot)) is Dictionary)
	# Extract the actual production guard, replacing only its Zone dependency.
	var source := FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/player/player.gd")
	var script := GDScript.new()
	script.source_code = "extends Node3D\nconst _STATE_DIAGNOSTICS = preload(\"C:/Dev/LuminaClient/mirror-godot-app/scripts/diagnostics/player_state_diagnostics.gd\")\nvar _lumina_faulted := false\nvar _lumina_history: Array = []\nclass Zone:\n\tstatic var client\n\tstatic func is_host(): return true\n" + _function_source(source, "_lumina_guard")
	assert(script.reload() == OK)
	var player := Node3D.new()
	player.set_script(script)
	root.add_child(player)
	ProjectSettings.set_setting("mirror/env_name", "official")
	assert(player._lumina_guard("outside_local", {"position": Vector3(NAN, 0, 0)}))
	assert(not player._lumina_faulted)
	ProjectSettings.set_setting("mirror/env_name", "local")
	for index in 20:
		assert(player._lumina_guard("healthy", {"body": Transform3D.IDENTITY}))
	assert(player._lumina_history.size() == 12)
	var directory := "res://.lumina-bridge/diagnostics"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var before := DirAccess.get_files_at(directory)
	assert(not player._lumina_guard("physics.native_result", {"body": Transform3D(Basis.IDENTITY, Vector3(NAN, 0, 0))}))
	assert(not player._lumina_guard("later_duplicate", {"body": Transform3D.IDENTITY}))
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED)
	var created := 0
	for filename in DirAccess.get_files_at(directory):
		if filename not in before:
			created += 1
			var report = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(filename)))
			assert(report.invalid_field == "body")
			assert(report.fault.stage == "physics.native_result")
			assert(report.preceding_checks.size() == 12)
	assert(created == 1)
	print("PASS: invalid-state detection, local-only scope, bounded history, one report, stop-once guard. Expected exit code: 2")
	player.free()
