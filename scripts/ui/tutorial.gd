extends Node
## Autoload "Tutorial": falas da SINE ligadas a acontecimentos do jogo (primeira
## vez que um agente te vê, etc.). Cada evento toca um roteiro de
## data/dialogue/*.json uma vez por save (vai para os diálogos vistos). Espera o
## jogo estar livre: sem hack, leitura, pausa, transição ou outro diálogo.
##
##   Tutorial.event("spotted")

## evento -> id do roteiro
const EVENTS := {
	"spotted": "tut_spotted",
}

var _pending: Dictionary = {}
## As simulações de tests/ rodam sem as falas (elas pausam o jogo); um teste
## que queira as falas liga isto.
var allow_in_tests: bool = false


func event(name: String) -> void:
	var id: String = EVENTS.get(name, "")
	if id == "" or id in GameManager.dialogues_seen or _pending.has(id):
		return
	if Dialogue.lines_for(id).is_empty():
		return
	var scene := get_tree().current_scene
	if not allow_in_tests and scene and scene.scene_file_path.begins_with("res://tests/"):
		return
	_pending[id] = true
	_play_when_free(id)


func _play_when_free(id: String) -> void:
	# Um instante antes de falar: o jogador vê o "!" do agente primeiro.
	await get_tree().create_timer(0.5, false).timeout
	while get_tree().paused or Dialogue.is_open() or LevelTransition.is_busy() \
			or GameManager.state != GameManager.State.PLAYING:
		await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("Player")
	if p and not p.get("is_dead") and not (id in GameManager.dialogues_seen):
		Dialogue.play_id(id)
	_pending.erase(id)
