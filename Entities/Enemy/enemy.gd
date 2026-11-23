class_name Enemy
extends CharacterBody2D

enum EnemyType { HUMAN, CYBORG }

@warning_ignore("unused_signal")
signal alarm_triggered(last_position: Vector2)

@export_category("Configurações do Inimigo")
@export var enemy_type: EnemyType = EnemyType.HUMAN
@export var move_speed: float = 120.0
@export var chase_speed: float = 180.0
@export var vision_range: float = 300.0
@export var attack_range: float = 50.0
@export var vision_angle_deg: float = 120.0
@export var taser_defense_drain: float = 15.0
@export var waypoints: Array[Node2D] = []

@export_category("Sensores")
@export_flags_2d_physics var vision_mask: int = 3 # Camada 1 (Mundo) + Camada 2 (Player)
## Altura dos olhos em relação à origem do nó (guardas com sprite de 128 px usam ~-100).
@export var eye_offset: Vector2 = Vector2(0, -20)
## Ponta da arma (olhando para a direita; espelha com o lado). O raio do
## taser sai daqui, não do meio do corpo.
@export var muzzle_offset: Vector2 = Vector2(30, -74)
## Andar normal (não agachado) só é ouvido dentro deste raio; correr usa a HearingArea inteira.
@export var walk_hearing_radius: float = 140.0
## Raio em que o guarda responde a um alarme de câmera/varredura.
@export var alarm_response_radius: float = 900.0
## Ao avistar o Eduardo, chama pelo rádio os agentes neste raio (eles chegam
## depois de `radio_delay` s). Quem atende ao rádio não repassa o chamado.
@export var radio_radius: float = 700.0
@export var radio_delay: float = 0.5

## Segundos para encher a barra de detecção com o jogador no limite do cone
## (de perto enche em `detect_time_near`).
@export var detect_time_far: float = 2.0
@export var detect_time_near: float = 0.7
## Quanto a barra esvazia por segundo sem ver o jogador.
@export var detect_decay: float = 0.4
## Unidade Lógica (ciborgue): segundos sem visão depois de hackeada (ponto cego).
@export var blind_time: float = 6.0

@export_category("Navegação")
## Pulo da perseguição (degraus, caixas, beiradas baixas). ~90 px de altura.
@export var jump_velocity: float = -420.0
@export var climb_speed: float = 120.0
## Sem caminho até o jogador em outro andar: espera a esta distância, mirando,
## em vez de espelhar os passos dele por baixo.
@export var hold_distance: float = 150.0
## Até onde procura uma escada (px na horizontal).
@export var ladder_search_range: float = 900.0

@export_category("Debug Visual")
@export var show_debug_vision: bool = true
## Desenha o cone de visão (laranja em patrulha, vermelho em alerta).
@export var show_vision_cone: bool = false

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hearing_area: Area2D = $Sensors/HearingArea
@onready var visible_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D
@onready var attack_timer: Timer = $AttackTimer
@onready var state_indicator: Label = $StateIndicator

var ray_cast: RayCast2D
var taser_line: Line2D
var player_ref: Node2D = null
var is_player_in_hearing_area: bool = false
var last_known_player_pos: Vector2 = Vector2.ZERO
var target_noise_pos: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

## Barra de detecção (0..1). Cheia = MaxAlert; acima de SUSPECT_AT o guarda estranha.
var awareness: float = 0.0
## > 0: sistema visual hackeado (só ciborgue). Não vê nada até zerar.
var blind_left: float = 0.0
## Escada em uso pela navegação (null = andando) e sentido (-1 sobe, 1 desce).
var _climb_ladder: Area2D = null
var _climb_dir: int = 0
var _saved_mask: int = 0
var _jump_cooldown: float = 0.0
## true quando o alerta veio do rádio de outro agente (não repassa).
var _by_radio: bool = false
const SUSPECT_AT: float = 0.35
## Nó filho que desenha a barra por cima do sprite (o _draw do próprio guarda
## fica atrás dos filhos e o sprite cobria a barra).
var _awareness_bar: Node2D
## Camada própria: o jogador atravessa os guardas e eles não colidem entre si.
const ENEMY_LAYER: int = 1 << 2

var is_firing_taser: bool = false
var taser_target_ref: Node2D = null

func _ready() -> void:
	if has_node("RayCast2D"):
		ray_cast = $RayCast2D
	else:
		ray_cast = RayCast2D.new()
		ray_cast.name = "RayCast2D"
		add_child(ray_cast)
		ray_cast.enabled = false

	ray_cast.position = eye_offset
	# Só colide com o mundo (camada 1); o jogador passa por dentro dos guardas
	# e um jogador escondido não trava a rota deles.
	collision_layer = ENEMY_LAYER
	collision_mask = 1

	if has_node("TaserLine"):
		taser_line = $TaserLine
	elif has_node("Line2D"):
		taser_line = $Line2D
	else:
		taser_line = Line2D.new()
		taser_line.name = "TaserLine"
		add_child(taser_line)

	taser_line.width = 3.0
	taser_line.default_color = Color(0.0, 0.94, 1.0)
	taser_line.joint_mode = Line2D.LINE_JOINT_ROUND
	taser_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	taser_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	taser_line.visible = false

	if vision_range <= 0: vision_range = 300.0
	if attack_range <= 0: attack_range = 50.0
	if vision_mask == 0: vision_mask = 3

	if is_instance_valid(ray_cast):
		ray_cast.add_exception(self)
		ray_cast.collide_with_areas = false
		ray_cast.collide_with_bodies = true

	visible_enabler.enable_mode = VisibleOnScreenEnabler2D.ENABLE_MODE_INHERIT
	
	if attack_timer:
		attack_timer.one_shot = true
		if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
			attack_timer.timeout.connect(_on_attack_timer_timeout)

	hearing_area.body_entered.connect(_on_hearing_body_entered)
	hearing_area.body_exited.connect(_on_hearing_body_exited)
	
	if ResourceLoader.exists("res://assets/fonts/ui_font.tres") and state_indicator:
		var custom_font = load("res://assets/fonts/ui_font.tres")
		state_indicator.add_theme_font_override("font", custom_font)
		state_indicator.add_theme_font_size_override("font_size", 22)
		
	add_to_group("guards")
	GameManager.alarm_raised.connect(_on_alarm_raised)
	var hackable := get_node_or_null("Hackable") as Hackable
	if hackable:
		hackable.kind = Hackable.Kind.CYBORG if enemy_type == EnemyType.CYBORG else Hackable.Kind.GUARD
		hackable.ignore_body = self
		hackable.hacked.connect(_on_hacked)

	_awareness_bar = Node2D.new()
	_awareness_bar.name = "AwarenessBar"
	_awareness_bar.z_index = 8
	add_child(_awareness_bar)
	_awareness_bar.draw.connect(_draw_awareness_bar)

	state_machine.init(self)
	get_player.call_deferred()

func _process(delta: float) -> void:
	if blind_left > 0.0:
		blind_left = maxf(blind_left - delta, 0.0)
	queue_redraw()
	if _awareness_bar:
		_awareness_bar.queue_redraw()
	_update_animation()

	if is_firing_taser and is_instance_valid(taser_target_ref):
		var start_pos = muzzle_position()
		var end_pos = _aim_point(taser_target_ref)
		generate_lightning_beam(start_pos, end_pos)

func _physics_process(delta: float) -> void:
	_jump_cooldown = maxf(_jump_cooldown - delta, 0.0)
	if _climb_ladder == null and not is_on_floor():
		velocity.y += gravity * delta
		
	check_sensors(delta)

func get_player() -> Node2D:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("Player")
		_ignore_player_body(player_ref)
	return player_ref


## O jogador também fica na camada 1 (mundo); a exceção impede que o guarda o
## trate como parede (e que um jogador escondido trave a patrulha).
func _ignore_player_body(p: Node) -> void:
	if p is PhysicsBody2D:
		add_collision_exception_with(p)

func get_facing_direction() -> Vector2:
	var is_flipped = false
	if has_node("AnimatedSprite2D"):
		is_flipped = $AnimatedSprite2D.flip_h
	elif has_node("Sprite2D"):
		is_flipped = $Sprite2D.flip_h
	return Vector2.LEFT if is_flipped else Vector2.RIGHT

func update_facing(dir_x: float) -> void:
	if dir_x == 0:
		return
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = (dir_x < 0)
	elif has_node("Sprite2D"):
		$Sprite2D.flip_h = (dir_x < 0)

# --- SISTEMA UNIFICADO DE SENSORES ---

func check_sensors(delta: float = 0.0) -> void:
	var target_player = get_player()
	var st := _current_state_name()
	if st == "maxalert":
		awareness = 1.0
	if not target_player:
		_decay_awareness(delta)
		return
	# Distraído (implante tocando) ou desacordado: não vê nem ouve.
	if st in ["distracted", "stunned"]:
		_decay_awareness(delta)
		return
	# Escondido: invisível e silencioso. Camuflado (Variável Oculta): invisível,
	# mas os passos ainda podem ser ouvidos.
	if target_player.has_method("is_detectable") and not target_player.is_detectable():
		_decay_awareness(delta)
		if target_player.get("camouflaged") and not target_player.is_hidden():
			_check_hearing(target_player, global_position.distance_to(_aim_point(target_player)))
		return
	# Ciborgue com o sistema visual hackeado: ponto cego total.
	if is_blind():
		_decay_awareness(delta)
		return

	var ray_origin = global_position + eye_offset
	var player_center = _aim_point(target_player)
	var to_player = player_center - ray_origin
	var dist_to_player = to_player.length()

	# 1. TESTE DE VISÃO (Prioridade 1 -> MaxAlert)
	var facing_dir = get_facing_direction()
	var dir_to_player = to_player.normalized()
	var dot = facing_dir.dot(dir_to_player)
	var min_dot = cos(deg_to_rad(vision_angle_deg / 2.0))
	
	var is_in_view_cone = (dot >= min_dot) and (dist_to_player <= vision_range)
	var is_touching = dist_to_player <= 60.0

	if is_in_view_cone or is_touching:
		if has_line_of_sight_to(target_player, player_center):
			last_known_player_pos = target_player.global_position
			if st == "maxalert":
				return
			# Barra de detecção: enche mais rápido de perto; encostar é instantâneo.
			var t := clampf(dist_to_player / vision_range, 0.0, 1.0)
			var fill_time := lerpf(detect_time_near, detect_time_far, t)
			awareness = 1.0 if is_touching else minf(awareness + delta / fill_time, 1.0)
			if awareness >= 1.0:
				state_machine.transition_to("MaxAlert")
			elif awareness >= SUSPECT_AT and st == "patrol" and enemy_type != EnemyType.CYBORG:
				# (a Unidade Lógica não hesita: a barra só enche até o alerta)
				target_noise_pos = target_player.global_position
				state_machine.transition_to("Suspicious")
			return
	_decay_awareness(delta)

	# 2. TESTE DE AUDIÇÃO (Prioridade 2 -> Search / Suspicious)
	_check_hearing(target_player, dist_to_player)

## Audição (Prioridade 2 -> Search / Suspicious). Também vale para o Eduardo
## camuflado: a camuflagem engana os olhos, não os ouvidos.
func _check_hearing(target_player, dist_to_player: float) -> void:
	if is_player_in_hearing_area and enemy_type != EnemyType.CYBORG:
		var current_state_name: String = ""
		if state_machine and state_machine.current_state:
			current_state_name = state_machine.current_state.name

		var is_moving = abs(target_player.velocity.x) > 10.0 or abs(target_player.velocity.y) > 10.0

		var is_running_flag = false
		if target_player.has_method("is_running"):
			is_running_flag = target_player.is_running()
		elif "is_running" in target_player:
			is_running_flag = target_player.is_running

		# Agachado não faz barulho; andando só é ouvido de perto.
		var is_silent: bool = target_player.has_method("is_silent") and target_player.is_silent()
		if is_silent or (not is_running_flag and dist_to_player > walk_hearing_radius):
			is_moving = false

		if is_moving:
			if is_running_flag:
				if current_state_name in ["Patrol", "Suspicious", "Investigate"]:
					awareness = maxf(awareness, 0.6)
					last_known_player_pos = target_player.global_position
					state_machine.transition_to("Search")
			else:
				if current_state_name == "Patrol":
					awareness = maxf(awareness, SUSPECT_AT)
					target_noise_pos = target_player.global_position
					state_machine.transition_to("Suspicious")

func _decay_awareness(delta: float) -> void:
	if _current_state_name() == "maxalert":
		return
	awareness = maxf(awareness - detect_decay * delta, 0.0)

# --- VISÃO VIA NÓ RAYCAST2D ---

func has_line_of_sight_to(target_player: Node2D, target_pos: Vector2) -> bool:
	if not is_instance_valid(ray_cast):
		return false
	# Vapor/fumaça: não colide, mas tapa a visão.
	if VisionBlocker.line_blocked(get_tree(), ray_cast.global_position, target_pos):
		return false

	ray_cast.target_position = ray_cast.to_local(target_pos)
	ray_cast.collision_mask = vision_mask if vision_mask != 0 else 3
	ray_cast.force_raycast_update()

	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider == target_player or collider.is_in_group("Player") or target_player.is_ancestor_of(collider):
			return true

	return false

func is_player_in_los() -> bool:
	var target_player = get_player()
	if not target_player:
		return false
		
	if target_player.has_method("is_detectable") and not target_player.is_detectable():
		return false
	if is_blind():
		return false
	var ray_origin = global_position + eye_offset
	var player_center = _aim_point(target_player)
	var dist_to_player = ray_origin.distance_to(player_center)

	# Se ultrapassar a distância máxima de visão, perde o contato visual imediatamente
	if dist_to_player > vision_range:
		return false
	# Colado no jogador: o raio nasceria dentro do corpo dele e não "veria" nada
	# (o guarda travava perseguindo sem atacar). Encostar é ver.
	if _aim_point(target_player).distance_to(global_position + Vector2(0, -60)) <= 70.0:
		return not VisionBlocker.line_blocked(get_tree(), ray_origin, player_center)

	return has_line_of_sight_to(target_player, player_center)

# --- AUDIÇÃO, ATAQUE E EFEITO DO TASER ---

func _on_hearing_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_ref = body
		_ignore_player_body(body)
		is_player_in_hearing_area = true

func _on_hearing_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_player_in_hearing_area = false

func try_fire_taser() -> void:
	if attack_timer and attack_timer.is_stopped():
		attack_timer.start()

func fire_taser_effect() -> void:
	var target_player = get_player()
	if not target_player:
		return

	is_firing_taser = true
	taser_target_ref = target_player
	taser_line.visible = true

	var tween = create_tween()
	tween.tween_callback(func():
		is_firing_taser = false
		taser_line.visible = false
		taser_line.clear_points()
	).set_delay(0.25)

func generate_lightning_beam(start_pos: Vector2, end_pos: Vector2, segments: int = 6, displacement: float = 10.0) -> void:
	if not is_instance_valid(taser_line):
		return

	taser_line.clear_points()
	taser_line.add_point(taser_line.to_local(start_pos))

	var dir = (end_pos - start_pos).normalized()
	var normal = Vector2(-dir.y, dir.x)

	for i in range(1, segments):
		var progress = float(i) / float(segments)
		var current_pos = start_pos.lerp(end_pos, progress)
		var offset = normal * randf_range(-displacement, displacement)
		current_pos += offset

		taser_line.add_point(taser_line.to_local(current_pos))

	taser_line.add_point(taser_line.to_local(end_pos))

func _on_attack_timer_timeout() -> void:
	var target_player = get_player()
	if not target_player:
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= attack_range and is_player_in_los():
		if target_player.has_method("take_damage"):
			target_player.take_damage(taser_defense_drain)
		fire_taser_effect()
		Sfx.play_at("taser", global_position + Vector2(0, -40), 0.0, 0.08)

func update_state_indicator(state_name: String) -> void:
	if not state_indicator:
		return

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	state_indicator.scale = Vector2(0.5, 0.5)
	tween.tween_property(state_indicator, "scale", Vector2(1.0, 1.0), 0.15)

	match state_name.to_lower():
		"patrol":
			state_indicator.visible = false
		"suspicious":
			state_indicator.visible = true
			state_indicator.text = "?"
			state_indicator.add_theme_color_override("font_color", Color("#ffaa00"))
		"search":
			state_indicator.visible = true
			state_indicator.text = "?"
			state_indicator.add_theme_color_override("font_color", Color("#ff6600"))
		"maxalert":
			state_indicator.visible = true
			state_indicator.text = "!"
			state_indicator.add_theme_color_override("font_color", Color("#ff0055"))
		"investigate":
			state_indicator.visible = true
			state_indicator.text = "?"
			state_indicator.add_theme_color_override("font_color", Color("#ffaa00"))
		"distracted":
			state_indicator.visible = true
			state_indicator.text = "~"
			state_indicator.add_theme_color_override("font_color", Color("#33f2ff"))
		_:
			state_indicator.visible = false

# --- DEBUG VISUAL DE DEPURAÇÃO DO RAYCAST ---

func _draw() -> void:
	if show_vision_cone:
		_draw_vision_cone()
	if not show_debug_vision or not is_instance_valid(ray_cast):
		return

	var origin = ray_cast.position
	var end_point = origin + ray_cast.target_position
	var line_color = Color(1.0, 0.2, 0.2, 0.8)

	if ray_cast.is_colliding():
		end_point = to_local(ray_cast.get_collision_point())
		
		var collider = ray_cast.get_collider()
		var target_player = get_player()
		
		if target_player and (collider == target_player or collider.is_in_group("Player") or target_player.is_ancestor_of(collider)):
			line_color = Color(0.2, 1.0, 0.4, 0.8)
		else:
			line_color = Color(1.0, 0.8, 0.2, 0.8)

	draw_line(origin, end_point, line_color, 2.0)
	draw_circle(end_point, 4.0, line_color)


func is_player_in_hearing_range() -> bool:
	return is_player_in_hearing_area


func _aim_point(target: Node2D) -> Vector2:
	if target.has_method("get_aim_point"):
		return target.get_aim_point()
	return target.global_position + Vector2(0, -20)


func _current_state_name() -> String:
	if state_machine and state_machine.current_state:
		return String(state_machine.current_state.name).to_lower()
	return ""


# --- Reações a hack e alarme ---------------------------------------------

## Hack no agente: o implante "toca" e ele fica distraído (cego e surdo) por alguns segundos.
func _on_hacked() -> void:
	if enemy_type == EnemyType.CYBORG:
		# Unidade Lógica (GDD §7): o hack apaga o sistema visual por `blind_time`
		# (ponto cego) e reescreve a rotina: volta à patrulha do primeiro waypoint.
		blind_left = blind_time
		awareness = 0.0
		var patrol: Node = state_machine.states.get("patrol")
		if patrol:
			patrol.current_waypoint_idx = 0
		state_machine.transition_to("Patrol")
		return
	state_machine.transition_to("Distracted")


func is_blind() -> bool:
	return blind_left > 0.0


## Chamado por distrações (quiosque, etc.): vai até o ponto e olha em volta.
func investigate(world_point: Vector2) -> void:
	if enemy_type == EnemyType.CYBORG:
		return
	if _current_state_name() in ["maxalert", "stunned"]:
		return
	target_noise_pos = world_point
	if state_machine.current_state and state_machine.current_state.name == "Investigate":
		state_machine.current_state.enter()  # reinicia com o novo ponto
	else:
		state_machine.transition_to("Investigate")


## Chamado pelo StateMaxAlert ao entrar em alerta máximo. Se foi ele quem viu o
## Eduardo (não veio do rádio nem de um alarme), chama os vizinhos.
func on_max_alert(by_alarm: bool) -> void:
	if _by_radio or by_alarm:
		_by_radio = false
		return
	Sfx.play_at("detect", global_position + Vector2(0, -60))
	var called := 0
	for g in get_tree().get_nodes_in_group("guards"):
		if g == self or not (g is Enemy):
			continue
		var e := g as Enemy
		if e._current_state_name() in ["maxalert", "stunned", "distracted"] or e.is_blind():
			continue
		if e.global_position.distance_to(global_position) > radio_radius:
			continue
		e._answer_radio(last_known_player_pos, radio_delay)
		called += 1
	if called > 0:
		Sfx.play_at("radio", global_position + Vector2(0, -60), -4.0)
		get_tree().call_group("stealth_hud", "_flash", "AGENTE CHAMOU REFORÇOS PELO RÁDIO", Color(1.0, 0.6, 0.15))
	Tutorial.event("spotted")


func _answer_radio(pos: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree() or _current_state_name() in ["maxalert", "stunned"]:
		return
	_by_radio = true
	last_known_player_pos = pos
	state_machine.transition_to("MaxAlert")


var _alarm_entering: bool = false


func entered_by_alarm() -> bool:
	var v := _alarm_entering
	_alarm_entering = false
	return v


func _on_alarm_raised(world_position: Vector2) -> void:
	if _current_state_name() in ["stunned"]:
		return
	if global_position.distance_to(world_position) > alarm_response_radius:
		return
	last_known_player_pos = world_position
	_alarm_entering = true
	state_machine.transition_to("MaxAlert")


# --- Animação --------------------------------------------------------------

func muzzle_position() -> Vector2:
	return global_position + Vector2(muzzle_offset.x * get_facing_direction().x, muzzle_offset.y)


var _anim_backwards: bool = false


func _update_animation() -> void:
	var spr := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null or spr.sprite_frames.get_animation_names().is_empty():
		return
	var moving := absf(velocity.x) > 8.0
	# Recuando (anda para um lado olhando para o outro): passos ao contrário.
	var backing := moving and is_on_floor() and signf(velocity.x) != signf(get_facing_direction().x)
	if backing:
		var walk: StringName = &"patrol"
		if spr.sprite_frames.has_animation(walk) and (spr.animation != walk or not _anim_backwards):
			spr.play_backwards(walk)
			_anim_backwards = true
		return
	if _anim_backwards:
		_anim_backwards = false
		spr.play(spr.animation)
	var anim: StringName = &"idle"
	match _current_state_name():
		"patrol":
			anim = &"patrol" if moving else &"idle"
		"suspicious", "distracted":
			anim = &"suspicious"
		"investigate", "search":
			anim = &"patrol" if moving else &"suspicious"
		"maxalert":
			if is_firing_taser or (attack_timer and not attack_timer.is_stopped()):
				anim = &"shoot"
			else:
				anim = &"chase" if moving else &"alert"
		"stunned":
			anim = &"stunned"
	if spr.sprite_frames.has_animation(anim) and spr.animation != anim:
		spr.play(anim)


# --- Cone de visão ---------------------------------------------------------

func _draw_vision_cone() -> void:
	var st := _current_state_name()
	if st in ["distracted", "stunned"]:
		return
	var origin := eye_offset
	var g_origin := global_position + eye_offset
	var facing := get_facing_direction()
	var base_angle := facing.angle()
	var half := deg_to_rad(vision_angle_deg * 0.5)
	var pts := PackedVector2Array([origin])
	var space := get_world_2d().direct_space_state
	var steps := 12
	for i in steps + 1:
		var a := base_angle - half + 2.0 * half * float(i) / float(steps)
		var end := g_origin + Vector2.from_angle(a) * vision_range
		var q := PhysicsRayQueryParameters2D.create(g_origin, end, 1)
		var ex: Array[RID] = [get_rid()]
		var p := get_player()
		if p is CollisionObject2D:
			ex.append((p as CollisionObject2D).get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			end = hit["position"]
		end = VisionBlocker.clip(get_tree(), g_origin, end)
		pts.append(end - global_position)
	var col := Color(1.0, 0.55, 0.15, 0.10)
	if is_blind():
		# Sistema visual hackeado: cone ciano apagado, piscando no fim.
		if blind_left < 1.2 and int(Time.get_ticks_msec() / 120) % 2 == 0:
			return
		col = Color(0.0, 0.94, 1.0, 0.05)
	elif st == "maxalert":
		col = Color(1.0, 0.1, 0.12, 0.22)
	elif st in ["suspicious", "search", "investigate"]:
		col = Color(1.0, 0.75, 0.1, 0.16)
	draw_colored_polygon(pts, col)


# --- Barra de detecção -----------------------------------------------------

## Hackeado (implante tocando / visão apagada): barra ciano que esvazia até ele
## voltar ao normal.
func hack_time_left() -> float:
	if _current_state_name() == "distracted":
		var s: Node = state_machine.current_state
		return clampf(1.0 - float(s.get("timer")) / maxf(float(s.get("duration")), 0.01), 0.0, 1.0)
	if is_blind():
		return clampf(blind_left / maxf(blind_time, 0.01), 0.0, 1.0)
	return 0.0


func _draw_awareness_bar() -> void:
	var st := _current_state_name()
	var hack_left := hack_time_left()
	if hack_left > 0.0:
		var hb := _awareness_bar
		var hw := 46.0
		var htop := eye_offset.y - 32.0
		if state_indicator:
			htop = state_indicator.position.y + state_indicator.size.y + 1.0
		var hp := Vector2(-hw * 0.5, htop)
		var cyan := Color(0.2, 0.95, 1.0)
		if hack_left < 0.25 and int(Time.get_ticks_msec() / 150) % 2 == 0:
			cyan = Color(1, 1, 1)
		hb.draw_rect(Rect2(hp - Vector2(2, 2), Vector2(hw + 4, 10)), Color(0, 0, 0, 0.85))
		hb.draw_rect(Rect2(hp, Vector2(hw * hack_left, 6)), cyan)
		hb.draw_rect(Rect2(hp - Vector2(1, 1), Vector2(hw + 2, 8)), Color(cyan.r, cyan.g, cyan.b, 0.9), false, 1.0)
		return
	var alert := st == "maxalert"
	if st in ["distracted", "stunned"] or (awareness <= 0.01 and not alert):
		return
	var b := _awareness_bar
	var w := 46.0
	var h := 6.0
	var top := eye_offset.y - 32.0
	if state_indicator:
		top = state_indicator.position.y + state_indicator.size.y + 1.0
	var pos := Vector2(-w * 0.5, top)
	var ratio := 1.0 if alert else awareness
	b.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(w + 4, h + 4)), Color(0, 0, 0, 0.85))
	var col := Color(1.0, 0.8, 0.15).lerp(Color(1.0, 0.1, 0.25), ratio)
	if alert and fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2:
		col = Color(1, 0.55, 0.6)
	b.draw_rect(Rect2(pos, Vector2(w * ratio, h)), col)
	b.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(col.r, col.g, col.b, 0.95), false, 1.0)
	# marca do ponto em que ele começa a estranhar
	var mx := pos.x + w * SUSPECT_AT
	b.draw_line(Vector2(mx, pos.y - 1), Vector2(mx, pos.y + h + 1), Color(0, 0, 0, 0.8), 1.0)


# --- Navegação de perseguição: pulo e escadas ---------------------------------

## Move em direção a `target` (posição de pés, global) a `speed`, mudando de
## andar quando preciso: pula degraus e obstáculos baixos, usa escadas para subir
## e descer e sai pela ponta da plataforma. Sem caminho para cima, para a
## `hold_distance` do alvo (mirando) em vez de espelhar os passos dele por baixo.
## Só ajusta `velocity` e o lado; quem chama faz o move_and_slide().
## Devolve true quando chegou (mesmo andar e perto em x).
func chase_move(target: Vector2, speed: float) -> bool:
	if _climb_ladder:
		_do_climb()
		return false
	var dx := target.x - global_position.x
	var dy := target.y - global_position.y
	if absf(dy) > 64.0 and is_on_floor():
		var lad := _ladder_toward(dy < 0.0, target)
		if lad:
			var lx := lad.global_position.x
			if absf(lx - global_position.x) <= 6.0:
				_start_climb(lad, -1 if dy < 0.0 else 1)
				return false
			_walk(signf(lx - global_position.x), speed)
			return false
		if dy < 0.0:
			# Alvo num andar de cima sem escada: segura posição e mira.
			var hold_x := target.x - signf(dx if dx != 0.0 else 1.0) * hold_distance
			update_facing(signf(dx))
			if absf(hold_x - global_position.x) > 10.0:
				_walk(signf(hold_x - global_position.x), speed)
				update_facing(signf(dx))
			else:
				velocity.x = move_toward(velocity.x, 0.0, speed)
			return false
		# Alvo embaixo sem escada: chega até a beirada e espera mirando
		# (_walk não deixa cair de plataformas).
	if absf(dx) <= 8.0:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		return absf(dy) <= 64.0
	_walk(signf(dx), speed)
	return false


## Maior queda que o agente encara andando (degraus, caixas). Mais que isso é
## beirada: ele para e espera (desce só por escada).
@export var max_step_down: float = 72.0


func _walk(dir: float, speed: float) -> void:
	update_facing(dir)
	if is_on_floor() and _ledge_ahead(dir):
		velocity.x = move_toward(velocity.x, 0.0, speed)
		return
	velocity.x = dir * speed
	if is_on_floor() and is_on_wall():
		# Obstáculo baixo na frente: pula. Parede alta (ou teto baixo em cima):
		# pular não adianta, então para em vez de ficar quicando.
		if _can_jump_over(dir):
			if _jump_cooldown <= 0.0:
				velocity.y = jump_velocity
				_jump_cooldown = 0.6
		else:
			velocity.x = 0.0


## Perto demais para o taser: recua (de frente para o alvo) se houver chão e
## espaço atrás. Devolve a velocidade x desejada (0 = fica parado).
@export var back_off_distance: float = 110.0


func back_off_velocity(target: Vector2) -> float:
	var dx := target.x - global_position.x
	if absf(dx) >= back_off_distance or not is_on_floor():
		return 0.0
	var away := -signf(dx) if dx != 0.0 else -get_facing_direction().x
	if _ledge_ahead(away) or test_move(global_transform, Vector2(away * 10.0, 0)):
		return 0.0
	return away * move_speed * 0.8


## Altura máxima do pulo (v²/2g).
func _jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * maxf(gravity, 1.0))


## Testa se, no alto do pulo, o caminho à frente está livre (e se há espaço
## em cima para subir até lá).
func _can_jump_over(dir: float) -> bool:
	var h := _jump_height() - 6.0
	if test_move(global_transform, Vector2(0, -h)):
		return false  # teto baixo: bate a cabeça
	return not test_move(global_transform.translated(Vector2(0, -h)), Vector2(dir * 14.0, 0))


## Há chão logo à frente, até `max_step_down` abaixo dos pés?
func _ledge_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 26.0, -8.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, max_step_down + 8.0), collision_mask)
	q.exclude = [get_rid()]
	q.hit_from_inside = true
	return space.intersect_ray(q).is_empty()


## Escada que leva para cima (ou para baixo) a partir do andar atual, a mais
## perto em x (preferindo as que vão para perto do alvo).
func _ladder_toward(up: bool, target: Vector2) -> Area2D:
	var best: Area2D = null
	var best_score := INF
	var feet := global_position.y
	for lad in get_tree().get_nodes_in_group("ladder"):
		var a := lad as Area2D
		var top := _ladder_top(a)
		var base := a.global_position.y
		var ok := false
		if up:
			ok = absf(base - feet) < 28.0 and top < feet - 48.0 and top >= target.y - 48.0
		else:
			ok = absf(top - feet) < 28.0 and base > feet + 48.0
		if not ok:
			continue
		var d := absf(a.global_position.x - global_position.x)
		if d > ladder_search_range:
			continue
		var score := d + absf(a.global_position.x - target.x) * 0.5
		if score < best_score:
			best_score = score
			best = a
	return best


## Superfície do topo da escada (onde se pisa ao sair dela).
func _ladder_top(a: Area2D) -> float:
	var cs := a.get_child(0) as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		return a.global_position.y + cs.position.y - (cs.shape as RectangleShape2D).size.y / 2.0 + 4.0
	return a.global_position.y


func _start_climb(lad: Area2D, dir: int) -> void:
	_climb_ladder = lad
	_climb_dir = dir
	global_position.x = lad.global_position.x
	velocity = Vector2.ZERO
	if dir > 0:
		# Descendo: atravessa a passarela de mão única (sem colisão até a base).
		_saved_mask = collision_mask
		collision_mask = 0


func _do_climb() -> void:
	var lad := _climb_ladder
	global_position.x = lad.global_position.x
	velocity = Vector2(0.0, _climb_dir * climb_speed)
	if _climb_dir < 0 and global_position.y <= _ladder_top(lad) + 2.0:
		# Chegou em cima: impulso para passar da borda e pisar na plataforma.
		velocity = Vector2(get_facing_direction().x * 40.0, -140.0)
		_climb_ladder = null
		_jump_cooldown = 0.4
	elif _climb_dir > 0 and global_position.y >= lad.global_position.y - 2.0:
		global_position.y = lad.global_position.y - 1.0
		collision_mask = _saved_mask
		velocity = Vector2.ZERO
		_climb_ladder = null


func is_climbing() -> bool:
	return _climb_ladder != null

