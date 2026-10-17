# SecurityCamera
extends Node2D

enum CameraState { SCANNING, DETECTING, ALERT, HACKED }

signal alerta(detected_position: Vector2)
signal state_changed(old_state: int, new_state: int)
signal camera_hacked(duration: float)
signal camera_restored

@export_category("Varredura e Rotacao")
@export var is_sweeping: bool = true
@export var sweep_speed_deg: float = 30.0
@export var angle_min_deg: float = 25.0
@export var angle_max_deg: float = 85.0
@export var pause_at_bounds: float = 0.8
@export var mount_on_ceiling: bool = true

@export_category("Visao e Deteccao")
@export var vision_range: float = 380.0
@export var fov_deg: float = 50.0
@export var detection_time: float = 0.5
@export var alert_duration: float = 3.5
@export_flags_2d_physics var obstacle_mask: int = 1
@export_flags_2d_physics var player_mask: int = 3
@export var ray_density: int = 20

@export_category("Hacking (Subversao Matematica)")
@export var is_hacked: bool = false
@export var default_hack_duration: float = 20.0

@export_category("Estetica Neon Cyberpunk e Acessibilidade")
@export var color_scan: Color = Color(1.0, 0.35, 0.05, 0.22)
@export var color_detecting: Color = Color(1.0, 0.75, 0.0, 0.35)
@export var color_alert: Color = Color(1.0, 0.05, 0.2, 0.5)
@export var color_hacked: Color = Color(0.0, 0.88, 1.0, 0.2)
@export var show_scanline: bool = true
@export var show_range_grid: bool = true

var current_state: int = CameraState.SCANNING
var current_aim_angle_deg: float = 55.0
var sweep_direction: float = 1.0
var sweep_pause_timer: float = 0.0

var detection_progress: float = 0.0
var anim_pulse_time: float = 0.0
var last_detected_pos: Vector2 = Vector2.ZERO
var cached_cone_polygon: PackedVector2Array = PackedVector2Array()

var alert_timer: Timer
var hack_timer: Timer
var state_label: Label

func _ready() -> void:
	add_to_group("SecurityCameras")
	
	if has_node("AlertTimer"):
		alert_timer = $AlertTimer as Timer
		alert_timer.one_shot = true
		if not alert_timer.timeout.is_connected(_on_alert_timeout):
			alert_timer.timeout.connect(_on_alert_timeout)
	else:
		alert_timer = Timer.new()
		alert_timer.name = "AlertTimer"
		alert_timer.one_shot = true
		alert_timer.timeout.connect(_on_alert_timeout)
		add_child(alert_timer)
		
	if has_node("HackTimer"):
		hack_timer = $HackTimer as Timer
		hack_timer.one_shot = true
		if not hack_timer.timeout.is_connected(_on_hack_timeout):
			hack_timer.timeout.connect(_on_hack_timeout)
	else:
		hack_timer = Timer.new()
		hack_timer.name = "HackTimer"
		hack_timer.one_shot = true
		hack_timer.timeout.connect(_on_hack_timeout)
		add_child(hack_timer)
		
	if has_node("StateLabel"):
		state_label = $StateLabel as Label
		
	current_aim_angle_deg = clamp(current_aim_angle_deg, angle_min_deg, angle_max_deg)
	
	if is_hacked:
		hack_disable(default_hack_duration)
	else:
		_set_state(CameraState.SCANNING)

func _physics_process(delta: float) -> void:
	anim_pulse_time += delta
	
	if current_state == CameraState.HACKED:
		_process_hacked_state(delta)
		queue_redraw()
		return
		
	_process_sweeping(delta)
	_update_cone_geometry()
	_process_detection(delta)
	
	queue_redraw()

func _process_sweeping(delta: float) -> void:
	if current_state == CameraState.ALERT:
		return
		
	if not is_sweeping:
		return
		
	if sweep_pause_timer > 0.0:
		sweep_pause_timer -= delta
		return
		
	current_aim_angle_deg += sweep_direction * sweep_speed_deg * delta
	
	if current_aim_angle_deg >= angle_max_deg:
		current_aim_angle_deg = angle_max_deg
		sweep_direction = -1.0
		sweep_pause_timer = pause_at_bounds
	elif current_aim_angle_deg <= angle_min_deg:
		current_aim_angle_deg = angle_min_deg
		sweep_direction = 1.0
		sweep_pause_timer = pause_at_bounds

func _update_cone_geometry() -> void:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return
		
	var poly = PackedVector2Array()
	poly.append(Vector2.ZERO)
	
	var half_fov = fov_deg / 2.0
	var start_ang = deg_to_rad(current_aim_angle_deg - half_fov)
	var end_ang = deg_to_rad(current_aim_angle_deg + half_fov)
	var step_ang = (end_ang - start_ang) / float(ray_density - 1)
	
	var origin_global = global_position
	
	for i in range(ray_density):
		var ang = start_ang + float(i) * step_ang
		var dir = Vector2(cos(ang), sin(ang))
		var target_global = origin_global + dir * vision_range
		
		var query = PhysicsRayQueryParameters2D.create(origin_global, target_global, obstacle_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [self]
		
		var hit = space_state.intersect_ray(query)
		if hit:
			poly.append(to_local(hit.position))
		else:
			poly.append(to_local(target_global))
			
	cached_cone_polygon = poly

func _process_detection(delta: float) -> void:
	var player = _get_player()
	if not player:
		_decay_detection(delta)
		return
		
	if player.get("is_dead") == true:
		_decay_detection(delta)
		return
		
	if player.get("is_cloaked") == true or player.get("is_hidden") == true:
		_decay_detection(delta)
		return
		
	var player_center = player.global_position + Vector2(0, -20)
	var to_player = player_center - global_position
	var dist = to_player.length()
	
	if dist > vision_range:
		_decay_detection(delta)
		return
		
	var angle_to_player_deg = rad_to_deg(to_player.angle())
	var angle_diff = abs(wrapf(angle_to_player_deg - current_aim_angle_deg, -180.0, 180.0))
	
	if angle_diff <= (fov_deg / 2.0):
		if _has_line_of_sight(player, player_center):
			last_detected_pos = player.global_position
			detection_progress += delta / detection_time
			
			if detection_progress >= 1.0:
				_trigger_alert(last_detected_pos)
			elif current_state != CameraState.ALERT:
				_set_state(CameraState.DETECTING)
			return
			
	_decay_detection(delta)

func _decay_detection(delta: float) -> void:
	if current_state == CameraState.ALERT:
		return
		
	if detection_progress > 0.0:
		detection_progress = max(0.0, detection_progress - delta * 1.5)
		if detection_progress == 0.0 and current_state == CameraState.DETECTING:
			_set_state(CameraState.SCANNING)

func _has_line_of_sight(target: Node2D, target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
		
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos, player_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	
	var hit = space_state.intersect_ray(query)
	if hit:
		var collider = hit.collider
		if collider == target or collider.is_in_group("Player") or target.is_ancestor_of(collider):
			return true
	return false

func _trigger_alert(intruder_pos: Vector2) -> void:
	if current_state != CameraState.ALERT:
		_set_state(CameraState.ALERT)
		alerta.emit(intruder_pos)
		get_tree().call_group("Enemies", "on_external_alert", intruder_pos)
		
		if has_node("AudioAlert"):
			var audio = $AudioAlert as AudioStreamPlayer2D
			if audio and not audio.playing:
				audio.play()
				
	if alert_timer:
		alert_timer.start(alert_duration)

func _on_alert_timeout() -> void:
	detection_progress = 0.0
	_set_state(CameraState.SCANNING)

func hack_disable(duration: float = -1.0) -> void:
	var actual_duration = default_hack_duration if duration == 0.0 else duration
	is_hacked = true
	detection_progress = 0.0
	_set_state(CameraState.HACKED)
	camera_hacked.emit(actual_duration)
	
	if actual_duration > 0.0 and hack_timer:
		hack_timer.start(actual_duration)

func restore_camera() -> void:
	is_hacked = false
	detection_progress = 0.0
	if hack_timer:
		hack_timer.stop()
	_set_state(CameraState.SCANNING)
	camera_restored.emit()

func _on_hack_timeout() -> void:
	restore_camera()

func _process_hacked_state(_delta: float) -> void:
	_update_cone_geometry()

func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	_update_label()

func _update_label() -> void:
	if not state_label:
		return
		
	match current_state:
		CameraState.SCANNING:
			state_label.text = "SCAN"
			state_label.add_theme_color_override("font_color", Color("#ff5500"))
		CameraState.DETECTING:
			state_label.text = "?"
			state_label.add_theme_color_override("font_color", Color("#ffaa00"))
		CameraState.ALERT:
			state_label.text = "ALERTA!"
			state_label.add_theme_color_override("font_color", Color("#ff0044"))
		CameraState.HACKED:
			state_label.text = "[OFFLINE]"
			state_label.add_theme_color_override("font_color", Color("#00f0ff"))

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("Player")

func _draw() -> void:
	_draw_vision_cone()
	_draw_camera_mount()
	_draw_camera_head()

func _draw_vision_cone() -> void:
	if cached_cone_polygon.size() < 3:
		return
		
	var fill_col: Color
	var border_col: Color
	
	match current_state:
		CameraState.SCANNING:
			var pulse = 0.05 * sin(anim_pulse_time * 3.0)
			fill_col = Color(color_scan.r, color_scan.g, color_scan.b, clamp(color_scan.a + pulse, 0.1, 0.4))
			border_col = Color(color_scan.r, color_scan.g, color_scan.b, 0.8)
		CameraState.DETECTING:
			var detect_ratio = clamp(detection_progress, 0.0, 1.0)
			fill_col = color_detecting.lerp(color_alert, detect_ratio)
			border_col = Color(1.0, 0.8, 0.0, 0.9)
		CameraState.ALERT:
			var fast_pulse = (sin(anim_pulse_time * 12.0) + 1.0) * 0.5
			fill_col = Color(color_alert.r, color_alert.g, color_alert.b, 0.35 + 0.25 * fast_pulse)
			border_col = Color(1.0, 0.1, 0.2, 1.0)
		CameraState.HACKED:
			var glitch_pulse = 0.04 * sin(anim_pulse_time * 2.0)
			fill_col = Color(color_hacked.r, color_hacked.g, color_hacked.b, clamp(color_hacked.a + glitch_pulse, 0.08, 0.3))
			border_col = Color(color_hacked.r, color_hacked.g, color_hacked.b, 0.6)
			
	draw_colored_polygon(cached_cone_polygon, fill_col)
	
	var outline_points = cached_cone_polygon.duplicate()
	outline_points.append(cached_cone_polygon[0])
	draw_polyline(outline_points, border_col, 2.0, true)
	
	if show_range_grid and cached_cone_polygon.size() > 2:
		var half_range = vision_range * 0.5
		var center_dir = Vector2(cos(deg_to_rad(current_aim_angle_deg)), sin(deg_to_rad(current_aim_angle_deg)))
		
		draw_line(Vector2.ZERO, center_dir * (vision_range * 0.9), Color(border_col.r, border_col.g, border_col.b, 0.3), 1.0)
		
		if current_state != CameraState.HACKED:
			var arc_pts = PackedVector2Array()
			var half_fov = fov_deg / 2.0
			for i in range(11):
				var a = deg_to_rad(current_aim_angle_deg - half_fov + float(i) * (fov_deg / 10.0))
				arc_pts.append(Vector2(cos(a), sin(a)) * half_range)
			if arc_pts.size() > 1:
				draw_polyline(arc_pts, Color(border_col.r, border_col.g, border_col.b, 0.25), 1.0)
				
	if current_state == CameraState.ALERT:
		var alert_center = Vector2(cos(deg_to_rad(current_aim_angle_deg)), sin(deg_to_rad(current_aim_angle_deg))) * (vision_range * 0.4)
		var tri = PackedVector2Array([
			alert_center + Vector2(0, -18),
			alert_center + Vector2(15, 12),
			alert_center + Vector2(-15, 12)
		])
		draw_colored_polygon(tri, Color(1.0, 0.05, 0.2, 0.7))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 2.0)
		draw_line(alert_center + Vector2(0, -7), alert_center + Vector2(0, 3), Color.WHITE, 2.5)
		draw_circle(alert_center + Vector2(0, 7), 1.5, Color.WHITE)

func _draw_camera_mount() -> void:
	var base_rect = Rect2(-14, -14, 28, 8) if mount_on_ceiling else Rect2(-14, -6, 28, 8)
	draw_rect(base_rect, Color("#1a1e28"), true)
	draw_rect(base_rect, Color("#3a4454"), false, 1.5)
	
	draw_circle(Vector2(-10, -10), 1.5, Color("#8a93b0"))
	draw_circle(Vector2(10, -10), 1.5, Color("#8a93b0"))
	draw_line(Vector2(0, -6), Vector2(0, 0), Color("#2a3242"), 4.0)

func _draw_camera_head() -> void:
	var aim_rad = deg_to_rad(current_aim_angle_deg)
	var forward = Vector2(cos(aim_rad), sin(aim_rad))
	var right = Vector2(-forward.y, forward.x)
	
	draw_circle(Vector2.ZERO, 6.0, Color("#2a3242"))
	draw_circle(Vector2.ZERO, 6.0, Color("#4a566b"), false, 1.0)
	
	var p_fwd_top = forward * 18.0 + right * 6.0
	var p_fwd_bot = forward * 18.0 - right * 6.0
	var p_back_bot = -forward * 8.0 - right * 8.0
	var p_back_top = -forward * 8.0 + right * 8.0
	
	var body_poly = PackedVector2Array([p_back_top, p_fwd_top, p_fwd_bot, p_back_bot])
	draw_colored_polygon(body_poly, Color("#121722"))
	draw_polyline(PackedVector2Array([p_back_top, p_fwd_top, p_fwd_bot, p_back_bot, p_back_top]), Color("#3b485d"), 1.5)
	
	var lens_center = forward * 19.0
	var lens_col: Color
	match current_state:
		CameraState.SCANNING:
			lens_col = Color("#ff4400")
		CameraState.DETECTING:
			lens_col = Color("#ffaa00")
		CameraState.ALERT:
			lens_col = Color("#ff0033")
		CameraState.HACKED:
			lens_col = Color("#00f0ff")
			
	draw_circle(lens_center, 4.0, Color("#0a0e14"))
	draw_circle(lens_center, 3.0, lens_col)
	draw_circle(lens_center + Vector2(-1, -1), 1.0, Color.WHITE)
	
	var led_pos = -forward * 4.0 + right * 7.0
	draw_circle(led_pos, 2.0, lens_col)




