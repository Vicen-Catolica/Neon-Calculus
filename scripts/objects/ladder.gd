class_name Ladder
extends Area2D
## Escada: Area2D sem colisão física. Registra-se no Eduardo ao ser tocada.

func _ready() -> void:
	add_to_group("ladder")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("register_ladder"):
		body.register_ladder(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("unregister_ladder"):
		body.unregister_ladder(self)