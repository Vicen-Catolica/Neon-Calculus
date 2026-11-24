class_name StateInvestigate
extends EnemyState
## Vai até um ponto de barulho (ex.: quiosque hackeado), olha em volta e volta à patrulha.

@export var look_time: float = 3.5
@export var give_up_time: float = 12.0

var looking: float = 0.0
var elapsed: float = 0.0
var _turn: float = 0.0


func enter() -> void:
	looking = 0.0
	elapsed = 0.0
	_turn = 0.0


func physics_update(delta: float) -> void:
	elapsed += delta
	var dist_x: float = enemy.target_noise_pos.x - enemy.global_position.x
	var dist_y: float = enemy.target_noise_pos.y - enemy.global_position.y
	if (looking > 0.0 or (absf(dist_x) < 24.0 and absf(dist_y) < 64.0) or elapsed >= give_up_time) and not enemy.is_climbing():
		looking += delta
		enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.move_speed)
		# Olha para um lado e para o outro.
		_turn += delta
		if _turn >= 1.1:
			_turn = 0.0
			var f: Vector2 = enemy.get_facing_direction()
			enemy.update_facing(-f.x)
		if looking >= look_time:
			state_machine.transition_to("Patrol")
	else:
		enemy.chase_move(enemy.target_noise_pos, enemy.move_speed)
	enemy.move_and_slide()
