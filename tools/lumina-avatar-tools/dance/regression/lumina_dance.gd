extends RefCounted
## Shared deterministic dance policy for prediction and remote presentation.
const CLIP: Animation = preload("C:/Dev/LuminaClient/mirror-godot-app/player/animations/dances/dance_twerk.tres")

static func can_dance(movement: Vector2, jumping: bool, grounded: bool, sitting: bool, dead: bool, aiming: bool, vr_active: bool, is_frozen: bool) -> bool:
	return movement.is_finite() and movement.length_squared() < 0.0001 and not jumping and grounded and not sitting and not dead and not aiming and not vr_active and not is_frozen

static func playback_position(elapsed: float) -> float:
	return fposmod(maxf(elapsed, 0.0), CLIP.length) if is_finite(elapsed) else 0.0

static func remote_elapsed(old_active: bool, old_elapsed: float, new_active: bool, new_elapsed: float, alpha: float) -> float:
	if not is_finite(old_elapsed) or not is_finite(new_elapsed): return 0.0
	if old_active and new_active: return maxf(lerpf(old_elapsed, new_elapsed, clampf(alpha, 0.0, 1.0)), 0.0)
	return maxf(new_elapsed if alpha > 0.5 else old_elapsed, 0.0)
