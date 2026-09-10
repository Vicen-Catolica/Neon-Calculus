class_name StateSuspect
extends State

@export var suspect_duration: float = 3.0
var timer: float = 0.0

func enter() -> void:
	timer = suspect_duration
	var enemy = actor as Enemy
	if enemy:
		enemy.velocity = Vector2.ZERO
		enemy.vision_raycast.target_position = enemy.to_local(enemy.last_known_player_position)

func update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		transitioned.emit(self, "patrol")