extends CharacterBody3D

@export var walk_speed: float = 4.4
@export var run_speed: float = 6.2
@export var look_sensitivity: float = 0.003
@export var gravity: float = 18.0
@export var jump_speed: float = 6.4
@export var motion_turn_speed: float = 1.7
var move_input := Vector2.ZERO
var motion_enabled := false
var motion_forward := 0.0
var motion_turn := 0.0
var last_shake_count := 0
var motion_poll_timer := 0.0
var motion_cache := {}
@onready var camera: Camera3D = $Camera3D

const WEB_MOTION_INIT := """
(function () {
  if (window.wildlineMotion) return;
  const state = window.wildlineMotion = {
    enabled: false, permission: false, beta: 0, gamma: 0,
    neutralBeta: 0, neutralGamma: 0, forward: 0, turn: 0,
    shakeCount: 0, lastShake: 0, lastAcceleration: null, calibrating: false
  };
  const button = document.createElement('button');
  button.id = 'wildline-motion-toggle';
  button.type = 'button';
  button.textContent = 'ACTIVAR MOVIMIENTO';
  Object.assign(button.style, {
    position: 'fixed', top: '16px', right: '16px', zIndex: '10000',
    padding: '12px 14px', maxWidth: '48vw', borderRadius: '10px',
    border: '1px solid rgba(177,202,151,.9)',
    background: 'rgba(8,25,22,.92)', color: '#edf4dc',
    font: '600 12px system-ui, sans-serif', letterSpacing: '.04em',
    boxShadow: '0 3px 16px rgba(0,0,0,.35)', touchAction: 'manipulation'
  });
  document.body.appendChild(button);
  function updateButton(text) { button.textContent = text; }
  function onOrientation(event) {
    if (event.beta == null || event.gamma == null) return;
    state.beta = event.beta;
    state.gamma = event.gamma;
    if (state.calibrating) {
      state.neutralBeta = state.beta;
      state.neutralGamma = state.gamma;
      state.calibrating = false;
      state.forward = 0;
      state.turn = 0;
      return;
    }
    state.forward = Math.max(-1, Math.min(1, (state.beta - state.neutralBeta) / 24));
    state.turn = Math.max(-1, Math.min(1, (state.gamma - state.neutralGamma) / 22));
  }
  function onMotion(event) {
    if (!state.enabled) return;
    const a = event.acceleration;
    const g = event.accelerationIncludingGravity;
    if (a && a.x != null && a.y != null && a.z != null) {
      const magnitude = Math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z);
      const now = Date.now();
      if (magnitude > 13.5 && now - state.lastShake > 750) {
        state.shakeCount += 1;
        state.lastShake = now;
      }
      return;
    }
    if (!g || g.x == null || g.y == null || g.z == null) return;
    const current = [g.x, g.y, g.z];
    if (state.lastAcceleration) {
      const dx = current[0] - state.lastAcceleration[0];
      const dy = current[1] - state.lastAcceleration[1];
      const dz = current[2] - state.lastAcceleration[2];
      const now = Date.now();
      if (Math.sqrt(dx*dx + dy*dy + dz*dz) > 18 && now - state.lastShake > 750) {
        state.shakeCount += 1;
        state.lastShake = now;
      }
    }
    state.lastAcceleration = current;
  }
  button.addEventListener('click', async function () {
    try {
      if (typeof DeviceOrientationEvent === 'undefined') {
        updateButton('SENSORES NO DISPONIBLES');
        return;
      }
      if (typeof DeviceOrientationEvent.requestPermission === 'function') {
        const result = await DeviceOrientationEvent.requestPermission();
        if (result !== 'granted') {
          updateButton('PERMISO DENEGADO · TOCÁ PARA REINTENTAR');
          return;
        }
      }
      if (typeof DeviceMotionEvent !== 'undefined' &&
          typeof DeviceMotionEvent.requestPermission === 'function') {
        const result = await DeviceMotionEvent.requestPermission();
        if (result !== 'granted') {
          updateButton('PERMISO DE MOVIMIENTO DENEGADO');
          return;
        }
      }
      state.forward = 0;
      state.turn = 0;
      state.permission = true;
      state.enabled = true;
      state.calibrating = true;
      window.addEventListener('deviceorientation', onOrientation, true);
      window.addEventListener('devicemotion', onMotion, true);
      updateButton('ACTIVO · INCLINÁ PARA AVANZAR/GIRAR · AGITÁ PARA SALTAR');
    } catch (error) {
      updateButton('NO SE PUDO ACTIVAR · VOLVÉ A TOCAR');
    }
  });
})();
"""

func _ready() -> void:
	# Pointer lock is for desktop mouse look only; on mobile web it triggers
	# the browser's cursor warning and is not needed for touch controls.
	if not OS.has_feature("mobile") and not OS.has_feature("web_android") and not OS.has_feature("web_ios"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	position.x = float(GameState.player.get("x", 0.0))
	position.z = float(GameState.player.get("z", 0.0))
	rotation.y = float(GameState.player.get("yaw", 0.0))
	camera.rotation.x = float(GameState.player.get("pitch", 0.0))
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_MOTION_INIT, true)

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

func _read_motion_controls() -> void:
	if not OS.has_feature("web"):
		return
	motion_poll_timer -= get_physics_process_delta_time()
	if motion_poll_timer <= 0.0:
		motion_poll_timer = 0.08
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.wildlineMotion || {})", true)
		if raw is String and not raw.is_empty():
			var parsed := JSON.new()
			if parsed.parse(raw) == OK and parsed.data is Dictionary:
				motion_cache = parsed.data
	if motion_cache.is_empty():
		return
	var data: Dictionary = motion_cache
	motion_enabled = bool(data.get("enabled", false))
	motion_forward = clampf(float(data.get("forward", 0.0)), -1.0, 1.0)
	motion_turn = clampf(float(data.get("turn", 0.0)), -1.0, 1.0)
	var shake_count := int(data.get("shakeCount", 0))
	if shake_count > last_shake_count:
		last_shake_count = shake_count
		if is_on_floor():
			velocity.y = jump_speed

func _physics_process(delta: float) -> void:
	_read_motion_controls()
	var keyboard_input := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var input_vector := keyboard_input if keyboard_input.length() > 0.1 else move_input
	if motion_enabled:
		rotation.y -= motion_turn * motion_turn_speed * delta
		if keyboard_input.length() <= 0.1 and move_input.length() <= 0.1 and absf(motion_forward) > 0.08:
			input_vector = Vector2(0.0, -motion_forward)
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
