extends RefCounted
const LuminaDance=preload("res://lumina_dance.gd")
const AnimationController={"STANCE_INT":{"Unarmed":0}}
var _scale_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _position_compression_level=DataBuffer.COMPRESSION_LEVEL_1
var _rotation_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _velocity_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _stance_compression_level=DataBuffer.COMPRESSION_LEVEL_3
var global_transform=Transform3D.IDENTITY
var scale=Vector3.ONE
var position=Vector3.ZERO
var linear_velocity=Vector3.ZERO
var _desired_horizontal_rotation=0.0
var _desired_vertical_rotation=0.0
var dance_active=true
var dance_elapsed=0.0
class Model:
	extends RefCounted
	var _running=false
	var _grounded=true
	var _sitting=false
	var _dead=false
	var _is_aiming=false
	var stance="Unarmed"
	var dance_active=false
	var dance_elapsed=0.0
	func update_character_status(_dt,_position,_yaw,_pitch):pass
	func update(_movement,_run,_ground,_sit,_dead,_aim,_stance):pass
	func set_dance_state(active,elapsed):dance_active=active;dance_elapsed=elapsed
var model=Model.new()
func _lumina_guard(_stage,_values):return true
func notify_received_net_sync_update():pass
func get_local_movement_velocity():return linear_velocity
func encode_stance(decoded_value) -> int:
	return AnimationController.STANCE_INT[decoded_value]


func lerp_phase(a, b, alpha: float):
	if alpha > 0.5:
		return b
	else:
		return a


func trickled_sync_state_collect(db: DataBuffer, update_rate: float) -> void:
	var rotation_y: float = global_transform.basis.get_euler().y
	var rotation_x: float = global_transform.basis.get_euler().x
	db.add_unit_real(clamp(rotation_y / PI, -1, 1), _rotation_compression_level)
	db.add_unit_real(clamp(rotation_x / (PI / 2.0), -1, 1), _rotation_compression_level)
	# TODO constrain the scale depending on Netsync, then we can use unit_real instead
	db.add_real(scale.y, _scale_compression_level)
	db.add_vector3(position, _position_compression_level)

	var animation_details_velocity := Vector2(linear_velocity.x, linear_velocity.z)
	# TODO rename those private variables to be public, but in the next PR.
	var animation_details_running: bool = model._running
	var animation_details_grounded: bool = model._grounded
	var animation_details_sitting: bool = model._sitting
	var animation_details_dead: bool = model._dead
	var animation_details_is_aiming: bool = model._is_aiming
	# A StringName is not sent correctly over-the-wire
	var animation_details_stance: int = encode_stance(model.stance)

	db.add_vector2(animation_details_velocity, _velocity_compression_level)
	db.add_bool(animation_details_running)
	db.add_bool(animation_details_grounded)
	db.add_bool(animation_details_sitting)
	db.add_bool(animation_details_dead)
	db.add_bool(animation_details_is_aiming)
	db.add_uint(animation_details_stance, _stance_compression_level)
	db.add_bool(dance_active)
	db.add_real(dance_elapsed, _position_compression_level)


func trickled_sync_state_apply(dt: float, alpha: float, db_from: DataBuffer, db_to: DataBuffer) -> void:
	if not _lumina_guard("network.trickle_entry", {"body": global_transform, "alpha": alpha, "dt": dt}):
		return
	notify_received_net_sync_update()

	var old_rotation_y: float = db_from.read_unit_real(_rotation_compression_level) * PI
	var old_rotation_x: float = db_from.read_unit_real(_rotation_compression_level) * (PI / 2.0)
	var old_scale: float = db_from.read_real(_scale_compression_level)
	var old_position: Vector3 = db_from.read_vector3(_position_compression_level)

	var old_animation_details_velocity := db_from.read_vector2(_velocity_compression_level)
	var old_animation_details_running := db_from.read_bool()
	var old_animation_details_grounded := db_from.read_bool()
	var old_animation_details_sitting := db_from.read_bool()
	var old_animation_details_dead := db_from.read_bool()
	var old_animation_details_is_aiming := db_from.read_bool()
	var old_animation_details_stance := db_from.read_uint(_stance_compression_level)
	var old_dance_active := db_from.read_bool()
	var old_dance_elapsed := db_from.read_real(_position_compression_level)

	var new_rotation_y: float = db_to.read_unit_real(_rotation_compression_level) * PI
	var new_rotation_x: float = db_to.read_unit_real(_rotation_compression_level) * (PI / 2.0)
	var new_scale: float = db_to.read_real(_scale_compression_level)
	var new_position: Vector3 = db_to.read_vector3(_position_compression_level)
	var new_animation_details_velocity := db_to.read_vector2(_velocity_compression_level)
	var new_animation_details_running := db_to.read_bool()
	var new_animation_details_grounded := db_to.read_bool()
	var new_animation_details_sitting := db_to.read_bool()
	var new_animation_details_dead := db_to.read_bool()
	var new_animation_details_is_aiming := db_to.read_bool()
	var new_animation_details_stance := db_to.read_uint(_stance_compression_level)
	var new_dance_active := db_to.read_bool()
	var new_dance_elapsed := db_to.read_real(_position_compression_level)
	if not _lumina_guard("network.decoded_snapshot", {"old_position": old_position, "new_position": new_position, "positive_old_scale": old_scale, "positive_new_scale": new_scale, "old_yaw": old_rotation_y, "new_yaw": new_rotation_y, "old_pitch": old_rotation_x, "new_pitch": new_rotation_x, "old_velocity": old_animation_details_velocity, "new_velocity": new_animation_details_velocity}):
		return

	scale = Vector3.ONE * lerp(old_scale, new_scale, alpha)
	position = lerp(old_position, new_position, alpha)
	_desired_horizontal_rotation = lerp_angle(old_rotation_y, new_rotation_y, alpha)
	_desired_vertical_rotation = lerp_angle(old_rotation_x, new_rotation_x, alpha)
	if not _lumina_guard("network.interpolated_result", {"body": global_transform, "yaw": _desired_horizontal_rotation, "pitch": _desired_vertical_rotation}):
		return

	# Updates the character location right away. No need to interpolate in this case
	# because this method is already interpolated.
	model.update_character_status(0.0, position, _desired_horizontal_rotation, _desired_vertical_rotation)

	var animation_details_velocity := old_animation_details_velocity.lerp(new_animation_details_velocity, alpha)
	var animation_details_running: bool = lerp_phase(old_animation_details_running, new_animation_details_running, alpha)
	var animation_details_grounded: bool = lerp_phase(old_animation_details_grounded, new_animation_details_grounded, alpha)
	var animation_details_sitting: bool = lerp_phase(old_animation_details_sitting, new_animation_details_sitting, alpha)
	var animation_details_dead: bool = lerp_phase(old_animation_details_dead, new_animation_details_dead, alpha)
	var animation_details_is_aiming: bool = lerp_phase(old_animation_details_is_aiming, new_animation_details_is_aiming, alpha)
	var animation_details_stance: int = lerp_phase(old_animation_details_stance, new_animation_details_stance, alpha)

	linear_velocity = Vector3(animation_details_velocity.x, 0, animation_details_velocity.y)
	var mv: Vector3 = get_local_movement_velocity()

	model.update(
		Vector2(mv.x, mv.z),
		animation_details_running,
		animation_details_grounded,
		animation_details_sitting,
		animation_details_dead,
		animation_details_is_aiming,
		#decode_stance(animation_details_stance)
		model.stance
	)
	model.set_dance_state(lerp_phase(old_dance_active, new_dance_active, alpha), LuminaDance.remote_elapsed(old_dance_active, old_dance_elapsed, new_dance_active, new_dance_elapsed, alpha))
