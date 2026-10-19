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
var _air_speed: float = 110.0
var _landing: bool = false
var _climb_cooldown: float = 0.0
var _hidden: bool = false
var _hide_spots: Array[Area2D] = []
var _lights: Array[Node] = []

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

	if _hidden:
		_process_hidden(delta, dir)
		return
	if Input.is_action_just_pressed("interact_world") and _try_hide():
		return

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

	var speed := _current_speed()
	var target := dir * speed
	var rate := acceleration if dir != 0.0 else friction
	velocity.x = move_toward(velocity.x, target, rate * delta)

	_climb_cooldown = maxf(_climb_cooldown - delta, 0.0)
	if _climb_cooldown <= 0.0 and _ladder_available() and (Input.is_action_pressed("climb_up") or (Input.is_action_pressed("climb_down") and not is_on_floor())):
		_enter_climb()


func _process_climb(dir: float) -> void:
	var v := Input.get_axis("climb_up", "climb_down")
	velocity = Vector2(dir * walk_speed * 0.4, v * climb_speed)
	var leave := Input.is_action_just_pressed("jump") or not _ladder_available()
	if leave:
		_set_state(State.FALL)
		# Não reagarra a escada logo em seguida (senão, ao chegar no topo
		# segurando "subir", ele cai de volta nela antes de pisar na plataforma).
		_climb_cooldown = 0.35
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity * 0.7
		elif v < 0.0:
			velocity.y = -160.0  # impulso para passar da borda da plataforma
	elif is_on_floor() and v > 0.0:
		_set_state(State.IDLE)


func _current_speed() -> float:
	# No ar mantém a velocidade horizontal máxima de quando saiu do chão
	# (pular correndo conserva a corrida).
	if not is_on_floor():
		return _air_speed
	if _crouching:
		_air_speed = crouch_speed
	elif Input.is_action_pressed("run"):
		_air_speed = run_speed
	else:
		_air_speed = walk_speed
	return _air_speed


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
	# 3 px acima: o contato da base com o chão não conta como obstáculo.
	params.transform = global_transform.translated(Vector2(0, -3)) * stand_shape.transform
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


# --- Esconderijos e luz ------------------------------------------------

## Chamado pelas Areas2D de esconderijo (grupo "hide_spot").
func register_hide_spot(area: Area2D) -> void:
	if not _hide_spots.has(area):
		_hide_spots.append(area)


func unregister_hide_spot(area: Area2D) -> void:
	_hide_spots.erase(area)


## Chamado pela LightZone de um letreiro neon aceso.
func enter_light(source: Node) -> void:
	if not _lights.has(source):
		_lights.append(source)


func exit_light(source: Node) -> void:
	_lights.erase(source)


func is_in_light() -> bool:
	return not _lights.is_empty()


func is_hidden() -> bool:
	return _hidden


## Guardas e câmeras só enxergam o jogador se ele não estiver escondido no escuro.
func is_detectable() -> bool:
	return not (_hidden and _lights.is_empty())


## Agachado ou escondido: passos silenciosos.
func is_silent() -> bool:
	return _hidden or _crouching


func can_hide() -> bool:
	return not _hide_spots.is_empty() and is_on_floor() and _lights.is_empty() and state != State.CLIMB


## Texto de ajuda para a HUD.
func get_interaction_hint() -> String:
	if _hidden:
		return "[F] SAIR DO ESCONDERIJO"
	if not _hide_spots.is_empty():
		if not _lights.is_empty():
			return "LUZ DEMAIS PARA SE ESCONDER — APAGUE O NEON"
		return "[F] ESCONDER"
	return ""


func _try_hide() -> bool:
	if not can_hide():
		return false
	var spot := _hide_spots[0]
	_hidden = true
	_crouching = true
	_apply_crouch_shape(true)
	velocity = Vector2.ZERO
	global_position.x = spot.global_position.x
	z_index = -1
	sprite.modulate = Color(0.35, 0.38, 0.5)
	if sprite.animation != &"crouch_idle":
		sprite.play(&"crouching")
	_set_state(State.CROUCH)
	return true


func _unhide() -> void:
	_hidden = false
	z_index = 0
	sprite.modulate = Color.WHITE


func _process_hidden(delta: float, dir: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	velocity.x = 0.0
	move_and_slide()
	if Input.is_action_just_pressed("interact_world") or dir != 0.0 or Input.is_action_just_pressed("jump"):
		_unhide()
		return
	if not (sprite.animation == &"crouching" and sprite.is_playing()):
		_play(&"crouch_idle")


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
	var was_air := state == State.JUMP or state == State.FALL
	state = s
	if was_air and s == State.IDLE and is_on_floor():
		_landing = true
		sprite.play(&"land")
	if s == State.CLIMB:
		sprite.play(&"ladder_enter")
	state_changed.emit(s)


func _update_climb_visuals() -> void:
	# Primeiro toca a entrada (vira de costas); depois o ciclo de subida.
	if sprite.animation == &"ladder_enter" and sprite.is_playing():
		return
	if sprite.animation != &"ladder_climb":
		sprite.animation = &"ladder_climb"
	if velocity.y < -1.0:
		if not sprite.is_playing() or sprite.get_playing_speed() < 0.0:
			sprite.play(&"ladder_climb")
	elif velocity.y > 1.0:
		if not sprite.is_playing() or sprite.get_playing_speed() > 0.0:
			sprite.play_backwards(&"ladder_climb")
	else:
		# Parado na escada: segura a pose neutra.
		sprite.pause()
		sprite.frame = 2


func _update_visuals(delta: float) -> void:
	# Na escada ele fica de costas: sem espelhar.
	var mirror := facing < 0 and state != State.CLIMB
	sprite.flip_h = mirror
	# Centro do corpo no quadro fica ~2 px à direita do centro; espelha ao virar.
	sprite.position.x = 2.0 if mirror else -2.0
	fx.flip_h = sprite.flip_h
	fx.position.x = sprite.position.x
	camera.position.x = lerpf(camera.position.x, look_ahead * facing, 4.0 * delta)

	# Aterrissagem: toca "land" uma vez; andar/correr cortam a animação.
	if _landing and (state != State.IDLE or not (sprite.animation == &"land" and sprite.is_playing())):
		_landing = false

	match state:
		State.IDLE:
			# Não corta a transição de levantar (crouching ao contrário) nem a aterrissagem.
			if _landing:
				pass
			elif not (sprite.animation == &"crouching" and sprite.is_playing()):
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
			# Toca uma vez e segura o último quadro (ápice).
			if sprite.animation != &"jump":
				sprite.play(&"jump")
		State.FALL:
			_play(&"fall")
		State.CLIMB:
			_update_climb_visuals()


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
	if _hidden or (_crouching and not _can_stand()):
		# Hackeando escondido ou embaixo de um teto baixo (túnel, puxadinho):
		# continua agachado; levantar aqui prendia o Eduardo no teto.
		return
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
