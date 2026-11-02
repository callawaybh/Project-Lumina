extends SceneTree
func _initialize():
	var prefix = """extends RefCounted
var space_object_data = {"asset": "new"}
var current_asset = {"_id": "old"}
var asset_id = "old"
var data_version = "old"
var events = []
class Client:
	func get_asset_json(_id): return {"_id": "new"}
var Net = {"asset_client": Client.new()}
func _populate_asset_data():
	data_version = current_asset._id
	events.append("populate:" + data_version)
	return true
func _setup_object(): events.append("setup:" + data_version)
func _set_as_errored(message): assert(false, message)
func load_server_asset(_id): pass
func load_client_asset(_id): pass
class ZoneStub:
	func is_host(): return false
	func get_instance_type(): return "fixture"
var Zone = ZoneStub.new()
"""
	var paths=["C:/Dev/LuminaClient/mirror-godot-app/.lumina-bridge/space-object-before-refresh-order.gd", "C:/Dev/LuminaClient/mirror-godot-app/gameplay/space_object/space_object.gd"]
	for i in range(2):
		var source=FileAccess.get_file_as_string(paths[i]).replace("\r", "")
		var fn="func _load_asset"+source.split("func _load_asset",true,1)[1].split("\nfunc ",true,1)[0]
		var script=GDScript.new();script.source_code=prefix+fn
		assert(script.reload()==OK)
		var instance=script.new()
		await instance._load_asset()
		if i==0: assert(instance.events==["setup:old","populate:new"])
		else: assert(instance.events==["populate:new","setup:new"])
	print("LUMINA_CACHED_REFRESH_PASS: old source reproduces stale model; fixed source sets up new model")
	quit()
