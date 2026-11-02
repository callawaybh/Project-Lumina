extends SceneTree
const Retarget = preload("res://dance_retarget.gd")
func _initialize():
	var paths={"actual":"C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/avatars/mpfb-test/Lumina_Test_Adult_Mirror_v3.glb","canonical":"C:/Dev/LuminaClient/mirror-godot-app/player/character_models/astronaut/astronaut_updated.glb"}
	var output={}
	for key in paths:
		var state=GLTFState.new();state.set_handle_binary_image(GLTFState.HANDLE_BINARY_DISCARD_TEXTURES)
		var doc=GLTFDocument.new();assert(doc.append_from_file(paths[key],state,8)==OK)
		var node=doc.generate_scene(state);root.add_child(node)
		var skeleton:Skeleton3D=node.find_children("*","Skeleton3D",true,false)[0]
		skeleton.motion_scale=skeleton.get_bone_global_rest(skeleton.find_bone("Hips")).origin.y
		var start=Time.get_ticks_msec();var clip=Retarget.animation_for(skeleton)
		var player := AnimationPlayer.new()
		node.add_child(player)
		player.root_node = player.get_path_to(node)
		var applied: Animation = clip.duplicate(true)
		for track in range(applied.get_track_count()):
			applied.track_set_path(track, NodePath(str(node.get_path_to(skeleton)) + ":" + str(applied.track_get_path(track).get_subname(0))))
		var library := AnimationLibrary.new()
		library.add_animation(&"dance_twerk", applied)
		player.add_animation_library(&"lumina_emotes", library)
		var poses=[]
		for t in [0.0,1.5,4.0,6.0,10.0,14.0]:
			skeleton.reset_bone_poses()
			player.play(&"lumina_emotes/dance_twerk")
			player.seek(t, true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			var bones={}
			for bone in range(skeleton.get_bone_count()):
				var pose=skeleton.get_bone_global_pose(bone);var q=pose.basis.get_rotation_quaternion()
				assert(pose.is_finite())
				bones[skeleton.get_bone_name(bone)]={"position":[pose.origin.x,pose.origin.y,pose.origin.z],"rotation":[q.x,q.y,q.z,q.w]}
			poses.append({"time":t,"bones":bones})
		assert(Retarget.animation_for(skeleton)==clip)
		output[key]={"samples":poses,"bake_ms":Time.get_ticks_msec()-start,"motion_scale":skeleton.motion_scale}
		node.free()
	var f=FileAccess.open("C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/animations/dance-test/corrected_native_poses.json",FileAccess.WRITE);f.store_string(JSON.stringify(output));f.close()
	print("LUMINA_CORRECTED_NATIVE_POSES_SAVED");quit()
