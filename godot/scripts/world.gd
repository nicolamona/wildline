extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const PICKUP_SCRIPT = preload("res://scripts/pickup.gd")
const GRID_SIZE := 64
const STEP := 2.3
const ISLAND_RADIUS := 73.0
var player: CharacterBody3D
var mission_label: Label
var stats_label: Label
var message_label: Label
var message_timer := 0.0
var rng := RandomNumberGenerator.new()
var material_cache: Dictionary = {}

func _ready() -> void:
	rng.seed = 140721
	_build_environment()
	_build_terrain()
	_build_landmarks()
	_build_forest()
	_build_resources()
	_build_player()
	_build_hud()
	GameState.changed.connect(_refresh_hud)
	_refresh_hud()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = ""

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.25, 0.31)
	sky_mat.sky_horizon_color = Color(0.66, 0.70, 0.62)
	sky_mat.ground_bottom_color = Color(0.045, 0.075, 0.06)
	sky_mat.ground_horizon_color = Color(0.34, 0.39, 0.31)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.55, 0.49)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.57, 0.65, 0.60)
	env.fog_density = 0.0045
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75.0
	add_child(sun)
	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(360.0, 360.0)
	water.mesh = water_mesh
	water.position.y = -1.8
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.025, 0.20, 0.22, 0.88)
	water_mat.metallic = 0.22
	water_mat.roughness = 0.24
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = water_mat
	add_child(water)

func _terrain_height(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	var fade := clampf((ISLAND_RADIUS - radius) / 14.0, 0.0, 1.0)
	var broad := sin(x * 0.055) * 2.1 + cos(z * 0.047) * 1.7
	var detail := sin((x + z) * 0.12) * 0.45 + cos((x - z) * 0.10) * 0.35
	return -2.3 + fade * (5.0 + broad + detail)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(GRID_SIZE) * STEP * 0.5
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var x0 := -half + float(x) * STEP
			var z0 := -half + float(z) * STEP
			var x1 := x0 + STEP
			var z1 := z0 + STEP
			var a := Vector3(x0, _terrain_height(x0, z0), z0)
			var b := Vector3(x1, _terrain_height(x1, z0), z0)
			var c := Vector3(x0, _terrain_height(x0, z1), z1)
			var d := Vector3(x1, _terrain_height(x1, z1), z1)
			surface.add_vertex(a); surface.add_vertex(c); surface.add_vertex(b)
			surface.add_vertex(b); surface.add_vertex(c); surface.add_vertex(d)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain := MeshInstance3D.new()
	terrain.mesh = terrain_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.20, 0.27, 0.17)
	ground_mat.roughness = 1.0
	terrain.material_override = ground_mat
	add_child(terrain)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)

func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(true), roughness]
	if material_cache.has(key):
		return material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material_cache[key] = material
	return material

func _add_tree(pos: Vector3, scale_factor: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.36
	trunk_mesh.height = 4.5
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.25
	trunk.material_override = _mat(Color(0.19, 0.105, 0.055))
	tree.add_child(trunk)
	var greens := [Color(0.09, 0.20, 0.13), Color(0.12, 0.25, 0.15), Color(0.16, 0.29, 0.17), Color(0.10, 0.23, 0.16)]
	for level in range(4):
		var crown := MeshInstance3D.new()
		var cone := ConeMesh.new()
		cone.bottom_radius = 2.25 - float(level) * 0.25
		cone.height = 3.0 - float(level) * 0.25
		cone.radial_segments = 7
		crown.mesh = cone
		crown.position.y = 3.2 + float(level) * 1.15
		crown.material_override = _mat(greens[level])
		tree.add_child(crown)

func _build_forest() -> void:
	for i in range(330):
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * 66.0
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if Vector2(x, z).length() < 9.0: continue
		if Vector2(x - 14.0, z + 30.0).length() < 10.0: continue
		if Vector2(x - 29.0, z + 39.0).length() < 10.0: continue
		_add_tree(Vector3(x, _terrain_height(x, z), z), rng.randf_range(0.72, 1.42))
		if i % 4 == 0:
			_add_rock(Vector3(x + rng.randf_range(-2.0, 2.0), _terrain_height(x, z), z + rng.randf_range(-2.0, 2.0)), rng.randf_range(0.35, 1.0))

func _add_rock(pos: Vector3, size: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 1.55
	rock.mesh = mesh
	rock.position = pos + Vector3(0.0, size * 0.42, 0.0)
	rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
	rock.scale = Vector3(1.25, 0.72, 0.9)
	rock.material_override = _mat(Color(0.28, 0.31, 0.28))
	add_child(rock)

func _block(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _mat(color)
	parent.add_child(instance)

func _build_landmarks() -> void:
	var outpost_pos := Vector3(14.0, _terrain_height(14.0, -30.0), -30.0)
	var outpost := Node3D.new()
	outpost.position = outpost_pos
	add_child(outpost)
	_block(outpost, Vector3(0, 1.35, 0), Vector3(5.2, 2.7, 4.0), Color(0.25, 0.20, 0.13))
	_block(outpost, Vector3(0, 2.9, 0), Vector3(5.8, 0.35, 4.6), Color(0.16, 0.14, 0.11))
	var outpost_body := StaticBody3D.new()
	outpost_body.position = outpost_pos + Vector3(0, 1.0, 0)
	outpost_body.set_script(PICKUP_SCRIPT)
	outpost_body.set("landmark_id", "outpost")
	var outpost_shape := CollisionShape3D.new()
	var outpost_box := BoxShape3D.new()
	outpost_box.size = Vector3(5.0, 3.0, 4.0)
	outpost_shape.shape = outpost_box
	outpost_body.add_child(outpost_shape)
	add_child(outpost_body)
	var cave_pos := Vector3(29.0, _terrain_height(29.0, -39.0), -39.0)
	_block(self, cave_pos + Vector3(0, 2.0, 0), Vector3(7.0, 4.0, 1.8), Color(0.20, 0.22, 0.20))
	_block(self, cave_pos + Vector3(0, 0.2, 0.95), Vector3(2.8, 2.7, 0.25), Color(0.025, 0.035, 0.03))
	var cave_body := StaticBody3D.new()
	cave_body.position = cave_pos + Vector3(0, 1.2, 0)
	cave_body.set_script(PICKUP_SCRIPT)
	cave_body.set("landmark_id", "cave")
	var cave_shape := CollisionShape3D.new()
	var cave_box := BoxShape3D.new()
	cave_box.size = Vector3(4.0, 2.5, 2.0)
	cave_shape.shape = cave_box
	cave_body.add_child(cave_shape)
	add_child(cave_body)

func _add_pickup(pos: Vector3, kind: String, id: String) -> void:
	if GameState.taken.has(id): return
	var body := StaticBody3D.new()
	body.position = pos
	body.set_script(PICKUP_SCRIPT)
	body.set("resource_type", kind)
	body.set("resource_id", id)
	var visual := MeshInstance3D.new()
	var mesh: Mesh
	var color := Color(0.26, 0.16, 0.08)
	if kind == "wood":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.12
		cylinder.bottom_radius = 0.17
		cylinder.height = 1.25
		mesh = cylinder
		color = Color(0.39, 0.22, 0.10)
	elif kind == "stone":
		var sphere := SphereMesh.new()
		sphere.radius = 0.42
		sphere.height = 0.62
		mesh = sphere
		color = Color(0.42, 0.46, 0.43)
	else:
		var fiber := SphereMesh.new()
		fiber.radius = 0.38
		fiber.height = 0.7
		mesh = fiber
		color = Color(0.25, 0.43, 0.19)
	visual.mesh = mesh
	visual.position.y = 0.45
	visual.material_override = _mat(color)
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.0
	shape.shape = sphere_shape
	body.add_child(shape)
	add_child(body)

func _build_resources() -> void:
	var items := [
		[Vector3(-5, _terrain_height(-5, -3), -3), "wood", "wood-01"],
		[Vector3(5, _terrain_height(5, -5), -5), "stone", "stone-01"],
		[Vector3(-7, _terrain_height(-7, 5), 5), "fiber", "fiber-01"],
		[Vector3(8, _terrain_height(8, 4), 4), "wood", "wood-02"],
		[Vector3(-12, _terrain_height(-12, -10), -10), "stone", "stone-02"],
		[Vector3(2, _terrain_height(2, 11), 11), "fiber", "fiber-02"],
		[Vector3(19, _terrain_height(19, -24), -24), "wood", "wood-03"],
		[Vector3(25, _terrain_height(25, -29), -29), "stone", "stone-03"]
	]
	for item in items:
		_add_pickup(item[0], item[1], item[2])

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	var px := float(GameState.player.get("x", 0.0))
	var pz := float(GameState.player.get("z", 0.0))
	player.position = Vector3(px, _terrain_height(px, pz) + 2.0, pz)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.58
	camera.fov = 78.0
	player.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)
	mission_label = Label.new()
	mission_label.position = Vector2(22, 18)
	mission_label.add_theme_font_size_override("font_size", 22)
	mission_label.add_theme_color_override("font_color", Color(0.85, 0.91, 0.78))
	hud.add_child(mission_label)
	stats_label = Label.new()
	stats_label.position = Vector2(22, 54)
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color(0.91, 0.88, 0.74))
	hud.add_child(stats_label)
	message_label = Label.new()
	message_label.anchor_left = 0.18
	message_label.anchor_right = 0.82
	message_label.anchor_top = 0.78
	message_label.anchor_bottom = 0.88
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 19)
	message_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.75))
	hud.add_child(message_label)
	var button := Button.new()
	button.text = "＋  USAR"
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -172
	button.offset_right = -24
	button.offset_top = -104
	button.offset_bottom = -32
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_on_interact_pressed)
	hud.add_child(button)
	var hint := Label.new()
	hint.text = "PC: WASD + ratón · Móvil: arrastra izquierda para moverte y derecha para mirar"
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 18
	hint.offset_right = -18
	hint.offset_top = -28
	hint.offset_bottom = -6
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.77, 0.82, 0.73))
	hud.add_child(hint)

func _on_interact_pressed() -> void:
	_show_message(player.interact())
	_refresh_hud()

func _show_message(message: String) -> void:
	message_label.text = message
	message_timer = 4.0

func _refresh_hud() -> void:
	if not is_instance_valid(mission_label): return
	mission_label.text = GameState.mission_title()
	stats_label.text = "VIDA %d   AGUA %d   ENERGÍA %d\nMADERA %d   PIEDRA %d   FIBRA %d" % [
		int(GameState.player.health), int(GameState.player.water), int(GameState.player.energy),
		int(GameState.player.wood), int(GameState.player.stone), int(GameState.player.fiber)
	]
