class_name StateSearch
extends State

func enter() -> void:
	var enemy = actor as Enemy
	if enemy:
		enemy.nav_agent.target_position = enemy.last_known_player_position

func physics_update(_delta: float) -> void:
	var enemy = actor as Enemy
	if not enemy:
		return

	if enemy.nav_agent.is_navigation_finished():
		transitioned.emit(self, "suspect")
		return

	var next_pos = enemy.nav_agent.get_next_path_position()
	var dir = (next_pos - enemy.global_position).normalized()
	enemy.velocity = dir * enemy.speed_search
	enemy.move_and_slide()