extends RefCounted
const LuminaDance=preload("res://lumina_dance.gd")
var _input_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _hori_rotation_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _vert_rotation_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _vr_compression_level=DataBuffer.COMPRESSION_LEVEL_1
var _constant_buffer_size=-1
var _dance_intent=false
var VRManager={"vr_is_active":false}
var global_transform=Transform3D.IDENTITY
var global_position=Vector3.ZERO
class Equipment:
	func is_current_equipable_aiming():return false
var equipable_controller=Equipment.new()
func get_head_global_transform():return Transform3D.IDENTITY
func _lumina_guard(_stage,_values):return true
func get_intended_movement_direction():return Vector3.ZERO
func is_intent_to_run():return false
func is_intent_to_jump():return false
func camera_get_rotation():return Vector2.ZERO
func get_look_target():return Vector3.FORWARD
func write_pending_interactions_to_buffer(buffer):buffer.add_bool(false)
func get_current_seat_path_or_null():return null
func get_body_position():return Vector3.ZERO
func count_interactions_buffer_size(buffer):assert(not buffer.read_bool());return buffer.get_bool_size()
func are_interactions_different(a,b):return a.read_bool()!=b.read_bool()
func _collect_inputs(delta: float, buffer: DataBuffer) -> void:
	var camera_transform = get_head_global_transform()
	if not _lumina_guard("collect_inputs.entry", {"body": global_transform, "camera": camera_transform}):
		return
	var input_move = camera_transform.basis * get_intended_movement_direction()
	input_move = Vector2(input_move.x, input_move.z).normalized()
	var input_run = is_intent_to_run()
	var input_jump = is_intent_to_jump()
	var character_horizontal_rotation = camera_get_rotation().y
	var character_head_vertical_rotation = camera_get_rotation().x
	var look_target = get_look_target()
	var is_aiming = equipable_controller.is_current_equipable_aiming()
	if not _lumina_guard("collect_inputs.values", {"move": input_move, "yaw": character_horizontal_rotation, "pitch": character_head_vertical_rotation}):
		return

	write_pending_interactions_to_buffer(buffer)
	buffer.add_optional_variant(get_current_seat_path_or_null(), null)

	var vr_is_active: bool = VRManager.vr_is_active
	buffer.add_bool(vr_is_active)

	if vr_is_active:
		var vr_body_position = get_body_position()
		vr_body_position.y = 0.0
		vr_body_position = global_transform * vr_body_position
		var vr_old_position = global_position
		buffer.add_vector3(vr_body_position, _vr_compression_level)
		buffer.add_vector3(vr_old_position, _vr_compression_level)

	buffer.add_normalized_vector2(input_move.normalized(), _input_compression_level)
	buffer.add_bool(input_run)
	buffer.add_bool(input_jump)
	buffer.add_real(character_horizontal_rotation, _hori_rotation_compression_level)
	buffer.add_real(character_head_vertical_rotation, _vert_rotation_compression_level)
	buffer.add_bool(is_aiming)
	buffer.add_bool(_dance_intent)


func _count_input_size(inputs: DataBuffer) -> int:
	var variable_buffer_size = 0
	variable_buffer_size += count_interactions_buffer_size(inputs)
	variable_buffer_size += inputs.read_optional_variant_size(null)

	var vr_is_active: bool = inputs.read_bool()
	if vr_is_active:
		variable_buffer_size += inputs.get_vector3_size(_vr_compression_level)
		variable_buffer_size += inputs.get_vector3_size(_vr_compression_level)

	# Define it once, as if it was a const
	if _constant_buffer_size == -1:
		_constant_buffer_size = (
			inputs.get_bool_size()
			+ inputs.get_normalized_vector2_size(_input_compression_level)
			+ inputs.get_bool_size()
			+ inputs.get_bool_size()
			+ inputs.get_real_size(_hori_rotation_compression_level)
			+ inputs.get_real_size(_vert_rotation_compression_level)
			+ inputs.get_bool_size()
			+ inputs.get_bool_size() # dance intent
		)
	return _constant_buffer_size + variable_buffer_size


func _are_inputs_different(inputs_A: DataBuffer, inputs_B: DataBuffer) -> bool:
	if inputs_A.size() != inputs_B.size():
		return true

	if are_interactions_different(inputs_A, inputs_B):
		return true

	var seat_path_A = inputs_A.read_optional_variant(null)
	var seat_path_B = inputs_B.read_optional_variant(null)
	if seat_path_A != seat_path_B:
		return true

	var vr_is_active_A: bool = inputs_A.read_bool()
	var vr_is_active_B: bool = inputs_B.read_bool()
	if vr_is_active_A != vr_is_active_B:
		return true

	if vr_is_active_A:
		var vr_body_position_A: Vector3 = inputs_A.read_vector3(_vr_compression_level)
		var vr_body_position_B: Vector3 = inputs_B.read_vector3(_vr_compression_level)
		if vr_body_position_A != vr_body_position_B:
			return true

		var vr_old_position_A: Vector3 = inputs_A.read_vector3(_vr_compression_level)
		var vr_old_position_B: Vector3 = inputs_B.read_vector3(_vr_compression_level)
		if vr_old_position_A != vr_old_position_B:
			return true

	var input_move_A: Vector2 = inputs_A.read_normalized_vector2(_input_compression_level)
	var input_move_B: Vector2 = inputs_B.read_normalized_vector2(_input_compression_level)
	if input_move_A != input_move_B:
		return true

	var input_run_A = inputs_A.read_bool()
	var input_run_B = inputs_B.read_bool()
	if input_run_A != input_run_B:
		return true

	var input_jump_A = inputs_A.read_bool()
	var input_jump_B = inputs_B.read_bool()
	if input_jump_A != input_jump_B:
		return true

	var h_rotation_A = inputs_A.read_real(_hori_rotation_compression_level)
	var h_rotation_B = inputs_B.read_real(_hori_rotation_compression_level)
	if h_rotation_A != h_rotation_B:
		return true

	var v_rotation_A = inputs_A.read_real(_vert_rotation_compression_level)
	var v_rotation_B = inputs_B.read_real(_vert_rotation_compression_level)
	if v_rotation_A != v_rotation_B:
		return true

	var is_aiming_A = inputs_A.read_bool()
	var is_aiming_B = inputs_B.read_bool()
	if is_aiming_A != is_aiming_B:
		return true

	if inputs_A.read_bool() != inputs_B.read_bool():
		return true
	return false
