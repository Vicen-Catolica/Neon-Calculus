class_name AlarmDialogue
extends Node
## Diálogo que toca no primeiro alarme da fase (a Axioma falando pelos
## alto-falantes, GDD §9). Uma vez por save, como os outros diálogos. Espera o
## jogo estar livre (sem hack, leitura ou outro diálogo).

@export var dialogue_id: String = ""

var _pending: bool = false


func _ready() -> void:
	GameManager.alarm_raised.connect(_on_alarm)


func _on_alarm(_pos: Vector2) -> void:
	if _pending or dialogue_id == "" or dialogue_id in GameManager.dialogues_seen:
		return
	_pending = true
	while is_inside_tree() and (get_tree().paused or Dialogue.is_open() or LevelTransition.is_busy()
			or GameManager.state != GameManager.State.PLAYING):
		await get_tree().process_frame
	if is_inside_tree() and not (dialogue_id in GameManager.dialogues_seen):
		var p := get_tree().get_first_node_in_group("Player")
		if p and not p.get("is_dead"):
			Dialogue.play_id(dialogue_id)
	_pending = false
