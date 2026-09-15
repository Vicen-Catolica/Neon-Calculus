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
	
	if abs(dist_x) < 15.0:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.move_speed)
		wait_timer += delta
		
		var max_wait = 1.0 if enemy.enemy_type == Enemy.EnemyType.CYBORG else 2.5
		if wait_timer >= max_wait:
			wait_timer = 0.0
			current_waypoint_idx = (current_waypoint_idx + 1) % enemy.waypoints.size()
	else:
		var dir_x = sign(dist_x)
		enemy.update_facing(dir_x)
		enemy.velocity.x = dir_x * enemy.move_speed

	enemy.move_and_slide()