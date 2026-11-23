class_name StatePatrol
extends EnemyState

var current_waypoint_idx: int = 0
var wait_timer: float = 0.0

func enter() -> void:
	enemy.velocity.x = 0

func physics_update(delta: float) -> void:
	if enemy.waypoints.is_empty():
		enemy.move_and_slide()
		return
		
	var target_node = enemy.waypoints[current_waypoint_idx]
	var dist_x = target_node.global_position.x - enemy.global_position.x
	var dist_y = target_node.global_position.y - enemy.global_position.y

	# Fora do andar da rota (depois de uma perseguição): volta pelo caminho.
	if absf(dist_y) > 64.0 or enemy.is_climbing():
		enemy.chase_move(target_node.global_position, enemy.move_speed)
		enemy.move_and_slide()
		return

	if abs(dist_x) < 15.0:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.move_speed)
		wait_timer += delta
		
		var max_wait = 1.0 if enemy.enemy_type == Enemy.EnemyType.CYBORG else 2.5
		if wait_timer >= max_wait:
			wait_timer = 0.0
			current_waypoint_idx = (current_waypoint_idx + 1) % enemy.waypoints.size()
	else:
		enemy.chase_move(target_node.global_position, enemy.move_speed)

	enemy.move_and_slide()