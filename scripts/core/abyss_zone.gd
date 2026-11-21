class_name AbyssZone
extends Area2D
## Abismo do Núcleo (Fase 4): cair no vazio não é game over. O Eduardo volta à
## última plataforma segura antes da queda e perde `damage` de Defesa Neural
## (se zerar, aí sim cai a conexão). Os pontos de retorno ficam em `respawn_points`
## (globais, no chão), em ordem da esquerda para a direita.

signal player_fell(respawn: Vector2)

@export var respawn_points: Array[Vector2] = []
@export var damage: float = 20.0


func _ready() -> void:
	add_to_group("abyss")
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


## Último ponto de retorno à esquerda de `x` (ou o primeiro, se nenhum).
func respawn_for(x: float) -> Vector2:
	var best := respawn_points[0] if not respawn_points.is_empty() else Vector2.ZERO
	for r in respawn_points:
		if r.x <= x + 40.0:
			best = r
	return best


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player") or body.get("is_dead"):
		return
	var r := respawn_for(body.global_position.x)
	body.set_deferred("global_position", r)
	body.set("velocity", Vector2.ZERO)
	get_tree().call_group("stealth_hud", "_flash", "QUEDA NO VAZIO — DEFESA NEURAL -%d" % int(damage), Color(1.0, 0.2, 0.25))
	player_fell.emit(r)
	if body.has_method("take_damage"):
		body.take_damage(damage)
