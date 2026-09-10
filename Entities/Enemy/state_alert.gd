class_name StateAlert
extends State

@export var taser_damage: float = 35.0
@export var attack_cooldown: float = 0.8
var attack_timer: float = 0.0

func enter() -> void:
	var enemy = actor as Enemy
	if enemy:
		enemy.velocity = Vector2.ZERO
		attack_timer = 0.0
		print("ALERTA MÁXIMO: Inimigo travou a mira e iniciou disparos de Taser!")

func physics_update(delta: float) -> void:
	var enemy = actor as Enemy
	if not enemy or not is_instance_valid(enemy.player):
		transitioned.emit(self, "search")
		return

	# Cronômetro para o próximo disparo
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		shoot_taser(enemy)

func shoot_taser(enemy: Enemy) -> void:
	if enemy.vision_raycast.is_colliding():
		var collider = enemy.vision_raycast.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("Player")):
			if collider.has_method("take_damage"):
				collider.take_damage(taser_damage)