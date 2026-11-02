extends Node
## Local developer JSON command bridge. No sockets, credentials, or arbitrary code.
const DIR = "res://.lumina-bridge/"
const GROUPS_KEY = "luminaBuilderGroups"
const COPY_FIELDS = ["asset", "position", "rotation", "scale", "offset", "description", "locked",
	"collisionEnabled", "shapeType", "bodyType", "massKg", "gravityScale", "castShadows",
	"visibleFrom", "visibleTo", "visibleFromMargin", "visibleToMargin", "materialAssetId",
	"objectColor", "objectTexture", "objectTextureSizeV2", "objectTextureOffset",
	"objectTextureTriplanar", "objectTextureRepeat", "surfaceMaterialId", "extraNodes", "scriptEvents",
	"audioAutoPlay", "audioLoop", "audioIsSpatial", "audioPitch", "audioBaseVolume",
	"audioSpatialMaxVolume", "audioSpatialRange"]
var busy := false
var elapsed := 0.0
var created: Dictionary = {}

func _ready() -> void:
	set_process(false)
	if not OS.has_feature("editor") or OS.get_cmdline_args().has("--server"):
		return
	await Zone.wait_till_booted()
	if Zone.is_host():
		return
	Zone.instance_manager.space_object_created.connect(_created)
	set_process(true)

func _created(object, receipt_id) -> void:
	if str(receipt_id).begins_with("lumina-"):
		created[str(receipt_id)] = object.space_object_data.get("_id", "")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25 or busy or Zone.is_host():
		return
	elapsed = 0.0
	if ProjectSettings.get_setting("mirror/env_name", "") != "local":
		return
	if not FileAccess.file_exists(DIR + "enabled"):
		return
	var directory := DirAccess.open(DIR)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".request.json"):
			var response_path: String = DIR + filename.replace(".request.json", ".response.json")
			if FileAccess.file_exists(response_path):
				continue
			busy = true
			_handle(DIR + filename, response_path)
			return

func _handle(path: String, response_path: String) -> void:
	# Claim before side effects: a crash must never replay a create automatically.
	var claimed: String = path.replace(".request.json", ".claimed.json")
	if DirAccess.rename_absolute(path, claimed) != OK:
		busy = false
		return
	var request = JSON.parse_string(FileAccess.get_file_as_string(claimed))
	var result: Dictionary = {"ok": false, "error": "Invalid request"}
	if request is Dictionary:
		result = await _dispatch(request)
	var file := FileAccess.open(response_path + ".tmp", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result))
		file.close()
		DirAccess.rename_absolute(response_path + ".tmp", response_path)
	busy = false

func _vector(value, count: int, positive := false) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
		if abs(float(number)) > 10000 or (positive and float(number) <= 0):
			return false
	return true

func _dispatch(request: Dictionary) -> Dictionary:
	var action: String = str(request.get("action", ""))
	if action == "status":
		var character = Zone.get_local_character() if Zone.space_ready else null
		var player_position: Array = []
		if is_instance_valid(character) and character.global_position.is_finite():
			player_position = Serialization.vector3_to_array(character.global_position)
		return {"ok": true, "space_id": Zone.space.get("_id", ""),
			"space_name": Zone.space.get("name", ""), "ready": Zone.space_ready,
			"edit_mode": Zone.is_in_edit_mode(), "user_id": Net.user_id,
			"player_position": player_position, "capabilities": ["delete_objects", "static_primitives", "world_bounds", "prepared_models", "club_environment", "inspect_object"]}
	if action == "join_space":
		var space_id: String = str(request.get("space_id", ""))
		if Net.user_id.is_empty() or space_id.length() != 24 or not space_id.is_valid_hex_number(false):
			return {"ok": false, "error": "Sign in first and provide a 24-character Space ID"}
		if Zone.space_ready:
			return {"ok": false, "error": "Already in a Space; leave it before joining another"}
		Zone.client.call_deferred("start_join_zone_by_space_id", space_id)
		return {"ok": true, "state": "joining", "space_id": space_id}
	if not Zone.space_ready or not Zone.is_in_edit_mode():
		return {"ok": false, "error": "Join a Space in edit mode first"}
	if action == "list_objects":
		var objects: Array = []
		for object in Zone.instance_manager.get_all_instances():
			if object is SpaceObject:
				objects.append({"id": object.space_object_data.get("_id", ""),
					"name": object.get_space_object_name(), "position": Serialization.vector3_to_array(object.position),
					"rotation": Serialization.vector3_to_array(object.rotation),
					"scale": Serialization.vector3_to_array(object.get_model_scale()),
					"asset_id": object.get_space_object_asset_id(),
					"body_type": object.physics_body_type, "collision_enabled": object.collision_enabled,
					"bounds": _world_bounds(object)})
		return {"ok": true, "objects": objects}
	if action == "list_groups":
		return await _load_groups()
	if Util.get_role_for_user(Zone.space, Net.user_id) < Enums.ROLE.CONTRIBUTOR:
		return {"ok": false, "error": "Current account cannot edit this Space"}
	if action == "create_model":
		return await _import_prepared_asset(request)
	if action == "replace_model":
		return await _import_prepared_asset(request, true)
	if action == "create_audio":
		return await _import_prepared_asset(request, false, true)
	if action == "set_environment":
		return await _set_club_environment(request)
	if action == "inspect_object":
		return _inspect_club_object(request)
	if action == "delete_objects":
		return await _delete_objects(request)
	if action == "create_primitive":
		return await _create(request)
	if action == "update_object":
		return await _update(request)
	if action == "rename_object":
		return await _update({"object_id": request.get("object_id", ""), "changes": {"name": request.get("name", "")}})
	if action == "duplicate_object":
		return await _duplicate(request)
	if action in ["create_group", "rename_group", "move_group", "duplicate_group"]:
		return await _group_command(request)
	return {"ok": false, "error": "Unknown action"}

func _create(request: Dictionary) -> Dictionary:
	if not _valid_name(request.get("name", "Lumina Primitive")):
		return {"ok": false, "error": "Name must contain 1 to 80 characters, without control characters"}
	var shape: String = str(request.get("shape", "box"))
	var size = request.get("size", [1, 1, 1])
	var position = request.get("position", [])
	var color = request.get("color", [1, 0, 0, 1])
	if not shape in ["box", "sphere", "cylinder"]:
		return {"ok": false, "error": "Supported shapes: box, sphere, cylinder"}
	if not _vector(size, 3, true) or not _vector(position, 3) or not _vector(color, 4):
		return {"ok": false, "error": "Expected size[3]>0, position[3], color[4]"}
	for component in color:
		if component < 0 or component > 1:
			return {"ok": false, "error": "Color components must be between 0 and 1"}
	var root := ModelRoot.new()
	root.name = Util.clean_string_for_model_file_path(str(request.get("name", "Lumina Primitive")).substr(0, 80))
	add_child(root)
	var primitive := ModelPrimitive.new()
	match shape:
		"box": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.BOX, PackedFloat64Array(size))
		"sphere": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.SPHERE, PackedFloat64Array([size[0] / 2.0]))
		"cylinder": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.CYLINDER, PackedFloat64Array([size[0] / 2.0, size[1]]))
	primitive.color = Color(color[0], color[1], color[2], color[3])
	root.add_child(primitive)
	# Position is the bottom-center of the object, in world meters.
	primitive.position.y = size[0] / 2.0 if shape == "sphere" else size[1] / 2.0
	var file_path: String = root.save_to_gltf_file()
	var promise = await GameUI.instance.creator_ui.asset_browser.create_asset_from_url(file_path)
	root.queue_free()
	if promise.is_error():
		return {"ok": false, "error": promise.get_error_message()}
	var asset: Dictionary = promise.get_result()
	var receipt_id: String = "lumina-" + str(request.get("id", Time.get_ticks_usec()))
	var result: Dictionary = await _spawn({"asset": asset["_id"], "position": position,
		"name": str(request.get("name", "Lumina Primitive")),
		"rotation": [0, 0, 0], "scale": [1, 1, 1], "bodyType": "Static", "collisionEnabled": true}, receipt_id)
	if result.get("ok", false):
		_remember_primitive(result.object_id, request)
	result["asset_id"] = asset["_id"]
	result["position"] = position
	return result

func _spawn(properties: Dictionary, receipt_id: String) -> Dictionary:
	Zone.client_send_create_space_object(properties, Zone.receipt_create(Net.user_id, false, receipt_id))
	var deadline: int = Time.get_ticks_msec() + 30000
	while not created.has(receipt_id) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not created.has(receipt_id):
		return {"ok": false, "error": "Creation acknowledgement timed out; inspect objects before retrying"}
	var object_id: String = str(created[receipt_id])
	created.erase(receipt_id)
	return {"ok": true, "object_id": object_id, "state": "created"}

func _update(request: Dictionary) -> Dictionary:
	var id: String = str(request.get("object_id", ""))
	var target = null
	for object in Zone.instance_manager.get_all_instances():
		if object is SpaceObject and object.space_object_data.get("_id", "") == id:
			target = object
	if target == null:
		return {"ok": false, "error": "Object not found in current Space"}
	if not Util.can_edit_object_in_space(target):
		return {"ok": false, "error": "Current account cannot edit this object"}
	if not request.get("changes", {}) is Dictionary:
		return {"ok": false, "error": "changes must be an object"}
	var changes: Dictionary = request.get("changes", {})
	if changes.is_empty():
		return {"ok": false, "error": "No changes supplied"}
	for key in changes:
		if key == "name":
			if not _valid_name(changes[key]):
				return {"ok": false, "error": "Name must contain 1 to 80 characters, without control characters"}
			continue
		if not key in ["position", "rotation", "scale", "color"]:
			return {"ok": false, "error": "Allowed changes: name, position, rotation (radians), scale, color"}
		if not _vector(changes[key], 4 if key == "color" else 3, key == "scale"):
			return {"ok": false, "error": "Invalid numeric array for " + key}
	if changes.has("color"):
		for component in changes.color:
			if component < 0 or component > 1:
				return {"ok": false, "error": "Color components must be between 0 and 1"}
	# Submit the native update packet directly. A non-selected object's process
	# loop may be disabled, so its ten-frame queued update can remain pending.
	var delta: Dictionary = {"_id": id}
	if changes.has("color"):
		# This revision's objectColor database field is not wired to the renderer.
		# For our own primitives, replace the model asset through native GLB upload.
		var original: Dictionary = _find_primitive_request(id)
		if original.is_empty():
			return {"ok": false, "error": "Recolor supports bridge-created primitives only; original geometry is unknown"}
		var shape: String = original.get("shape", "box")
		var size: Array = original.get("size", [1, 1, 1])
		var rgba: Array = changes.color
		var root := ModelRoot.new()
		root.name = "Lumina Recolored " + id
		add_child(root)
		var primitive := ModelPrimitive.new()
		match shape:
			"box": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.BOX, PackedFloat64Array(size))
			"sphere": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.SPHERE, PackedFloat64Array([size[0] / 2.0]))
			"cylinder": primitive.setup_primitive_shape(ModelPrimitive.ShapeType.CYLINDER, PackedFloat64Array([size[0] / 2.0, size[1]]))
		primitive.color = Color(rgba[0], rgba[1], rgba[2], rgba[3])
		root.add_child(primitive)
		primitive.position.y = size[0] / 2.0 if shape == "sphere" else size[1] / 2.0
		var file_path: String = root.save_to_gltf_file()
		var promise = await GameUI.instance.creator_ui.asset_browser.create_asset_from_url(file_path)
		root.queue_free()
		if promise.is_error():
			return {"ok": false, "error": promise.get_error_message()}
		delta["asset"] = promise.get_result()["_id"]
		delta["objectColor"] = [1, 1, 1, 1]
	for key in changes:
		if key != "color":
			delta[key] = changes[key]
	Zone.instance_manager.update_space_object(delta)
	Zone.send_data_to_server([Packet.TYPE.UPDATE_SPACE_OBJECT, delta])
	var confirmation: Dictionary = await _confirm_saved(id, delta)
	confirmation["object_id"] = id
	confirmation["changes"] = changes
	return confirmation

func _find_primitive_request(object_id: String) -> Dictionary:
	var spec_path: String = DIR + "primitive-" + object_id + ".json"
	if FileAccess.file_exists(spec_path):
		var spec = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
		if spec is Dictionary:
			return spec
	var directory := DirAccess.open(DIR)
	for filename in directory.get_files():
		if not filename.ends_with(".response.json"):
			continue
		var response = JSON.parse_string(FileAccess.get_file_as_string(DIR + filename))
		if not response is Dictionary or response.get("object_id", "") != object_id:
			continue
		var request_path: String = DIR + filename.replace(".response.json", ".claimed.json")
		var original = JSON.parse_string(FileAccess.get_file_as_string(request_path))
		if original is Dictionary and original.get("action", "") == "create_primitive":
			return original
	return {}

func _valid_name(value) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > 80:
		return false
	for index in value.length():
		if value.unicode_at(index) < 32:
			return false
	return true

func _object(id: String):
	for object in Zone.instance_manager.get_all_instances():
		if object is SpaceObject and object.space_object_data.get("_id", "") == id:
			return object
	return null

func _remember_primitive(object_id: String, spec: Dictionary) -> void:
	var path: String = DIR + "primitive-" + object_id + ".json"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(spec))
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)

func _confirm_saved(object_id: String, expected: Dictionary) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var promise = Net.space_client.get_space_object(object_id)
		await promise.wait_till_fulfilled()
		if promise.is_error():
			return {"ok": false, "error": "Update submitted, but saved-state verification failed: " + promise.get_error_message()}
		var actual: Dictionary = promise.get_result()
		var matches := true
		for key in expected:
			var value = actual.get(key)
			if value is Dictionary:
				value = value.get("_id", value)
			if not _saved_value_matches(value, expected[key]):
				matches = false
		if matches:
			return {"ok": true, "state": "saved"}
		await get_tree().create_timer(0.25).timeout
	return {"ok": false, "error": "Update submitted, but saved values did not match before timeout; inspect before retrying"}

func _duplicate(request: Dictionary) -> Dictionary:
	var source = _object(str(request.get("object_id", "")))
	if source == null:
		return {"ok": false, "error": "Source object not found in current Space"}
	if not Util.can_edit_object_in_space(source):
		return {"ok": false, "error": "Current account cannot duplicate this object"}
	var offset = request.get("offset", [2, 0, 0])
	var new_name = request.get("name", source.get_space_object_name() + " Copy")
	if not _vector(offset, 3) or not _valid_name(new_name):
		return {"ok": false, "error": "Expected a finite offset[3] and a name of 1 to 80 characters"}
	var properties: Dictionary = {}
	# Copy allowed native properties, never database IDs, roles, ownership or parents.
	for key in COPY_FIELDS:
		if source.space_object_data.get(key) != null:
			properties[key] = source.space_object_data[key]
	properties["asset"] = source.get_space_object_asset_id()
	properties["name"] = new_name
	properties["position"] = Serialization.vector3_to_array(source.position + Vector3(offset[0], offset[1], offset[2]))
	if not _vector(properties.position, 3):
		return {"ok": false, "error": "Copy destination exceeds the finite coordinate limits"}
	properties["rotation"] = Serialization.vector3_to_array(source.rotation)
	properties["scale"] = Serialization.vector3_to_array(source.get_model_scale())
	properties["offset"] = Serialization.vector3_to_array(source.get_model_offset())
	var result: Dictionary = await _spawn(properties, "lumina-" + str(request.get("id", Time.get_ticks_usec())))
	if result.get("ok", false):
		var spec: Dictionary = _find_primitive_request(str(request.object_id))
		if not spec.is_empty():
			_remember_primitive(result.object_id, spec)
		result["source_object_id"] = request.object_id
		result["asset_id"] = properties.asset
		result["position"] = properties.position
		result["name"] = _object(result.object_id).get_space_object_name()
	return result

func _load_groups() -> Dictionary:
	var promise = Net.space_client.get_space(str(Zone.space.get("_id", "")))
	await promise.wait_till_fulfilled()
	if promise.is_error():
		return {"ok": false, "error": promise.get_error_message()}
	var space: Dictionary = promise.get_result()
	var custom = space.get("customData", {})
	if not custom is Dictionary or not custom.get("data", {}) is Dictionary:
		return {"ok": false, "error": "Space custom data is not available"}
	var encoded = custom.get("data", {}).get(GROUPS_KEY, "{}")
	if not encoded is String:
		return {"ok": false, "error": "Group metadata has an unsupported format"}
	var groups = JSON.parse_string(encoded)
	if not groups is Dictionary:
		return {"ok": false, "error": "Group metadata is invalid; no changes made"}
	for group_id in groups:
		var group = groups[group_id]
		if not group is Dictionary or not _valid_name(group.get("name", "")) or not group.get("object_ids") is Array:
			return {"ok": false, "error": "A saved group has invalid metadata; no changes made"}
	return {"ok": true, "groups": groups, "space_id": Zone.space.get("_id", "")}

func _save_groups(groups: Dictionary) -> Dictionary:
	var promise = Net.space_client.update_space(str(Zone.space["_id"]),
		{"patchCustomData": {GROUPS_KEY: JSON.stringify(groups)}})
	await promise.wait_till_fulfilled()
	if promise.is_error():
		return {"ok": false, "error": promise.get_error_message()}
	return {"ok": true, "state": "saved"}

func _members(ids) -> Dictionary:
	if not ids is Array or ids.is_empty() or ids.size() > 100:
		return {"ok": false, "error": "A group requires between 1 and 100 object IDs"}
	var seen: Dictionary = {}
	for id in ids:
		if not id is String or seen.has(id):
			return {"ok": false, "error": "Object IDs must be unique strings"}
		var object = _object(id)
		if object == null or not Util.can_edit_object_in_space(object):
			return {"ok": false, "error": "Missing or uneditable group member: " + str(id)}
		seen[id] = true
	return {"ok": true}

func _group_command(request: Dictionary) -> Dictionary:
	var loaded: Dictionary = await _load_groups()
	if not loaded.ok:
		return loaded
	var groups: Dictionary = loaded.groups
	var action: String = request.action
	var group_id: String = str(request.get("group_id", ""))
	var members = request.get("object_ids", [])
	if action != "create_group":
		if not groups.has(group_id):
			return {"ok": false, "error": "Group not found in current Space"}
		members = groups[group_id].get("object_ids", [])
	var name = request.get("name", "")
	if action in ["create_group", "rename_group", "duplicate_group"]:
		if not _valid_name(name):
			return {"ok": false, "error": "Group name must contain 1 to 80 characters"}
		for existing_id in groups:
			if not (action == "rename_group" and existing_id == group_id) and groups[existing_id].get("name", "") == name:
				return {"ok": false, "error": "A group with this name already exists"}
	if action == "rename_group":
		groups[group_id]["name"] = name
		var saved: Dictionary = await _save_groups(groups)
		saved["group_id"] = group_id
		return saved
	var valid: Dictionary = _members(members)
	if not valid.ok:
		return valid
	if action == "create_group":
		group_id = "group-" + str(request.id)
		groups[group_id] = {"name": name, "object_ids": members}
		var saved: Dictionary = await _save_groups(groups)
		saved["group_id"] = group_id
		saved["group"] = groups[group_id]
		return saved
	var offset = request.get("offset", [])
	if not _vector(offset, 3):
		return {"ok": false, "error": "Expected a finite offset[3]"}
	var completed: Array = []
	var copied_ids: Array = []
	# Capture all positions before issuing edits (groups may have overlapping membership).
	var positions: Dictionary = {}
	for id in members:
		positions[id] = Serialization.vector3_to_array(_object(id).position + Vector3(offset[0], offset[1], offset[2]))
		if not _vector(positions[id], 3):
			return {"ok": false, "error": "A group destination exceeds the finite coordinate limits; no changes made"}
	for index in members.size():
		var id: String = members[index]
		var result: Dictionary
		if action == "move_group":
			result = await _update({"object_id": id, "changes": {"position": positions[id]}})
		else:
			result = await _duplicate({"object_id": id, "offset": offset, "id": str(request.id) + "-" + str(index)})
		if not result.get("ok", false):
			return {"ok": false, "error": "Group operation partially completed; inspect before retrying", "completed": completed, "failed_object_id": id, "detail": result}
		completed.append(result)
		if action == "duplicate_group":
			copied_ids.append(result.object_id)
	if action == "duplicate_group":
		group_id = "group-" + str(request.id)
		groups[group_id] = {"name": name, "object_ids": copied_ids}
		var saved: Dictionary = await _save_groups(groups)
		if not saved.ok:
			return {"ok": false, "error": "Copies created, but group metadata could not be saved", "completed": completed, "detail": saved}
	return {"ok": true, "state": "saved", "group_id": group_id, "completed": completed}


func _world_bounds(object: Node3D) -> Dictionary:
	var boxes: Array[AABB] = []
	_collect_bounds(object, boxes)
	if boxes.is_empty(): return {}
	var box: AABB = boxes[0]
	for i in range(1, boxes.size()): box = box.merge(boxes[i])
	return {"position": Serialization.vector3_to_array(box.position), "size": Serialization.vector3_to_array(box.size)}

func _collect_bounds(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(node.global_transform * node.get_aabb())
	for child in node.get_children(): _collect_bounds(child, boxes)

func _validate_deletion_request(request: Dictionary, space_id: String) -> Dictionary:
	if request.get("space_id", "") != space_id:
		return {"ok": false, "error": "Expected Space ID does not match current Space"}
	var ids = request.get("object_ids", [])
	if not ids is Array or ids.is_empty() or ids.size() > 32:
		return {"ok": false, "error": "Provide 1 to 32 explicit object IDs"}
	var seen = {}
	for id in ids:
		if not id is String or id.length() != 24 or not id.is_valid_hex_number(false) or seen.has(id):
			return {"ok": false, "error": "Object IDs must be unique 24-character hex strings"}
		seen[id] = true
	return {"ok": true}

func _delete_objects(request: Dictionary) -> Dictionary:
	var valid = _validate_deletion_request(request, str(Zone.space.get("_id", "")))
	if not valid.ok: return valid
	var ids: Array = request.object_ids
	var snapshot: Array = []
	var delete_ids: Array[StringName] = []
	for id in ids:
		var target = _object(id)
		if target == null or not Util.can_edit_object_in_space(target):
			return {"ok": false, "error": "Missing or uneditable object: " + id}
		# Ground maps must never be swept up by test-object cleanup.
		if target.get_space_object_name().begins_with("Map "):
			return {"ok": false, "error": "Map objects are protected from this cleanup command"}
		snapshot.append(target.space_object_data.duplicate(true))
		delete_ids.append(StringName(id))
	var loaded: Dictionary = await _load_groups()
	if not loaded.ok: return loaded
	var backup_path: String = DIR + "deletion-backup-" + str(request.id) + ".json"
	var file = FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null: return {"ok": false, "error": "Could not save pre-deletion snapshot"}
	file.store_string(JSON.stringify({"space_id": request.space_id, "objects": snapshot, "groups": loaded.groups}))
	file.close()
	Zone.send_data_to_server([Packet.TYPE.DELETE_SPACE_OBJECTS, delete_ids])
	var deadline: int = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		var promise = Net.space_client.get_space_objects(request.space_id)
		await promise.wait_till_fulfilled()
		if promise.is_error():
			return {"ok": false, "error": "Delete submitted; verification failed. Inspect before retrying.", "backup": backup_path}
		var remaining: Array = []
		for item in promise.get_result():
			if ids.has(str(item.get("_id", ""))): remaining.append(item.get("_id"))
		for id in ids:
			if _object(id) != null and not remaining.has(id): remaining.append(id)
		if remaining.is_empty():
			var groups: Dictionary = loaded.groups
			for group_id in groups.keys():
				var kept: Array = []
				for member in groups[group_id].object_ids:
					if not ids.has(member): kept.append(member)
				if kept.is_empty(): groups.erase(group_id)
				else: groups[group_id].object_ids = kept
			var saved: Dictionary = await _save_groups(groups)
			return {"ok": saved.ok, "state": "deleted", "deleted_ids": ids, "groups_saved": saved.ok, "backup": backup_path}
		await get_tree().create_timer(.25).timeout
	return {"ok": false, "error": "Delete submitted; verification timed out. Inspect before retrying.", "backup": backup_path}

func _checked_asset_path(request: Dictionary, audio := false) -> Dictionary:
	if request.get("space_id", "") != str(Zone.space.get("_id", "")):
		return {"ok": false, "error": "Expected Space ID does not match current Space"}
	var filename = request.get("file", "")
	if not filename is String or filename.is_empty() or filename != filename.get_file():
		return {"ok": false, "error": "Provide a model-directory filename, without a path"}
	if filename.get_extension().to_lower() != ("wav" if audio else "glb"):
		return {"ok": false, "error": "Expected WAV audio or GLB model"}
	var path: String = DIR + "models/" + filename
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Prepared asset file not found"}
	var file = FileAccess.open(path, FileAccess.READ)
	var length = file.get_length()
	if length < 16 or length >= 15 * 1024 * 1024:
		return {"ok": false, "error": "Asset must be between 16 bytes and 15 MiB"}
	if not audio and (file.get_32() != 0x46546C67 or file.get_32() != 2 or file.get_32() != length):
		return {"ok": false, "error": "Invalid GLB header"}
	return {"ok": true, "path": path}

func _import_prepared_asset(request: Dictionary, replace := false, audio := false) -> Dictionary:
	var checked = _checked_asset_path(request, audio)
	if not checked.ok: return checked
	var position = request.get("position", [])
	var rotation = request.get("rotation", [0, 0, 0])
	var name = request.get("name", "")
	var target = null
	if replace:
		target = _object(str(request.get("object_id", "")))
		if target == null or not Util.can_edit_object_in_space(target):
			return {"ok": false, "error": "Model replacement requires an editable object in current Space"}
	else:
		if not _vector(position, 3) or not _vector(rotation, 3) or not _valid_name(name):
			return {"ok": false, "error": "Expected finite position/rotation and a valid name"}
	if request.has("collision_enabled") and not request.collision_enabled is bool:
		return {"ok": false, "error": "collision_enabled must be a boolean"}
	var promise = await GameUI.instance.creator_ui.asset_browser.create_asset_from_url(checked.path)
	if promise.is_error(): return {"ok": false, "error": promise.get_error_message()}
	var asset: Dictionary = promise.get_result()
	var result: Dictionary
	if replace:
		var id: String = str(request.object_id)
		var delta: Dictionary = {"_id": id, "asset": asset["_id"]}
		Zone.instance_manager.update_space_object(delta)
		Zone.send_data_to_server([Packet.TYPE.UPDATE_SPACE_OBJECT, delta])
		result = await _confirm_saved(id, delta)
		result["object_id"] = id
	else:
		var properties: Dictionary = {"asset": asset["_id"], "position": position, "rotation": rotation,
			"scale": [1, 1, 1], "name": name, "bodyType": "Static", "collisionEnabled": request.get("collision_enabled", true)}
		if audio:
			properties.merge({"collisionEnabled": false, "audioAutoPlay": true, "audioLoop": true,
				"audioIsSpatial": false, "audioPitch": 100.0, "audioBaseVolume": 18.0}, true)
		result = await _spawn(properties, "lumina-" + str(request.id))
	result["asset_id"] = asset["_id"]
	return result

func _set_club_environment(request: Dictionary) -> Dictionary:
	if request.get("space_id", "") != str(Zone.space.get("_id", "")):
		return {"ok": false, "error": "Expected Space ID does not match current Space"}
	var changes = request.get("changes", {})
	if not changes is Dictionary or changes.is_empty():
		return {"ok": false, "error": "Environment changes required"}
	for key in changes:
		var value = changes[key]
		if key in ["skyTopColor", "skyHorizonColor", "skyBottomColor", "fogColor"]:
			if not _vector(value, 3): return {"ok": false, "error": "Invalid environment color"}
			for c in value:
				if c < 0 or c > 1: return {"ok": false, "error": "Environment colors must be 0 to 1"}
		elif key in ["fogEnabled", "fogVolumetric", "globalIllumination", "ssao", "ssr", "glow"]:
			if not value is bool: return {"ok": false, "error": "Environment switch must be boolean"}
		elif key in ["glowHdrThreshold", "fogDensity"]:
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 2:
				return {"ok": false, "error": "Invalid environment intensity"}
		elif key == "sunCount":
			if value != 0: return {"ok": false, "error": "Club preset supports zero suns only"}
		elif key == "suns":
			if not value is Array or not value.is_empty(): return {"ok": false, "error": "Club preset requires empty suns"}
		else: return {"ok": false, "error": "Unsupported environment field: " + str(key)}
	if changes.has("sunCount") != changes.has("suns"):
		return {"ok": false, "error": "Provide sunCount and suns together"}
	var backup_path: String = DIR + "environment-backup-" + str(request.id) + ".json"
	var backup = FileAccess.open(backup_path, FileAccess.WRITE)
	backup.store_string(JSON.stringify(Zone.space.get("environment", {})))
	backup.close()
	Zone.send_data_to_server([Packet.TYPE.ENVIRONMENT_CHANGE, changes])
	var deadline = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		var promise = Net.space_client.get_space(str(Zone.space["_id"]))
		await promise.wait_till_fulfilled()
		if promise.is_error(): return {"ok": false, "error": promise.get_error_message()}
		var environment: Dictionary = promise.get_result().get("environment", {})
		var matches = true
		for key in changes:
			if environment.get(key) != changes[key]: matches = false
		if matches: return {"ok": true, "state": "saved", "backup": backup_path}
		await get_tree().create_timer(0.25).timeout
	return {"ok": false, "error": "Environment submitted; saved verification timed out, inspect before retry"}

func _inspect_club_object(request: Dictionary) -> Dictionary:
	var target = _object(str(request.get("object_id", "")))
	if target == null: return {"ok": false, "error": "Object not found in current Space"}
	var result: Dictionary = {"ok": true, "object_id": str(request.object_id), "meshes": 0, "emissive_surfaces": 0, "lights": [], "seats": 0}
	_inspect_club_nodes(target.scaled_model, result)
	result["body_type"] = target.physics_body_type
	result["collision_enabled"] = target.collision_enabled
	result["bounds"] = _world_bounds(target)
	return result

func _inspect_club_nodes(node: Node, result: Dictionary) -> void:
	if node.has_meta(&"OMI_seat"): result.seats += 1
	if str(node.name) == "LuminaClubEffects":
		result["club_effects"] = {"version": 1, "moving_spots": node.spots.size(), "laser_fans": node.laser_fans.size(), "smoke_emitters": node.smoke.size(), "collision_bodies": 0}
	if node is CPUParticles3D:
		if not result.has("particles"): result["particles"] = []
		result.particles.append({"name": str(node.name), "amount": node.amount, "emitting": node.emitting, "lifetime": node.lifetime})
	if node is Light3D:
		result.lights.append({"name": str(node.name), "energy": node.light_energy, "shadow": node.shadow_enabled, "range": node.omni_range if node is OmniLight3D else 0.0})
	if node is MeshInstance3D and node.mesh != null:
		result.meshes += 1
		for i in range(node.mesh.get_surface_count()):
			var material = node.get_active_material(i)
			if material is BaseMaterial3D and material.emission_enabled:
				result.emissive_surfaces += 1
	for child in node.get_children(): _inspect_club_nodes(child, result)

# Native JSON serialization may round an angle by a few decimal places.
# Keep IDs/strings exact and accept only tiny finite numeric differences.
func _saved_value_matches(actual, expected) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return is_finite(float(actual)) and is_finite(float(expected)) and abs(float(actual) - float(expected)) <= 0.00001
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not _saved_value_matches(actual[i], expected[i]): return false
		return true
	return actual == expected
