class_name Level
extends Node2D
## Script raiz de uma fase (andar da torre): aplica limites à câmera do Eduardo,
## reinicia o estado global (andar, variância, time_scale) ao entrar/recomeçar e
## grava o checkpoint do início do andar (TDD: salvamento automático por andar).

@export var floor_number: int = 1
@export var limit_left: int = 0
@export var limit_right: int = 4096
@export var limit_top: int = -420
@export var limit_bottom: int = 320


func _ready() -> void:
	GameManager.start_level(floor_number)
	# Só a fase "de verdade" grava checkpoint; simulações instanciam a fase
	# como filha de outra cena e não devem mexer no save do jogador.
	if get_tree().current_scene == self and scene_file_path != "":
		SaveGame.save_checkpoint(floor_number, scene_file_path)
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cam := player.get_node_or_null("GameCamera") as Camera2D
	if cam:
		cam.limit_left = limit_left
		cam.limit_right = limit_right
		cam.limit_top = limit_top
		cam.limit_bottom = limit_bottom
