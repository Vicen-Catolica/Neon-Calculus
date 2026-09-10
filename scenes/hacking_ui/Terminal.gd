extends Area2D

@export_range(1, 4) var stage_level: int = 1
@export var is_unlocked: bool = false
@export var hacking_ui: CanvasLayer 

@export_enum("Automático", "Forçar Tema 1", "Forçar Tema 2") var topic_mode: int = 0

var player_in_range: bool = false
var sub_topic: int = 0

func _ready() -> void:
	add_to_group("Terminals")
	body_entered.connect(func(body): if body.is_in_group("Player"): player_in_range = true)
	body_exited.connect(func(body): if body.is_in_group("Player"): player_in_range = false)
	
	if not hacking_ui:
		hacking_ui = get_tree().current_scene.find_child("HackingInterface", true, false)
	
	# Detecta automaticamente o nível da fase pelo nome do nó raiz da cena (ex: stage1, stage2)
	var current_scene_name = get_tree().current_scene.name.to_lower()
	if current_scene_name.begins_with("stage"):
		var level_num = current_scene_name.replace("stage", "").to_int()
		if level_num >= 1 and level_num <= 4:
			stage_level = level_num # Atualiza para 2, 3 ou 4 automaticamente
			
	await get_tree().process_frame
	_calculate_sub_topic()

func _calculate_sub_topic() -> void:
	if topic_mode == 1:
		sub_topic = 0
	elif topic_mode == 2:
		sub_topic = 1
	else:
		var all_terminals = get_tree().get_nodes_in_group("Terminals")
		var my_index = all_terminals.find(self)
		var half_count = ceil(float(all_terminals.size()) / 2.0)
		
		if my_index < half_count:
			sub_topic = 0
		else:
			sub_topic = 1

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_unlocked and event.is_action_pressed("Interact"):
		_start_terminal_hack()

func _start_terminal_hack() -> void:
	if not hacking_ui:
		return
		
	if not hacking_ui.hacking_succeeded.is_connected(_on_success):
		hacking_ui.hacking_succeeded.connect(_on_success, CONNECT_ONE_SHOT)
	if not hacking_ui.hacking_failed.is_connected(_on_failure):
		hacking_ui.hacking_failed.connect(_on_failure, CONNECT_ONE_SHOT)
	
	hacking_ui.start_hacking(stage_level, sub_topic)

func _on_success() -> void:
	is_unlocked = true
	print("Terminal hackeado!")

func _on_failure() -> void:
	print("Falha no hack!")
