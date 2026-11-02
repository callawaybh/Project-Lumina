extends SceneTree
var seat_count := 0
var light_count := 0
var emission_count := 0
func scan(node: Node) -> void:
	if node.has_meta("OMI_seat"):
		seat_count += 1
		var seat: Dictionary = node.get_meta("OMI_seat")
		assert(seat.foot is Vector3 and seat.knee is Vector3 and seat.back is Vector3)
		assert(seat.upper_leg_dir.is_finite() and seat.spine_dir.is_finite())
	if node is Light3D:
		light_count += 1
		assert(node.light_energy > 0 and node.light_energy <= 3)
		assert(not node.shadow_enabled)
	if node is MeshInstance3D:
		assert(node.mesh != null)
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(i)
			assert(mat is BaseMaterial3D)
			if mat.emission_enabled:
				emission_count += 1
				assert(mat.emission_energy_multiplier > 1)
	for child in node.get_children(): scan(child)
func _initialize():
	var extension = load("C:/Dev/LuminaClient/mirror-godot-app/addons/omi_extensions/misc/omi_seat.gd").new()
	GLTFDocument.register_gltf_document_extension(extension)
	var dir = "C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/nightclub/models/"
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(dir+"manifest.json"))
	for name in manifest:
		seat_count=0; light_count=0; emission_count=0
		var document=GLTFDocument.new()
		var state=GLTFState.new()
		assert(document.append_from_file(dir+name+".glb",state)==OK,name)
		var scene=document.generate_scene(state)
		assert(scene != null,name)
		scan(scene)
		assert(seat_count == int(manifest[name].seats),name+" seat mismatch")
		assert(light_count == int(manifest[name].lights),name+" light mismatch")
		assert(emission_count == int(manifest[name].emissive_surfaces),name+" emission mismatch")
		scene.free()
	print("LUMINA_ASSETS_PASS: ",manifest.size()," modules; native geometry/material/seat/light imports verified")
	quit()
