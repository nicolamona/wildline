extends Node
signal changed

const SAVE_PATH := "user://wildline-save-v1.json"
const SAVE_VERSION := 1

var player := {"x": 0.0, "z": 0.0, "yaw": 0.0, "pitch": 0.0, "health": 100.0, "water": 100.0, "energy": 100.0, "wood": 0, "stone": 0, "fiber": 0, "tool": 0}
var mission_stage: int = 0
var taken: Array[String] = []

func _ready() -> void:
	load_progress()

func collect_resource(kind: String, resource_id: String) -> bool:
	if taken.has(resource_id) or not player.has(kind):
		return false
	taken.append(resource_id)
	player[kind] = int(player[kind]) + 1
	if mission_stage == 0 and int(player.wood) + int(player.stone) + int(player.fiber) >= 4:
		mission_stage = 1
	save_progress()
	changed.emit()
	return true

func interact_landmark(landmark: String) -> String:
	if landmark == "outpost":
		if mission_stage == 0:
			return "Reúne 4 recursos antes de investigar el puesto."
		if mission_stage == 1:
			mission_stage = 2
			save_progress()
			changed.emit()
			return "Registro encontrado. Una señal apunta hacia la cueva."
		return "Puesto costero: zona ya registrada."
	if landmark == "cave":
		if mission_stage < 2:
			return "La cueva queda para después. Sigue las pistas de la costa."
		if mission_stage == 2:
			mission_stage = 3
			save_progress()
			changed.emit()
			return "Capítulo 01 completado: señal recuperada."
		return "Cueva explorada. No hay más pistas por ahora."
	return "No hay nada nuevo que investigar."

func mission_title() -> String:
	match mission_stage:
		0: return "MISIÓN 01 · Reúne 4 recursos"
		1: return "MISIÓN 02 · Investiga el puesto"
		2: return "MISIÓN 03 · Encuentra la cueva"
		_: return "CAPÍTULO 01 · Completado"

func save_progress() -> void:
	var data := {"version": SAVE_VERSION, "player": player.duplicate(true), "missionStage": mission_stage, "taken": taken, "savedAt": int(Time.get_unix_time_from_system() * 1000.0)}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		return false
	var saved_player: Variant = parsed.get("player", {})
	if saved_player is Dictionary:
		for key in player.keys():
			if saved_player.has(key):
				player[key] = saved_player[key]
	mission_stage = clampi(int(parsed.get("missionStage", 0)), 0, 3)
	taken.clear()
	var saved_taken: Variant = parsed.get("taken", [])
	if saved_taken is Array:
		for item in saved_taken:
			taken.append(str(item))
	changed.emit()
	return true
