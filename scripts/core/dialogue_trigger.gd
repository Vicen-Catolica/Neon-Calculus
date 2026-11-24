class_name DialogueTrigger
extends Area2D
## Dispara um roteiro de diálogo (data/dialogue/*.json) quando o Eduardo entra.
## Toca uma vez por save: depois de visto, o id fica em GameManager.dialogues_seen.
## Espera a tela de transição sumir e o jogo estar livre (sem hack, leitura ou pausa).

@export var dialogue_id: String = ""
## Se preenchido, dispara um guia do Tutorial (passo a passo da SINE) em vez
## de um roteiro simples. Ex.: "hack".
@export var guide: String = ""
## Se preenchido, mostra uma dica de tecla do Tutorial (ex.: "hide"), sem pausar.
@export var hint: String = ""

var _waiting: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if hint != "":
		Tutorial.hint(hint, global_position)
		return
	if guide != "":
		if not ("guide_" + guide in GameManager.dialogues_seen):
			Tutorial.guide(guide, global_position)
		return
	if _waiting or dialogue_id == "" or Tutorial.muted_in_tests(dialogue_id):
		return
	if dialogue_id in GameManager.dialogues_seen:
		return
	_waiting = true
	while is_inside_tree() and not _ready_to_play(body):
		await get_tree().process_frame
	if is_inside_tree() and not (dialogue_id in GameManager.dialogues_seen):
		Dialogue.play_id(dialogue_id)
	_waiting = false


func _ready_to_play(body: Node2D) -> bool:
	if LevelTransition.is_busy() or get_tree().paused or Dialogue.is_open():
		return false
	if GameManager.state != GameManager.State.PLAYING:
		return false
	return is_instance_valid(body) and not body.get("is_dead")
