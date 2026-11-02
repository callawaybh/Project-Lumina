extends SceneTree

class SyncProbe:
	extends Node
	var setup_calls := 0
	var test_value := 42
	func _setup_synchronizer(_local_id: int) -> void:
		setup_calls += 1
		TMSceneSync.register_variable(self, "test_value")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if CollisionFxManager.get_parent() != TMSceneSync or String(CollisionFxManager.name).is_empty():
		push_error("Collision sound manager was not attached with a valid node name")
		quit(1)
		return
	for index in range(3):
		var extra_sync := GdSceneSynchronizer.new()
		extra_sync.free()
	for cycle in range(3):
		var context := Node.new()
		context.name = "SetupFixture%d" % cycle
		root.add_child(context)
		TMSceneSync.start_sync(context)
		if TMSceneSync.get_parent() != context:
			push_error("Coordinator did not attach to fixture context")
			quit(1)
			return
		var probe := SyncProbe.new()
		probe.name = "RegisteredProbe"
		context.add_child(probe)
		TMSceneSync.register_node(probe)
		if probe.setup_calls != 1:
			push_error("Registered object setup callback was not called exactly once")
			quit(1)
			return
		TMSceneSync.register_node(probe)
		if probe.setup_calls != 1:
			push_error("Repeated registration unexpectedly repeated setup")
			quit(1)
			return
		context.free()
		if TMSceneSync.get_parent() != null:
			push_error("Coordinator did not detach on context teardown")
			quit(1)
			return
	print("LUMINA_SYNC_SETUP_PASS: 3 setup/register/teardown cycles")
	quit(0)
