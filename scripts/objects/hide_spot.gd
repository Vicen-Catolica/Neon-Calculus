class_name HideSpot
extends Area2D
## Esconderijo atrás de um prop (caçamba, caixotes, sacos de lixo).
## O Eduardo se encaixa no centro horizontal desta área ao apertar `interact_world`.

func _ready() -> void:
	add_to_group("hide_spot")
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("register_hide_spot"):
		body.register_hide_spot(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("unregister_hide_spot"):
		body.unregister_hide_spot(self)
