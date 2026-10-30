extends SceneTree

# Exercise the production spawn methods without loading the game or its services.
func _function_source(source: String, method: String) -> String:
	var lines := source.split("\n")
	var result := ""
	var collecting := false
	for line in lines:
		if line.begins_with("func " + method + "("):
			collecting = true
		elif collecting and not line.is_empty() and not line.begins_with("\t"):
			break
		if collecting:
			result += line + "\n"
	assert(not result.is_empty(), "Production method missing: " + method)
	return result

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/player/player.gd")
	var radius_constant := ""
	for line in source.split("\n"):
		if line.begins_with("const SPAWN_RADIUS ="):
			radius_constant = line
	var script := GDScript.new()
	script.source_code = "extends Node3D\n" + radius_constant + "\nfunc _lumina_guard(_stage, _values): return true\n" + _function_source(source, "_calculate_spawn_transform") + _function_source(source, "_random_point_in_circle_vec3")
	assert(script.reload() == OK)
	var player := Node3D.new()
	player.set_script(script)
	root.add_child(player)
	for path in [NodePath(""), NodePath("MissingMarker")]:
		for iteration in 50:
			var spawn: Transform3D = player._calculate_spawn_transform(path)
			assert(spawn.is_finite())
			assert(spawn.origin.length() <= player.SPAWN_RADIUS + 0.001)
			assert(spawn.basis.is_equal_approx(Basis.IDENTITY))
	var marker := Node3D.new()
	marker.name = "SpawnMarker"
	player.add_child(marker)
	marker.position = Vector3(10, 3, -4)
	marker.rotation.y = 0.6
	marker.scale = Vector3.ONE * 2
	for iteration in 50:
		var spawn: Transform3D = player._calculate_spawn_transform(NodePath("SpawnMarker"))
		assert(spawn.is_finite())
		assert(spawn.origin.distance_to(marker.global_position) <= player.SPAWN_RADIUS * 2 + 0.001)
		assert(spawn.basis.is_equal_approx(marker.global_basis))
	print("PASS: empty, missing, and valid spawn markers (150 trials)")
	player.free()
	quit(0)
