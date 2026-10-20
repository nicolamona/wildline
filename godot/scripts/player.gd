extends CharacterBody3D

@export var walk_speed: float = 4.4
@export var run_speed: float = 6.2
@export var look_sensitivity: float = 0.003
@export var gravity: float = 18.0
var move_input := Vector2.ZERO
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Pointer lock is for desktop mouse look only; on mobile web it triggers
	# the browser's cursor warning and is not needed for touch controls.
	if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	position.x = float(GameState.player.get("x", 0.0))
	position.z = float(GameState.player.get("z", 0.0))
	rotation.y = float(GameState.player.get("yaw", 0.0))
	camera.rotation.x = float(GameState.player.get("pitch", 0.0))

func _unhandled_input(event: InputEvent) -> void:
	# Los gestos táctiles se gestionan en zonas GUI explícitas de world.gd.
	# Aquí quedan únicamente teclado y ratón de escritorio.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion:
		if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func apply_look_delta(relative: Vector2) -> void:
	rotation.y -= relative.x * look_sensitivity
	camera.rotation.x = clampf(camera.rotation.x - relative.y * look_sensitivity, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	var keyboard_input := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var input_vector := keyboard_input if keyboard_input.length() > 0.1 else move_input
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	GameState.player.x = position.x
	GameState.player.z = position.z
	GameState.player.yaw = rotation.y
	GameState.player.pitch = camera.rotation.x

func interact() -> String:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 4.5
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "Acércate a un recurso o a un lugar para investigar."
	var collider: Object = hit.get("collider")
	if collider and collider.has_method("collect_resource"):
		if collider.collect_resource():
			return "Recurso recogido."
		return "Este recurso ya fue recogido."
	if collider and collider.has_method("interact_landmark"):
		return collider.interact_landmark()
	return "No hay nada que recoger aquí."
