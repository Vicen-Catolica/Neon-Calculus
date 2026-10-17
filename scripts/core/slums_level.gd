extends Node2D
## Script raiz de um nível das favelas: aplica limites à câmera do Eduardo.

@export var limit_left: int = 0
@export var limit_right: int = 4096
@export var limit_top: int = -420
@export var limit_bottom: int = 320


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cam := player.get_node_or_null("GameCamera") as Camera2D
	if cam:
		cam.limit_left = limit_left
		cam.limit_right = limit_right
		cam.limit_top = limit_top
		cam.limit_bottom = limit_bottom