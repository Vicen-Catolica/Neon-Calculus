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

@export_category("Debug Visual")
@export var show_debug_vision: bool = true

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

	ray_cast.position = Vector2(0, -20)

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
	
	if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf") and state_indicator:
		var custom_font = load("res://assets/fonts/Orbitron-Bold.ttf")
		state_indicator.add_theme_font_override("font", custom_font)
		state_indicator.add_theme_font_size_override("font_size", 22)
		
	state_machine.init(self)

func _process(_delta: float) -> void:
	if show_debug_vision:
		queue_redraw()

	if is_firing_taser and is_instance_valid(taser_target_ref):
		var start_pos = global_position + Vector2(0, -20)
		var end_pos = taser_target_ref.global_position + Vector2(0, -20)
		generate_lightning_beam(start_pos, end_pos)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
	check_sensors()

func get_player() -> Node2D:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("Player")
	return player_ref

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

func check_sensors() -> void:
	var target_player = get_player()
	if not target_player:
		return

	var ray_origin = global_position + Vector2(0, -20)
	var player_center = target_player.global_position + Vector2(0, -20)
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
			if state_machine and state_machine.current_state and state_machine.current_state.name != "MaxAlert":
				state_machine.transition_to("MaxAlert")
			return

	# 2. TESTE DE AUDIÇÃO (Prioridade 2 -> Search / Suspicious)
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

		if is_moving:
			if is_running_flag:
				if current_state_name in ["Patrol", "Suspicious"]:
					last_known_player_pos = target_player.global_position
					state_machine.transition_to("Search")
			else:
				if current_state_name == "Patrol":
					target_noise_pos = target_player.global_position
					state_machine.transition_to("Suspicious")

# --- VISÃO VIA NÓ RAYCAST2D ---

func has_line_of_sight_to(target_player: Node2D, target_pos: Vector2) -> bool:
	if not is_instance_valid(ray_cast):
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
		
	var ray_origin = global_position + Vector2(0, -20)
	var player_center = target_player.global_position + Vector2(0, -20)
	var dist_to_player = ray_origin.distance_to(player_center)

	# Se ultrapassar a distância máxima de visão, perde o contato visual imediatamente
	if dist_to_player > vision_range:
		return false

	return has_line_of_sight_to(target_player, player_center)

# --- AUDIÇÃO, ATAQUE E EFEITO DO TASER ---

func _on_hearing_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_ref = body
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

# --- DEBUG VISUAL DE DEPURAÇÃO DO RAYCAST ---

func _draw() -> void:
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