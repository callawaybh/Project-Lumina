extends RefCounted
## Bake the canonical dance for the loaded avatar's actual bind pose and proportions.
const REFERENCE = preload("dance_reference.gd")
const BASE: Animation = preload("dance_twerk.tres")
static var _cache: Dictionary = {}

static func _q(values: Array) -> Quaternion:
	return Quaternion(values[0], values[1], values[2], values[3]).normalized()

static func _v(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func _depth(bone: String) -> int:
	var depth := 0
	while not str(REFERENCE.BONES[bone].parent).is_empty():
		bone = str(REFERENCE.BONES[bone].parent)
		depth += 1
	return depth

static func animation_for(skeleton: Skeleton3D) -> Animation:
	var signature = str(skeleton.motion_scale)
	for i in range(skeleton.get_bone_count()):
		signature += skeleton.get_bone_name(i) + var_to_str(skeleton.get_bone_rest(i))
	if _cache.has(signature): return _cache[signature]
	var result: Animation = BASE.duplicate(true)
	var tracks: Dictionary = {}
	var hips_track := -1
	for track in range(BASE.get_track_count()):
		var bone = str(BASE.track_get_path(track).get_subname(0))
		if BASE.track_get_type(track) == Animation.TYPE_ROTATION_3D: tracks[bone] = track
		elif bone == "Hips" and BASE.track_get_type(track) == Animation.TYPE_POSITION_3D: hips_track = track
	var names: Array = REFERENCE.BONES.keys()
	names.sort_custom(func(a, b): return _depth(a) < _depth(b))
	var offsets: Dictionary = {}
	for bone in names:
		var index = skeleton.find_bone(bone)
		if index < 0: continue
		var reference = REFERENCE.BONES[bone]
		var actual_rest = skeleton.get_bone_global_rest(index)
		var correction = Quaternion.IDENTITY
		var child = str(REFERENCE.PRIMARY.get(bone, ""))
		if not child.is_empty() and skeleton.find_bone(child) >= 0:
			var actual_direction = skeleton.get_bone_global_rest(skeleton.find_bone(child)).origin - actual_rest.origin
			var reference_direction = _v(REFERENCE.BONES[child].global_position) - _v(reference.global_position)
			if actual_direction.length_squared() > 0.00000001 and reference_direction.length_squared() > 0.00000001:
				correction = Quaternion(actual_direction.normalized(), reference_direction.normalized())
		offsets[bone] = _q(reference.global_rotation).inverse() * correction * actual_rest.basis.get_rotation_quaternion()
	var hips_id = skeleton.find_bone("Hips")
	if hips_id < 0: return result
	var reference_height: float = REFERENCE.BONES.Hips.global_position[1]
	var ratio: float = skeleton.get_bone_global_rest(hips_id).origin.y / reference_height
	var actual_hips = skeleton.get_bone_rest(hips_id).origin
	var reference_hips = _v(REFERENCE.BONES.Hips.position)
	var motion_scale = maxf(skeleton.motion_scale, 0.0001)
	for key in range(BASE.track_get_key_count(hips_track)):
		var canonical_global: Dictionary = {}
		var actual_global: Dictionary = {}
		for bone in names:
			var parent = str(REFERENCE.BONES[bone].parent)
			var local_rotation: Quaternion = BASE.track_get_key_value(tracks[bone], key) if tracks.has(bone) else _q(REFERENCE.BONES[bone].rotation)
			canonical_global[bone] = (canonical_global[parent] * local_rotation).normalized() if canonical_global.has(parent) else local_rotation
			if offsets.has(bone): actual_global[bone] = (canonical_global[bone] * offsets[bone]).normalized()
		for bone in tracks:
			if not actual_global.has(bone): continue
			var parent = str(REFERENCE.BONES[bone].parent)
			var rotation: Quaternion = (actual_global[parent].inverse() * actual_global[bone]).normalized() if actual_global.has(parent) else actual_global[bone]
			result.track_set_key_value(tracks[bone], key, rotation)
		var hips: Vector3 = BASE.track_get_key_value(hips_track, key)
		# AnimationMixer multiplies translation tracks by Skeleton3D.motion_scale.
		result.track_set_key_value(hips_track, key, (actual_hips + (hips - reference_hips) * ratio) / motion_scale)
	# Terminal marker bones are optional; omit tracks missing from this avatar.
	for track in range(result.get_track_count() - 1, -1, -1):
		if skeleton.find_bone(str(result.track_get_path(track).get_subname(0))) < 0:
			result.remove_track(track)
	_cache[signature] = result
	return result
