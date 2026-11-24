class_name PatrolDrone
extends Node2D
## Drone de patrulha da Axioma (Fase 2, WDD: "pombos foram substituídos por
## drones"). Voa entre dois pontos com o sensor apontado para baixo e para a
## frente. Não ataca: se o jogador ficar exposto ao cone por `exposure_to_alarm`
## segundos, dispara o alarme (os guardas próximos vêm e a variância sobe).
## Hackear reinicia o drone: fica parado e cego por `reboot_time` segundos.
##
## Sem colisão (passa por cima de tudo). Arte provisória desenhada em código.

enum Mode { PATROL, ALERT, REBOOT }

## Pontos de patrulha, em coordenadas globais (o drone vai e volta entre eles).
@export var point_a: Vector2 = Vector2.ZERO
@export var point_b: Vector2 = Vector2(400, 0)
@export var speed: float = 70.0
@export var end_pause: float = 1.2
@export var vision_range: float = 260.0
@export var fov_deg: float = 50.0
## Ângulo do sensor abaixo da horizontal, no sentido em que o drone voa.
@export var sensor_tilt_deg: float = 55.0
@export var exposure_to_alarm: float = 1.2
@export var reboot_time: float = 8.0
@export var world_mask: int = 1

## Sprites (PixelLab, ver tools/gen_industrial_art.py): só a cor do olho muda.
const TEX_PATROL: Texture2D = preload("res://assets/enemies/drone/drone_patrol.png")
const TEX_ALERT: Texture2D = preload("res://assets/enemies/drone/drone_alert.png")
const TEX_REBOOT: Texture2D = preload("res://assets/enemies/drone/drone_reboot.png")
## Olho no sprite (olhando para a direita), relativo ao centro.
const EYE := Vector2(9, 5)

var mode: Mode = Mode.PATROL
var facing: float = 1.0
var _target_b: bool = true
var _pause: float = 0.0
var _exposure: float = 0.0
var _lost: float = 0.0
var _reboot_left: float = 0.0
var _alarm_cooldown: float = 0.0
var _t: float = 0.0
var _cone := PackedVector2Array()


func _ready() -> void:
	add_to_group("drones")
	if point_a == Vector2.ZERO and point_b == Vector2(400, 0):
		point_a = global_position
		point_b = global_position + Vector2(400, 0)
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.DRONE
		h.hacked.connect(reboot)


func can_be_hacked() -> bool:
	return mode != Mode.REBOOT


func reboot() -> void:
	mode = Mode.REBOOT
	_reboot_left = reboot_time
	_exposure = 0.0
	_cone.clear()
	queue_redraw()


## Direção (graus) para onde o sensor aponta.
func sensor_deg() -> float:
	return sensor_tilt_deg if facing > 0.0 else 180.0 - sensor_tilt_deg


## Sensor relativo ao drone (espelha com a direção do voo).
func lens_local() -> Vector2:
	return Vector2(EYE.x * facing, EYE.y)


func lens_global() -> Vector2:
	return global_position + lens_local()


func _physics_process(delta: float) -> void:
	_t += delta
	_alarm_cooldown = maxf(_alarm_cooldown - delta, 0.0)
	match mode:
		Mode.PATROL:
			_fly(delta)
			if sees_player():
				mode = Mode.ALERT
				_exposure = 0.0
				_lost = 0.0
		Mode.ALERT:
			_do_alert(delta)
		Mode.REBOOT:
			_reboot_left -= delta
			if _reboot_left <= 0.0:
				mode = Mode.PATROL
	_update_cone()
	queue_redraw()


func _fly(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var target := point_b if _target_b else point_a
	var to := target - global_position
	if absf(to.x) > 1.0:
		facing = signf(to.x)
	var step := speed * delta
	if to.length() <= step:
		global_position = target
		_target_b = not _target_b
		_pause = end_pause
	else:
		global_position += to.normalized() * step


func _do_alert(delta: float) -> void:
	# Para no ar e encara o jogador enquanto a barra enche.
	var player := _player()
	if sees_player() and player:
		_lost = 0.0
		_exposure += delta
		if _exposure >= exposure_to_alarm and _alarm_cooldown <= 0.0:
			_alarm_cooldown = 4.0
			GameManager.raise_alarm(player.global_position)
	else:
		_lost += delta
		_exposure = maxf(_exposure - delta, 0.0)
		if _lost >= 1.5:
			mode = Mode.PATROL


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("Player") as Node2D


func sees_player() -> bool:
	if mode == Mode.REBOOT:
		return false
	var player := _player()
	if player == null or not player.has_method("get_aim_point"):
		return false
	if player.has_method("is_detectable") and not player.is_detectable():
		return false
	var origin := lens_global()
	var target: Vector2 = player.get_aim_point()
	var to := target - origin
	if to.length() > vision_range:
		return false
	if absf(wrapf(rad_to_deg(to.angle()) - sensor_deg(), -180.0, 180.0)) > fov_deg * 0.5:
		return false
	if VisionBlocker.line_blocked(get_tree(), origin, target):
		return false
	var q := PhysicsRayQueryParameters2D.create(origin, target, world_mask)
	if player is CollisionObject2D:
		q.exclude = [(player as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _update_cone() -> void:
	_cone.clear()
	if mode == Mode.REBOOT:
		return
	var g_origin := lens_global()
	_cone.append(lens_local())
	var space := get_world_2d().direct_space_state
	var player := _player()
	var steps := 8
	for i in steps + 1:
		var a := deg_to_rad(sensor_deg() - fov_deg * 0.5 + fov_deg * float(i) / float(steps))
		var end := g_origin + Vector2.from_angle(a) * vision_range
		var q := PhysicsRayQueryParameters2D.create(g_origin, end, world_mask)
		if player is CollisionObject2D:
			q.exclude = [(player as CollisionObject2D).get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			end = hit["position"]
		end = VisionBlocker.clip(get_tree(), g_origin, end)
		_cone.append(end - global_position)


func _draw() -> void:
	if _cone.size() >= 3:
		var col := Color(1.0, 0.45, 0.15, 0.12) if mode == Mode.PATROL else Color(1.0, 0.1, 0.12, 0.26)
		draw_colored_polygon(_cone, col)
	# flutua; no reboot desce um pouco e fica parado
	var bob := 0.0 if mode == Mode.REBOOT else roundf(sin(_t * 5.0) * 2.0)
	var o := Vector2(0, bob + (6.0 if mode == Mode.REBOOT else 0.0))
	var tex := TEX_PATROL
	if mode == Mode.ALERT:
		tex = TEX_ALERT if fmod(_t, 0.3) < 0.18 else TEX_PATROL
	elif mode == Mode.REBOOT:
		tex = TEX_REBOOT if fmod(_t, 0.8) < 0.4 else TEX_PATROL
	var size := tex.get_size()
	draw_set_transform(o, 0.0, Vector2(facing, 1.0))
	draw_texture(tex, -size / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_exposure_bar(o)


func _draw_exposure_bar(o: Vector2) -> void:
	if mode != Mode.ALERT or _exposure <= 0.0:
		return
	var ratio := clampf(_exposure / exposure_to_alarm, 0.0, 1.0)
	var pos := o + Vector2(-15, -32)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(32, 6)), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(pos, Vector2(30 * ratio, 4)), Color(1.0, 0.8, 0.15).lerp(Color(1.0, 0.1, 0.25), ratio))
