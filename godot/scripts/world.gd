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
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.63, 0.69, 0.61)
	env.fog_density = 0.0032
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.88
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 92.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.4
	add_child(sun)
	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(360.0, 360.0)
	water.mesh = water_mesh
	water.position.y = -1.8
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.025, 0.17, 0.19, 1.0)
	water_mat.metallic = 0.16
	water_mat.roughness = 0.19
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.005, 0.035, 0.04)
	water_mat.emission_energy_multiplier = 0.25
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
	surface.set_smooth_group(1)
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
			surface.set_color(_ground_tint(a))
			surface.add_vertex(a)
			surface.set_color(_ground_tint(c))
			surface.add_vertex(c)
			surface.set_color(_ground_tint(b))
			surface.add_vertex(b)
			surface.set_color(_ground_tint(b))
			surface.add_vertex(b)
			surface.set_color(_ground_tint(c))
			surface.add_vertex(c)
			surface.set_color(_ground_tint(d))
			surface.add_vertex(d)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain := MeshInstance3D.new()
	terrain.mesh = terrain_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.78, 0.82, 0.70)
	ground_mat.vertex_color_use_as_albedo = true
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
	tree.rotation.y = rng.randf_range(0.0, TAU)
	add_child(tree)
	var broadleaf := rng.randf() < 0.34
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13 if broadleaf else 0.18
	trunk_mesh.bottom_radius = 0.30 if broadleaf else 0.36
	trunk_mesh.height = rng.randf_range(3.7, 5.0)
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height * 0.5
	trunk.rotation.z = rng.randf_range(-0.07, 0.07)
	trunk.material_override = _mat([Color(0.19, 0.105, 0.055), Color(0.25, 0.16, 0.085), Color(0.15, 0.12, 0.075)][rng.randi_range(0, 2)])
	tree.add_child(trunk)
	var greens := [Color(0.07, 0.17, 0.105), Color(0.10, 0.22, 0.13), Color(0.14, 0.27, 0.15), Color(0.18, 0.30, 0.17), Color(0.10, 0.23, 0.16)]
	var crown_count := 3 if broadleaf else 4
	for level in range(crown_count):
		var crown := MeshInstance3D.new()
		var crown_mesh: Mesh
		if broadleaf:
			var blob := SphereMesh.new()
			blob.radius = rng.randf_range(1.15, 1.8)
			blob.height = blob.radius * 1.45
			blob.radial_segments = 7
			blob.rings = 4
			crown_mesh = blob
			crown.position = Vector3(rng.randf_range(-0.65, 0.65), 3.3 + float(level) * 0.72, rng.randf_range(-0.55, 0.55))
		else:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 2.25 - float(level) * 0.28
			cone.height = 3.0 - float(level) * 0.18
			cone.radial_segments = 7
			crown_mesh = cone
			crown.position.y = 3.2 + float(level) * 1.12
		crown.mesh = crown_mesh
		crown.material_override = _mat(greens[rng.randi_range(0, greens.size() - 1)])
		tree.add_child(crown)
	if rng.randf() < 0.42:
		for root_index in range(3):
			var root := MeshInstance3D.new()
			var root_mesh := CylinderMesh.new()
			root_mesh.top_radius = 0.035
			root_mesh.bottom_radius = 0.16
			root_mesh.height = rng.randf_range(0.9, 1.45)
			root.mesh = root_mesh
			root.position = Vector3(0.0, 0.12, 0.0)
			root.rotation = Vector3(0.15, float(root_index) * TAU / 3.0, 1.0)
			root.material_override = trunk.material_override
			tree.add_child(root)

func _ground_tint(point: Vector3) -> Color:
	var radius := Vector2(point.x, point.z).length()
	var noise := sin(point.x * 0.31 + cos(point.z * 0.21)) * 0.5 + cos(point.z * 0.27 - point.x * 0.13) * 0.5
	var base := Color(0.23, 0.30, 0.18).lerp(Color(0.35, 0.31, 0.20), clampf((noise + 0.5) * 0.55, 0.0, 0.8))
	if radius > ISLAND_RADIUS - 17.0:
		base = base.lerp(Color(0.43, 0.39, 0.27), 0.42)
	if point.y > 2.4:
		base = base.lerp(Color(0.29, 0.34, 0.24), 0.35)
	return base

func _add_ground_cover(pos: Vector3, size: float) -> void:
	var tuft := Node3D.new()
	tuft.position = pos
	tuft.rotation.y = rng.randf_range(0.0, TAU)
	tuft.scale = Vector3.ONE * size
	add_child(tuft)
	var leaf_colors := [Color(0.12, 0.23, 0.105), Color(0.20, 0.28, 0.12), Color(0.25, 0.29, 0.14), Color(0.16, 0.25, 0.17)]
	for j in range(3):
		var blade := MeshInstance3D.new()
		var blade_mesh := PrismMesh.new()
		blade_mesh.size = Vector3(0.12, rng.randf_range(0.35, 0.75), 0.10)
		blade.mesh = blade_mesh
		blade.position = Vector3(rng.randf_range(-0.18, 0.18), blade_mesh.size.y * 0.45, rng.randf_range(-0.18, 0.18))
		blade.rotation = Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(0.0, TAU), rng.randf_range(-0.32, 0.32))
		blade.material_override = _mat(leaf_colors[rng.randi_range(0, leaf_colors.size() - 1)])
		tuft.add_child(blade)

func _add_fallen_log(pos: Vector3, length: float) -> void:
	var log := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.20
	mesh.bottom_radius = 0.25
	mesh.height = length
	mesh.radial_segments = 7
	log.mesh = mesh
	log.position = pos + Vector3(0.0, 0.24, 0.0)
	log.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.08, 0.08), rng.randf_range(0.0, TAU), 0.0)
	log.material_override = _mat(Color(0.22, 0.14, 0.075))
	add_child(log)
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
		if i % 2 == 0:
			_add_ground_cover(Vector3(x + rng.randf_range(-1.7, 1.7), _terrain_height(x, z), z + rng.randf_range(-1.7, 1.7)), rng.randf_range(0.7, 1.35))
		if i % 17 == 0:
			_add_fallen_log(Vector3(x + 1.5, _terrain_height(x, z), z - 1.0), rng.randf_range(2.0, 3.8))

func _add_rock(pos: Vector3, size: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 1.55
	rock.mesh = mesh
	rock.position = pos + Vector3(0.0, size * 0.42, 0.0)
	rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
	rock.scale = Vector3(1.25, 0.72, 0.9)
	rock.material_override = _mat([Color(0.28, 0.31, 0.28), Color(0.34, 0.33, 0.28), Color(0.22, 0.27, 0.26)][rng.randi_range(0, 2)])
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
	button.text = "◈  INTERACTUAR"
	button.custom_minimum_size = Vector2(152, 62)
	button.add_theme_color_override("font_color", Color(0.92, 0.94, 0.83))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72))
	button.add_theme_color_override("font_pressed_color", Color(0.77, 0.88, 0.72))
	button.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.7))
	button.add_theme_stylebox_override("normal", _hud_panel(Color(0.045, 0.085, 0.075, 0.92), Color(0.48, 0.58, 0.42, 0.85)))
	button.add_theme_stylebox_override("hover", _hud_panel(Color(0.09, 0.15, 0.12, 0.96), Color(0.73, 0.72, 0.45, 0.95)))
	button.add_theme_stylebox_override("pressed", _hud_panel(Color(0.12, 0.17, 0.11, 0.98), Color(0.7, 0.66, 0.38, 1.0)))
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

func _hud_panel(fill: Color, border_color: Color) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = fill
	panel.border_color = border_color
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 12.0
	panel.content_margin_right = 12.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	return panel

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
