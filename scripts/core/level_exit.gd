class_name LevelExit
extends Area2D
## Saída de uma fase: quando o Eduardo entra, troca para a próxima pela tela de
## transição da Axioma. `next_stage` vazio desliga a saída (usado nos testes).

@export_file("*.tscn") var next_stage: String
## true = só vale com o Eduardo em pé no chão dentro da área, com os pés na
## altura da base dela (ex.: dentro do elevador). Evita sair da fase só por
## encostar a cabeça na área subindo uma escada por baixo.
@export var require_standing: bool = false

var _used: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if require_standing:
		return  # conferido a cada quadro em _physics_process
	_leave(body)


func _physics_process(_delta: float) -> void:
	if not require_standing or _used:
		return
	for b in get_overlapping_bodies():
		if b is CharacterBody2D and (b as CharacterBody2D).is_on_floor() \
				and absf(b.global_position.y - global_position.y) <= 8.0:
			_leave(b)
			return


func _leave(body: Node2D) -> void:
	if _used or not body.is_in_group("Player") or next_stage == "":
		return
	_used = true
	LevelTransition.change_level(next_stage)
