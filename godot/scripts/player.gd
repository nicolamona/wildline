extends CharacterBody3D

@export var walk_speed: float = 4.4
@export var run_speed: float = 6.2
@export var look_sensitivity: float = 0.003
@export var gravity: float = 18.0
var move_input := Vector2.ZERO
var left_touch_index: int = -1
var right_touch_index: int = -1
var left_touch_origin := Vector2.ZERO
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	position.x = float(GameState.player.get("x", 0.0))
	position.z = float(GameState.player.get("z", 0.0))
	rotation.y = float(GameState.player.get("yaw", 0.0))
	camera.rotation.x = float(GameState.player.get("pitch", 0.0))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventScreenTouch:
		var viewport_size := get_viewport().get_visible_rect().size
		# Reserve the lower-right HUD button area for GUI interaction, not camera look.
		var over_interact_button := event.position.x >= viewport_size.x - 190.0 and event.position.y >= viewport_size.y - 125.0
		if event.pressed:
			if over_interact_button:
				return
			if event.position.x < viewport_size.x * 0.48 and left_touch_index == -1:
				left_touch_index = event.index
				left_touch_origin = event.position
			elif right_touch_index == -1:
				right_touch_index = event.index
		else:
			if event.index == left_touch_index:
				left_touch_index = -1
				move_input = Vector2.ZERO
			if event.index == right_touch_index:
				right_touch_index = -1
	elif event is InputEventScreenDrag:
		if event.index == left_touch_index:
			var delta := (event.position - left_touch_origin) / 72.0
			move_input = Vector2(clampf(delta.x, -1.0, 1.0), clampf(delta.y, -1.0, 1.0))
		elif event.index == right_touch_index:
			_apply_look(event.relative)

func _apply_look(relative: Vector2) -> void:
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
