class_name Player
extends CharacterBody2D

signal defense_changed(current_value: float, max_value: float)

const GAME_OVER_SCENE: PackedScene = preload("res://scenes/GameOver/GameOver.tscn")

@export var speed_walk: float = 200.0
@export var speed_run: float = 350.0
@export var jump_velocity: float = -600.0

@export var max_defense: float = 100.0
var current_defense: float
var is_moving_fast: bool = false
var is_dead: bool = false # Trava para evitar execução repetida do Game Over

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	current_defense = max_defense
	defense_changed.emit(current_defense, max_defense)

func _physics_process(delta: float) -> void:
	# Se já estiver morto, não processa movimentação
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y < 0:
			if anim.animation != "Jump":
				anim.play("Jump")
		else:
			if anim.animation != "Fall":
				anim.play("Fall")

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	is_moving_fast = Input.is_key_pressed(KEY_SHIFT)
	var current_speed = speed_run if is_moving_fast else speed_walk

	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = direction * current_speed
		if direction < 0:
			anim.flip_h = true
		elif direction > 0:
			anim.flip_h = false
			
		if is_on_floor():
			if is_moving_fast:
				if anim.animation != "Run":
					anim.play("Run")
			else:
				if anim.sprite_frames.has_animation("Walk"):
					if anim.animation != "Walk":
						anim.play("Walk")
				else:
					if anim.animation != "Run":
						anim.play("Run")
	else:
		velocity.x = move_toward(velocity.x, 0, speed_walk)
		is_moving_fast = false
		if is_on_floor():
			if anim.animation != "Idle":
				anim.play("Idle")

	move_and_slide()

func is_running() -> bool:
	return is_moving_fast and is_on_floor() and velocity.x != 0

func take_damage(amount: float) -> void:
	# Se já morreu, ignora novos danos para não repetir a chamada
	if is_dead:
		return

	current_defense -= amount
	
	if current_defense <= 0.0:
		current_defense = 0.0
		defense_changed.emit(current_defense, max_defense)
		die()
	else:
		defense_changed.emit(current_defense, max_defense)

func die() -> void:
	# Impede que a função rode mais de uma vez
	if is_dead:
		return
		
	is_dead = true
	print("GAME OVER: Eduardo foi totalmente incapacitado!")
	
	# Oculta o HUD
	get_tree().call_group("hud", "hide_hud")
	
	# Instancia a tela de Game Over apenas UMA vez
	if GAME_OVER_SCENE:
		var game_over_instance = GAME_OVER_SCENE.instantiate()
		get_tree().root.add_child(game_over_instance)
