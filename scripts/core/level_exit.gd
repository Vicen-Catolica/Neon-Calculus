class_name LevelExit
extends Area2D
## Saída de uma fase: quando o Eduardo entra, troca para a próxima pela tela de
## transição da Axioma. `next_stage` vazio desliga a saída (usado nos testes).

@export_file("*.tscn") var next_stage: String

var _used: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("Player") or next_stage == "":
		return
	_used = true
	LevelTransition.change_level(next_stage)
