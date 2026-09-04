extends Area2D

@export var floor_level: int = 1
@export var is_unlocked: bool = false

var player_in_range: bool = false
@export var hacking_ui: CanvasLayer 

func _ready() -> void:
	body_entered.connect(func(body): if body.is_in_group("Player"): player_in_range = true)
	body_exited.connect(func(body): if body.is_in_group("Player"): player_in_range = false)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_unlocked and event.is_action_pressed("Interact"):
		_start_terminal_hack()

func _start_terminal_hack() -> void:
	# Escuta a resposta de sucesso ou falha emitida pela UI[cite: 1]
	if not hacking_ui.hacking_succeeded.is_connected(_on_success):
		hacking_ui.hacking_succeeded.connect(_on_success, CONNECT_ONE_SHOT)
	if not hacking_ui.hacking_failed.is_connected(_on_failure):
		hacking_ui.hacking_failed.connect(_on_failure, CONNECT_ONE_SHOT)
	
	hacking_ui.start_hacking(floor_level)

func _on_success() -> void:
	is_unlocked = true
	print("Terminal hackeado! Porta aberta/câmera desativada.")

func _on_failure() -> void:
	print("Falha no hack! Alarme ou Lockdown ativado.")
