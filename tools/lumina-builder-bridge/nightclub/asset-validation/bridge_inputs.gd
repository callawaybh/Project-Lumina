extends SceneTree
func _initialize():
	var source = FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/scripts/autoload/lumina_bridge.gd")
	var validator = "func _checked_asset_path" + source.split("func _checked_asset_path",true,1)[1].split("func _import_prepared_asset",true,1)[0]
	var script=GDScript.new()
	script.source_code = 'extends RefCounted\nconst DIR = "C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/nightclub/"\nvar Zone = {"space": {"_id": "6ae4703d5754d729b3dbf699"}}\n' + validator
	assert(script.reload()==OK)
	var api=script.new()
	var space="6ae4703d5754d729b3dbf699"
	assert(api._checked_asset_path({"space_id":space,"file":"bar_counter.glb"}).ok)
	assert(api._checked_asset_path({"space_id":space,"file":"lumina_original_loop.wav"},true).ok)
	for q in [{"space_id":"wrong","file":"bar_counter.glb"},{"space_id":space,"file":"../models/bar_counter.glb"},{"space_id":space,"file":"../secret.glb"},{"space_id":space,"file":"code.gd"},{"space_id":space,"file":"missing.glb"},{"space_id":space,"file":7}]:
		assert(not api._checked_asset_path(q).ok)
	print("LUMINA_MODEL_INPUTS_PASS: exact Space, prepared filenames, asset types and headers")
	quit()
