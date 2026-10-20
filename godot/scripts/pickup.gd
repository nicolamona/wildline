extends StaticBody3D

@export_enum("wood", "stone", "fiber") var resource_type: String = "wood"
@export var resource_id: String = ""
@export var landmark_id: String = ""

func _ready() -> void:
	if not resource_id.is_empty() and GameState.taken.has(resource_id):
		queue_free()

func collect_resource() -> bool:
	if resource_id.is_empty():
		return false
	var collected := GameState.collect_resource(resource_type, resource_id)
	if collected:
		queue_free()
	return collected

func interact_landmark() -> String:
	if landmark_id.is_empty():
		return "No hay nada que investigar."
	return GameState.interact_landmark(landmark_id)
