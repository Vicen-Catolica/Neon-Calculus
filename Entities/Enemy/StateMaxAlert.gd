class_name StateMaxAlert
extends EnemyState

@export var lose_interest_time: float = 3.0
var lose_sight_timer: float = 0.0

func enter() -> void:
	lose_sight_timer = 0.0
	enemy.alarm_triggered.emit(enemy.last_known_player_pos)

func physics_update(delta: float) -> void:
	var target_player = enemy.get_player()
	if not target_player:
		state_machine.transition_to("Search")
		return

	var has_los = enemy.is_player_in_los()
	var dist_to_player = enemy.global_position.distance_to(target_player.global_position)

	if has_los:
		lose_sight_timer = 0.0
		enemy.last_known_player_pos = target_player.global_position

		var dist_x = target_player.global_position.x - enemy.global_position.x
		if abs(dist_x) > 5.0:
			enemy.update_facing(sign(dist_x))

		if dist_to_player <= enemy.attack_range:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.chase_speed)
			enemy.try_fire_taser()
		else:
			var dir_x = sign(dist_x)
			enemy.velocity.x = dir_x * enemy.chase_speed
	else:
		lose_sight_timer += delta
		
		var dist_to_last_pos = enemy.last_known_player_pos.x - enemy.global_position.x
		if abs(dist_to_last_pos) > 10.0:
			var dir_x = sign(dist_to_last_pos)
			enemy.update_facing(dir_x)
			enemy.velocity.x = dir_x * enemy.chase_speed
		else:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.chase_speed)

		if lose_sight_timer >= lose_interest_time:
			state_machine.transition_to("Search")

	enemy.move_and_slide()