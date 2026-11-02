extends SceneTree
func _initialize():
	var doc=GLTFDocument.new();var state=GLTFState.new()
	assert(doc.append_from_file("C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/nightclub/models/starry_sky.glb",state)==OK)
	var scene=doc.generate_scene(state)
	var meshes=scene.find_children("*","MeshInstance3D",true,false)
	if scene is MeshInstance3D: meshes.append(scene)
	assert(meshes.size()==1)
	var mi:MeshInstance3D=meshes[0]
	assert(mi.mesh.get_aabb().size.is_equal_approx(Vector3(600,600,600)))
	var mat:BaseMaterial3D=mi.get_active_material(0)
	assert(mat.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert(mat.albedo_texture.get_width()==4096 and mat.albedo_texture.get_height()==2048)
	assert(mat.cull_mode==BaseMaterial3D.CULL_DISABLED)
	scene.free()
	print("LUMINA_SKY_PASS: 600 m unlit panorama sphere, embedded 4K texture, visible from inside")
	quit()
