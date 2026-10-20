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

	# Regression test: route touches through each actual on-screen arrow rectangle.
	var world := scene
	var expected_directions := [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
	if world.dpad_buttons.size() != 4:
		push_error("SMOKE TEST FAILED: expected four mobile D-pad buttons")
		quit(1)
		return
	var touch_index := 40
	for i in range(world.dpad_buttons.size()):
		var entry: Dictionary = world.dpad_buttons[i]
		var move_button := entry["button"] as Control
		var touch := InputEventScreenTouch.new()
		touch.index = touch_index
		touch.position = move_button.get_global_transform_with_canvas() * (move_button.size * 0.5)
		touch.pressed = true
		world._input(touch)
		if player.move_input != expected_directions[i]:
			push_error("SMOKE TEST FAILED: D-pad %d produced %s" % [i, player.move_input])
			quit(1)
			return
		touch.pressed = false
		world._input(touch)
		if player.move_input != Vector2.ZERO:
			push_error("SMOKE TEST FAILED: D-pad %d did not release movement" % i)
			quit(1)
			return
		touch_index += 1

	print("WILDLINE_SMOKE_TEST: PASS | mobile D-pad touch/release: 4 directions")
	print("Player/camera: OK | MeshInstance3D: %d | CollisionShape3D: %d | Buttons: %d" % [mesh_count, collision_count, button_count])
	quit(0)

func _count_type(node: Node, type_name: String) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		total += _count_type(child, type_name)
	return total
