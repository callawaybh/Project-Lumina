extends RefCounted
const LuminaDance=preload("res://lumina_dance.gd")
var _animation_tree:AnimationTree
var stance="Unarmed"
var _dance_active=false
var _dance_elapsed=0.0
var _grounded=true
var _sitting=false
var _dead=false
var _running=false
var _is_aiming=false
var _movement=Vector2.ZERO
var _animation_velocity=Vector2.ZERO
func _set_animation(delta: float) -> void:
	var request: String = "parameters/Stance/transition_request"
	var current_state: String = _animation_tree.get("parameters/Stance/current_state")
	if _sitting:
		_animation_tree.set(request, "Sitting")
		return
	if _dead:
		_animation_tree.set(request, "Dead")
		return
	if _dance_active and _grounded and not _sitting and not _dead:
		_animation_tree.set(request, "Dance")
		_animation_tree.set("parameters/DanceSeek/seek_request", LuminaDance.playback_position(_dance_elapsed))
		return
	if current_state != stance:
		_animation_tree.set(request, stance)
		current_state = stance
	var state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/%s/Main_State/playback" % [current_state])
	if current_state != "Sitting" and current_state != "Dead":
		if _grounded:
			if not _running:
				if current_state == "Unarmed":
					state_machine.travel("Walking")
				else:
					if _is_aiming:
						state_machine.travel("Walking_ADS")
					else:
						state_machine.travel("Walking_Hip")
			else:
				if current_state == "Unarmed":
					state_machine.travel("Running")
				else:
					state_machine.travel("Running_Hip")
		else:
			state_machine.travel("Fall")
	_animation_velocity = _animation_velocity.lerp(Vector2(_movement.x, -_movement.y), clampf(8.0 * delta, 0.0, 1.0))
	if current_state == "Unarmed":
		_animation_tree.set("parameters/%s/Main_State/Running/blend_position" % [current_state], _animation_velocity)
		_animation_tree.set("parameters/%s/Main_State/Walking/blend_position" % [current_state], _animation_velocity)
	else:
		_animation_tree.set("parameters/%s/Main_State/Running_Hip/blend_position" % [current_state], _animation_velocity)
		_animation_tree.set("parameters/%s/Main_State/Walking_Hip/blend_position" % [current_state], _animation_velocity)
		_animation_tree.set("parameters/%s/Main_State/Walking_ADS/blend_position" % [current_state], _animation_velocity)


func set_dance_state(active: bool, elapsed: float) -> void:
	_dance_active = active and is_finite(elapsed)
	_dance_elapsed = maxf(elapsed, 0.0) if is_finite(elapsed) else 0.0
