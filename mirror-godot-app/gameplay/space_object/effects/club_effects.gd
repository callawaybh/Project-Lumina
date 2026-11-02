extends Node3D
## Fixed decorative effect preset, activated only by the versioned marker in its GLB.
## Rendered locally on each client; no physics bodies or per-frame network updates.
const MARKER := "LUMINA_NIGHTCLUB_FX_V1"
const COLORS := [Color(1.0, 0.035, 0.16), Color(0.42, 0.08, 1.0), Color(0.65, 0.12, 1.0), Color(1.0, 0.04, 0.22)]
var movers: Array[Node3D] = []
var spots: Array[SpotLight3D] = []
var beam_materials: Array[ShaderMaterial] = []
var laser_fans: Array[Node3D] = []
var smoke: Array[CPUParticles3D] = []
var _epoch := 0.0
var _start_ticks := 0
var _built := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	build()

func build() -> void:
	if _built: return
	_built = true
	_epoch = fposmod(Time.get_unix_time_from_system(), 120.0)
	_start_ticks = Time.get_ticks_msec()
	for i in range(4):
		var pivot := Node3D.new()
		pivot.name = "MovingHead%d" % i
		pivot.position = Vector3(-4.8 if i % 2 == 0 else 4.8, 6.15, -5.0 if i < 2 else 4.0)
		add_child(pivot)
		movers.append(pivot)
		var housing := CylinderMesh.new()
		housing.top_radius = 0.19; housing.bottom_radius = 0.22; housing.height = 0.32
		var housing_material := StandardMaterial3D.new()
		housing_material.albedo_color = Color(0.035, 0.037, 0.05)
		housing_material.metallic = 0.65
		housing.material = housing_material
		_mesh(pivot, housing, Vector3(0, -0.08, 0))
		var spot := SpotLight3D.new()
		spot.name = "DanceFloorSpot%d" % i
		spot.rotation.x = -PI / 2.0
		spot.position.y = -0.26
		spot.light_color = COLORS[i]
		spot.light_energy = 2.2
		spot.spot_range = 9.0
		spot.spot_angle = 17.0
		spot.spot_attenuation = 0.7
		spot.shadow_enabled = false
		pivot.add_child(spot); spots.append(spot)
		var beam := CylinderMesh.new()
		beam.top_radius = 0.055; beam.bottom_radius = 1.65; beam.height = 6.25
		beam.radial_segments = 24; beam.rings = 1
		var material := ShaderMaterial.new()
		material.shader = preload("club_beam.gdshader")
		material.set_shader_parameter("tint", COLORS[i])
		material.set_shader_parameter("strength", 0.10)
		beam.material = material; beam_materials.append(material)
		_mesh(pivot, beam, Vector3(0, -3.385, 0))
	for side in range(2):
		var fan := Node3D.new()
		fan.name = "LaserFan%d" % side
		fan.position = Vector3(-4.5 if side == 0 else 4.5, 4.7, -10.0)
		add_child(fan); laser_fans.append(fan)
		for j in range(6):
			var beam := CylinderMesh.new()
			beam.top_radius = 0.009; beam.bottom_radius = 0.009
			beam.height = 1.0; beam.radial_segments = 6; beam.rings = 1
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(0.15, 0.8, 0.85) if side == 0 else Color(0.7, 0.12, 1.0)
			material.emission_enabled = true
			material.emission = material.albedo_color
			material.emission_energy_multiplier = 3.0
			beam.material = material
			_mesh(fan, beam, Vector3.ZERO)
	_create_smoke(-1.0)
	_create_smoke(1.0)
	update_at(_epoch)

func _mesh(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = offset
	parent.add_child(instance)
	return instance

func _create_smoke(side: float) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "StageHazeLeft" if side < 0 else "StageHazeRight"
	particles.position = Vector3(side * 5.5, 0.16, -9.5)
	particles.amount = 48
	particles.lifetime = 8.0
	particles.preprocess = 4.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.55, 0.035, 0.25)
	particles.direction = Vector3(-side * 0.7, 0.18, 0.5).normalized()
	particles.spread = 22.0
	particles.gravity = Vector3(0, 0.012, 0)
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 0.65
	particles.angular_velocity_min = -12.0
	particles.angular_velocity_max = 12.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.45)); growth.add_point(Vector2(1, 2.2))
	particles.scale_amount_curve = growth
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.18, 0.65, 1])
	gradient.colors = PackedColorArray([Color(0.45,0.40,0.58,0),Color(0.45,0.40,0.58,0.15),Color(0.45,0.40,0.58,0.08),Color(0.45,0.40,0.58,0)])
	particles.color_ramp = gradient
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := Vector2((x - 31.5) / 31.5, (y - 31.5) / 31.5).length()
			var alpha := pow(maxf(0.0, 1.0 - radius * radius), 2.8)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = ImageTexture.create_from_image(image)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	quad.material = material
	particles.mesh = quad
	add_child(particles); smoke.append(particles)

func _process(_delta: float) -> void:
	update_at(_epoch + (Time.get_ticks_msec() - _start_ticks) * 0.001)

func update_at(seconds: float) -> void:
	# Smooth sweeps and 0.5 Hz pulses; shared wall-clock phase, independent of music.
	for i in range(movers.size()):
		var phase := seconds * TAU / 30.0 + i * PI * 0.5
		movers[i].rotation = Vector3(0.15 * sin(phase * 0.75), 0, (0.16 if i % 2 == 0 else -0.16) + 0.24 * sin(phase))
		var pulse := 0.68 + 0.32 * pow(0.5 + 0.5 * sin(seconds * PI + i * 0.8), 2.0)
		spots[i].light_energy = 2.2 * pulse
		beam_materials[i].set_shader_parameter("strength", 0.10 * pulse)
	for side in range(laser_fans.size()):
		var fan := laser_fans[side]
		for j in range(fan.get_child_count()):
			var target := Vector3(-5.8 + j * 2.25 + 0.8 * sin(seconds * TAU / 40.0 + side * PI), 0.07, 1.5 + 3.8 * sin(seconds * TAU / 60.0 + side * 1.3 + j * 0.12))
			var vector := target - fan.position
			var beam: MeshInstance3D = fan.get_child(j)
			beam.position = vector * 0.5
			beam.quaternion = Quaternion(Vector3.UP, vector.normalized())
			beam.scale = Vector3(1, vector.length(), 1)
