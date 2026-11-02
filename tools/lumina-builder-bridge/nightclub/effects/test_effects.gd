extends SceneTree
const Effects = preload("club_effects.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	check(document.append_from_file("res://models/club_effects_v1.glb", state) == OK, "GLB import")
	var fixture := document.generate_scene(state)
	root.add_child(fixture)
	var marker := fixture.find_child(Effects.MARKER, true, false)
	check(marker != null, "Exact opt-in marker survives import")
	var a := Effects.new(); var b := Effects.new()
	marker.add_child(a); root.add_child(b)
	a.build(); b.build()
	check(a.spots.size() == 4, "Four real spotlights")
	check(a.laser_fans.size() == 2, "Two laser fans")
	check(a.smoke.size() == 2 and a.smoke[0].amount + a.smoke[1].amount == 96, "Bounded smoke budget")
	for emitter in a.smoke:
		check(emitter.mesh.material.albedo_texture != null, "Soft smoke sprite")
		check(emitter.mesh.material.no_depth_test == false, "Smoke obeys scene depth")
	for spot in a.spots:
		check(not spot.shadow_enabled, "Shadow-free dynamic light")
	var first := a.movers[0].rotation
	for t in [0.0, 1.0, 5.0, 17.0, 33.0, 61.0, 120.0, 3600.0]:
		a.update_at(t); b.update_at(t)
		for i in range(a.movers.size()):
			check(a.movers[i].transform.is_finite(), "Finite mover")
			check(a.movers[i].transform.is_equal_approx(b.movers[i].transform), "Matching client phase")
			check(a.spots[i].light_energy >= 1.49 and a.spots[i].light_energy <= 2.21, "Bounded pulse intensity")
		for fan in a.laser_fans:
			for beam in fan.get_children():
				check(beam.transform.is_finite(), "Finite laser")
				var end: Vector3 = fan.position + beam.position * 2.0
				check(absf(end.x) < 7.0 and absf(end.z) < 8.0 and absf(end.y - 0.07) < 0.001, "Laser ends inside dance floor")
	check(not first.is_equal_approx(a.movers[0].rotation), "Light rig moves")
	a.update_at(0.0); b.update_at(120.0)
	for i in range(4):
		check(a.movers[i].transform.is_equal_approx(b.movers[i].transform), "Clock wrap preserves phase")
	a.build(); check(a.spots.size() == 4, "Setup is idempotent")
	fixture.free(); b.free()
	print("LUMINA_CLUB_FX_PASS: ", checks, " checks; native GLB, lights, smoke, movement, phase and spatial limits")
	quit()
