extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -800.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimatedSprite2D

func _physics_process(delta):
	# Adiciona a gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
		
		# Só troca para o pulo ou queda se já não estiver neles
		if velocity.y < 0:
			if anim.animation != "Jump":
				anim.play("Jump")
		else:
			if anim.animation != "Fall":
				anim.play("Fall")

	# Lida com o pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Pega a direção do movimento
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction:
		velocity.x = direction * SPEED
		
		# Vira o sprite dependendo da direção
		if direction < 0:
			anim.flip_h = true  # Vira para a esquerda
		elif direction > 0:
			anim.flip_h = false # Vira para a direita
			
		# Se estiver no chão e se movendo
		if is_on_floor():
			if anim.animation != "Run":
				anim.play("Run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		# Se estiver parado e no chão
		if is_on_floor():
			if anim.animation != "Idle":
				anim.play("Idle")

	move_and_slide()
