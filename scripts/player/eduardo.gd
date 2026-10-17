class_name Eduardo
extends CharacterBody2D
## Protagonista. Origem do nó = pés. Usa apenas as ações novas do Input Map
## (move_*, run, crouch, jump, climb_*), nunca ui_*.

signal defense_changed(current_value: float, max_value: float)
signal state_changed(new_state: State)

enum State { IDLE, WALK, RUN, CROUCH, CROUCH_WALK, JUMP, FALL, CLIMB, HACK }

const GAME_OVER_SCENE: PackedScene = preload("res://scenes/GameOver/GameOver.tscn")

@export_group("Movimento")
@export var walk_speed: float = 110.0
@export var run_speed: float = 200.0
@export var crouch_speed: float = 60.0
@export var climb_speed: float = 70.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -380.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var look_ahead: float = 40.0

@export_group("Vida")
@export var max_defense: float = 100.0

var current_defense: float
var is_dead: bool = false
var state: State = State.IDLE
var facing: int = 1

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _crouching: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _ladders: Array[Area2D] = []
var _hacking: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var fx: AnimatedSprite2D = $HackFx
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var crouch_shape: CollisionShape2D = $CrouchShape
@onready var camera: Camera2D = $GameCamera


func _ready() -> void:
	add_to_group("Player")
	current_defense = max_defense
	defense_changed.emit(current_defense, max_defense)
	fx.visible = false
	_apply_crouch_shape(false)
	GameManager.state_changed.connect(_on_game_state_changed)
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _hacking:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += _gravity * delta
		move_and_slide()
		return

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	if state == State.CLIMB:
		_process_climb(dir)
	else:
		_process_ground_air(delta, dir)

	move_and_slide()
	_update_state(dir)
	_update_visuals(delta)


func _process_ground_air(delta: float, dir: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
		_coyote = maxf(_coyote - delta, 0.0)
	else:
		_coyote = coyote_time

	_update_crouch()

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not _crouching:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
	# Pulo variável: soltar o botão corta a subida.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var target := 0.0
	if dir != 0.0:
		target = dir * _current_speed()
	var rate := acceleration if dir != 0.0 else friction
	velocity.x = move_toward(velocity.x, target, rate * delta)

	if _ladder_available() and (Input.is_action_pressed("climb_up") or (Input.is_action_pressed("climb_down") and not is_on_floor())):
		_enter_climb()


func _process_climb(dir: float) -> void:
	var v := Input.get_axis("climb_up", "climb_down")
	velocity = Vector2(dir * walk_speed * 0.4, v * climb_speed)
	var leave := Input.is_action_just_pressed("jump") or not _ladder_available()
	if leave:
		_set_state(State.FALL)
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity * 0.7
	elif is_on_floor() and v > 0.0:
		_set_state(State.IDLE)


func _current_speed() -> float:
	if _crouching:
		return crouch_speed
	if Input.is_action_pressed("run") and is_on_floor():
		return run_speed
	return walk_speed


# --- Agachar -----------------------------------------------------------

func _update_crouch() -> void:
	var want := Input.is_action_pressed("crouch") and is_on_floor()
	if want and not _crouching:
		_crouching = true
		_apply_crouch_shape(true)
		sprite.play(&"crouching")
	elif not want and _crouching and _can_stand():
		_crouching = false
		_apply_crouch_shape(false)
		sprite.play_backwards(&"crouching")


func _apply_crouch_shape(crouched: bool) -> void:
	stand_shape.set_deferred("disabled", crouched)
	crouch_shape.set_deferred("disabled", not crouched)


## Há espaço para levantar? Testa a cápsula em pé na posição atual.
func _can_stand() -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = stand_shape.shape
	params.transform = global_transform * stand_shape.transform
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


# --- Escadas -----------------------------------------------------------

## Chamado pelas Areas2D de escada (grupo "ladder") via body_entered/exited.
func register_ladder(area: Area2D) -> void:
	if not _ladders.has(area):
		_ladders.append(area)


func unregister_ladder(area: Area2D) -> void:
	_ladders.erase(area)


func _ladder_available() -> bool:
	return not _ladders.is_empty()


func _enter_climb() -> void:
	if _crouching:
		_crouching = false
		_apply_crouch_shape(false)
	var ladder := _ladders[0]
	global_position.x = ladder.global_position.x
	velocity = Vector2.ZERO
	_set_state(State.CLIMB)


# --- Estado e animação -------------------------------------------------

func _update_state(dir: float) -> void:
	if state == State.CLIMB:
		return
	var s: State
	if not is_on_floor():
		s = State.JUMP if velocity.y < 0.0 else State.FALL
	elif _crouching:
		s = State.CROUCH_WALK if absf(velocity.x) > 5.0 and dir != 0.0 else State.CROUCH
	elif absf(velocity.x) > 5.0 and dir != 0.0:
		s = State.RUN if Input.is_action_pressed("run") else State.WALK
	else:
		s = State.IDLE
	_set_state(s)


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func _update_visuals(delta: float) -> void:
	sprite.flip_h = facing < 0
	# Centro do corpo no quadro fica ~2 px à direita do centro; espelha ao virar.
	sprite.position.x = -2.0 * facing
	fx.flip_h = sprite.flip_h
	fx.position.x = sprite.position.x
	camera.position.x = lerpf(camera.position.x, look_ahead * facing, 4.0 * delta)

	match state:
		State.IDLE:
			# Não corta a transição de levantar (crouching ao contrário).
			if not (sprite.animation == &"crouching" and sprite.is_playing()):
				_play(&"idle")
		State.WALK:
			_play(&"walk")
		State.RUN:
			_play(&"run")
		State.CROUCH:
			# Deixa a transição "crouching" terminar; depois segura em crouch_idle.
			if not (sprite.animation == &"crouching" and sprite.is_playing()):
				_play(&"crouch_idle")
		State.CROUCH_WALK:
			_play(&"crouch_walk")
		State.JUMP:
			_hold_frame(&"run", 2)  # placeholder até existir a arte de pulo
		State.FALL:
			_hold_frame(&"run", 5)  # placeholder até existir a arte de queda
		State.CLIMB:
			# Placeholder: anima "walk" ao subir/descer, congela parado.
			if absf(velocity.y) > 1.0:
				_play(&"walk")
			else:
				sprite.pause()


func _play(anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _hold_frame(anim: StringName, frame: int) -> void:
	if sprite.animation != anim or sprite.frame != frame:
		sprite.animation = anim
		sprite.frame = frame
	sprite.pause()


func _on_animation_finished() -> void:
	if sprite.animation == &"hack_start" and _hacking:
		sprite.play(&"hack")
		fx.play(&"hack_fx")


# --- Hack --------------------------------------------------------------

func _on_game_state_changed(new_state: GameManager.State) -> void:
	var hacking_now := new_state == GameManager.State.HACKING
	if hacking_now == _hacking:
		return
	_hacking = hacking_now
	if hacking_now:
		_crouching = false
		_apply_crouch_shape(false)
		_set_state(State.HACK)
		fx.visible = true
		sprite.play(&"hack_start")
	else:
		fx.visible = false
		fx.stop()
		_set_state(State.IDLE)


# --- Compatibilidade com Enemy / HUD / Game Over ------------------------

func get_aim_point() -> Vector2:
	return global_position + Vector2(0, -50 if _crouching else -80)


func is_running() -> bool:
	return state == State.RUN


func is_making_noise() -> bool:
	return is_running()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_defense = maxf(0.0, current_defense - amount)
	defense_changed.emit(current_defense, max_defense)
	if current_defense <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	get_tree().call_group("hud", "hide_hud")
	get_tree().root.add_child(GAME_OVER_SCENE.instantiate())
