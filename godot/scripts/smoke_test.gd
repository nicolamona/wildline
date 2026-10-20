extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("SMOKE TEST FAILED: main scene could not be loaded")
		quit(1)
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_error("SMOKE TEST FAILED: Player node is missing")
		quit(1)
		return
	if player.get_node_or_null("Camera3D") == null:
		push_error("SMOKE TEST FAILED: first-person camera is missing")
		quit(1)
		return

	var mesh_count := _count_type(scene, "MeshInstance3D")
	var collision_count := _count_type(scene, "CollisionShape3D")
	var button_count := _count_type(scene, "Button")
	if mesh_count < 1000:
		push_error("SMOKE TEST FAILED: expected dense forest meshes; found %d" % mesh_count)
		quit(1)
		return
	if collision_count < 10:
		push_error("SMOKE TEST FAILED: expected terrain/player/resource collisions; found %d" % collision_count)
		quit(1)
		return
	if button_count < 1:
		push_error("SMOKE TEST FAILED: interaction button is missing")
		quit(1)
		return

	# The instantiated main scene is the World script for this prototype.
	var world = scene
	# Regression test: explicit touch zones and movement drag/release behavior.
	var move_zone := scene.find_child("MoveTouchZone", true, false) as Control
	var look_zone := scene.find_child("LookTouchZone", true, false) as Control
	if move_zone == null or look_zone == null:
		push_error("SMOKE TEST FAILED: explicit move/look touch zones are missing")
		quit(1)
		return
	if move_zone.mouse_filter != Control.MOUSE_FILTER_PASS or look_zone.mouse_filter != Control.MOUSE_FILTER_PASS:
		push_error("SMOKE TEST FAILED: touch zones must pass GUI events without swallowing desktop input")
		quit(1)
		return
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 17
	touch_down.pressed = true
	touch_down.position = Vector2(80, 600)
	world._input(touch_down)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 17
	touch_drag.position = Vector2(80, 500)
	touch_drag.relative = Vector2(0, -60)
	world._input(touch_drag)
	if player.move_input.y >= -0.5:
		push_error("SMOKE TEST FAILED: upward touch drag must move player forward; got %s" % player.move_input)
		quit(1)
		return
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 17
	touch_up.pressed = false
	touch_up.position = Vector2(80, 500)
	world._input(touch_up)
	if player.move_input != Vector2.ZERO:
		push_error("SMOKE TEST FAILED: releasing touch must stop movement")
		quit(1)
		return
	print("WILDLINE_SMOKE_TEST: PASS | touch zones + drag direction + release")
	print("Player/camera: OK | MeshInstance3D: %d | CollisionShape3D: %d | Buttons: %d" % [mesh_count, collision_count, button_count])
	quit(0)

func _count_type(node: Node, type_name: String) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		total += _count_type(child, type_name)
	return total
