class_name StateSuspicious
extends EnemyState

var investigation_timer: float = 0.0

func enter() -> void:
	investigation_timer = 0.0
	enemy.velocity.x = 0
	# Vira para o que chamou a atenção (barulho ou vulto visto de relance).
	var dx: float = enemy.target_noise_pos.x - enemy.global_position.x
	if absf(dx) > 4.0:
		enemy.update_facing(signf(dx))

func physics_update(delta: float) -> void:
	investigation_timer += delta
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.move_speed)
	enemy.move_and_slide()
	
	if investigation_timer >= 2.0:
		state_machine.transition_to("Search")