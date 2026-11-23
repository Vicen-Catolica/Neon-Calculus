class_name StateSearch
extends EnemyState

var search_timer: float = 0.0

func enter() -> void:
	search_timer = 0.0

func physics_update(delta: float) -> void:
	search_timer += delta
	
	var arrived: bool = enemy.chase_move(enemy.last_known_player_pos, enemy.move_speed)
	if (arrived or search_timer >= 5.0) and not enemy.is_climbing():
		state_machine.transition_to("Patrol")
		return
	enemy.move_and_slide()