class_name StatePatrol
extends State

@export var arrival_distance: float = 20.0
@export var wait_time: float = 1.0 # Tempo (em segundos) que ele espera no waypoint antes de voltar

var current_waypoint_idx: int = 0
var is_waiting: bool = false
var wait_timer: float = 0.0

func enter() -> void:
	var enemy = actor as Enemy
	if not enemy or enemy.waypoints.is_empty():
		return

	current_waypoint_idx = 0
	is_waiting = false
	wait_timer = 0.0
	print("Patrulha iniciada! Indo em direção ao Waypoint 0.")

func update(delta: float) -> void:
	# Contagem regressiva da pausa ao chegar no ponto
	if is_waiting:
		wait_timer -= delta
		if wait_timer <= 0.0:
			is_waiting = false

func physics_update(_delta: float) -> void:
	var enemy = actor as Enemy
	if not enemy or enemy.waypoints.is_empty():
		return

	# Se estiver aguardando no waypoint, mantém o inimigo parado
	if is_waiting:
		enemy.velocity.x = 0
		enemy.move_and_slide()
		return

	var current_waypoint = enemy.waypoints[current_waypoint_idx]
	if not is_instance_valid(current_waypoint):
		return

	# Distância horizontal no eixo X
	var distance_x = abs(enemy.global_position.x - current_waypoint.global_position.x)

	# Se chegou ao ponto atual
	if distance_x <= arrival_distance:
		# Troca para o próximo waypoint no array (0 -> 1 -> 0 -> 1)
		current_waypoint_idx = (current_waypoint_idx + 1) % enemy.waypoints.size()
		print("Alcançou o waypoint! Novo alvo: Waypoint ", current_waypoint_idx)
		
		# Ativa a pausa no ponto
		is_waiting = true
		wait_timer = wait_time
		enemy.velocity.x = 0
		enemy.move_and_slide()
		return

	# Direção da movimentação no eixo X (-1 para esquerda, 1 para direita)
	var dir_x = sign(current_waypoint.global_position.x - enemy.global_position.x)
	enemy.velocity.x = dir_x * enemy.speed_patrol
	
	enemy.move_and_slide()
