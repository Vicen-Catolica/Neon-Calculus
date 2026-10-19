extends Node2D
## Script raiz de um nível: aplica limites à câmera do Eduardo e reinicia o
## estado global (andar, variância, time_scale) ao entrar/recomeçar a fase.

@export var floor_number: int = 1
@export var limit_left: int = 0
@export var limit_right: int = 4096
@export var limit_top: int = -420
@export var limit_bottom: int = 320


func _ready() -> void:
	GameManager.start_level(floor_number)
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cam := player.get_node_or_null("GameCamera") as Camera2D
	if cam:
		cam.limit_left = limit_left
		cam.limit_right = limit_right
		cam.limit_top = limit_top
		cam.limit_bottom = limit_bottom
