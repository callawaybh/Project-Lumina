extends SceneTree

func _initialize():
	call_deferred("run_checks")

func run_checks():
	var context = Node3D.new()
	context.name = "IsolatedPhysicsFixture"
	root.add_child(context)
	TMSceneSync.start_sync(context)
	var floor_body = JBody3D.new()
	floor_body.body_mode = 0
	floor_body.layer_name = &"STATIC"
	var floor_shape = JBoxShape3D.new()
	floor_shape.size = Vector3(20,1,20)
	floor_body.shape = floor_shape
	floor_body.position.y = -1
	context.add_child(floor_body)
	for trial in 24:
		var character = TMCharacter3D.new()
		character.body_mode = 1
		character.layer_name = &"CHARACTER"
		var capsule = JCapsuleShape3D.new()
		capsule.height = 1.75
		capsule.radius = .3
		character.shape = capsule
		character.position = Vector3(0,2,0)
		context.add_child(character)
		if not character.has_body_id():
			push_error("Fixture did not create a native character body")
			quit(1)
			return
		if trial % 2 == 1: character.add_impulse(Vector3(1,0,0))
		for step in 4:
			character.process_character(1.0/30.0,Vector2.ZERO if step != 2 else Vector2(1,0),false,false,9.8)
			if not character.linear_velocity.is_finite() or not character.global_transform.is_finite():
				push_error("Native character produced invalid first-step/movement state")
				quit(1)
				return
			if step == 0 and trial % 2 == 0 and abs(character.linear_velocity.x) > 0.01:
				push_error("Fresh character inherited an earlier object's pending impulse")
				quit(1)
				return
		# Exercise allocator reuse with an impulse that was never consumed.
		character.add_impulse(Vector3(7000,0,0))
		character.free()
	floor_body.free()
	context.free()
	print("LUMINA_NATIVE_CHARACTER_PASS: 24 fresh characters, 96 finite physics steps, with/without initial impulse")
	quit()
