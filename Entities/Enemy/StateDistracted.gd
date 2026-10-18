class_name StateDistracted
extends EnemyState
## Implante hackeado "tocando": o agente para, olha o pulso e fica cego/surdo.

@export var duration: float = 5.0
var timer: float = 0.0


func enter() -> void:
	timer = 0.0
	enemy.velocity.x = 0


func physics_update(delta: float) -> void:
	timer += delta
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, enemy.move_speed)
	enemy.move_and_slide()
	if timer >= duration:
		state_machine.transition_to("Patrol")
