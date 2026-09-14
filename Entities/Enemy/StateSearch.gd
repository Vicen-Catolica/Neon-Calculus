class_name StateSearch
extends EnemyState

var search_timer: float = 0.0

func enter() -> void:
	search_timer = 0.0

func physics_update(delta: float) -> void:
	search_timer += delta
	
	var dist_x = enemy.last_known_player_pos.x - enemy.global_position.x
	
	if abs(dist_x) < 20.0 or search_timer >= 5.0:
		state_machine.transition_to("Patrol")
		return
		
	var dir_x = sign(dist_x)
	enemy.update_facing(dir_x)
	enemy.velocity.x = dir_x * enemy.move_speed
	enemy.move_and_slide()