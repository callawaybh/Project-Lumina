extends SceneTree
func _initialize():
	var source=FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/scripts/autoload/lumina_bridge.gd")
	var fn="func _saved_value_matches"+source.split("func _saved_value_matches",true,1)[1]
	var script=GDScript.new();script.source_code="extends RefCounted\n"+fn
	assert(script.reload()==OK)
	var api=script.new()
	assert(api._saved_value_matches([0,-1.5707963267949,0],[0,-PI/2,0]))
	assert(not api._saved_value_matches([0,-1.5,0],[0,-PI/2,0]))
	assert(not api._saved_value_matches([0,0],[0,0,0]))
	assert(not api._saved_value_matches("asset-a","asset-b"))
	assert(not api._saved_value_matches(NAN,0))
	print("LUMINA_SAVED_PRECISION_PASS: rounded angles accepted, real differences/IDs/NaN rejected")
	quit()
