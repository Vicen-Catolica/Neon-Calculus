class_name SteamValve
extends Node2D
## Válvula de vapor (Fase 2). Hackear abre a válvula: uma nuvem de vapor desce
## do bico por `steam_time` segundos e tapa a visão de guardas e câmeras
## (grupo "vision_blocker"). Dentro da nuvem o jogador também fica invisível.
## O jogador atravessa o vapor normalmente (não tem colisão).
##
## Origem = chão sob o bico. O cano desce do teto até `nozzle_height` acima do
## chão. Arte provisória desenhada em código (greybox).

signal steam_changed(active: bool)

@export var steam_time: float = 6.0
## Tempo depois que o vapor some até poder hackear de novo.
@export var cooldown: float = 3.0
## Área coberta pela nuvem, apoiada no chão e centrada no bico.
@export var cloud_size: Vector2 = Vector2(200, 170)
@export var nozzle_height: float = 210.0
@export var pipe_length: float = 600.0

const PIPE := Color(0.24, 0.21, 0.2)
const PIPE_DARK := Color(0.05, 0.04, 0.04)
const WHEEL_IDLE := Color(0.75, 0.2, 0.12)
const WHEEL_OPEN := Color(0.0, 0.94, 1.0)
const STEAM := Color(0.86, 0.86, 0.84, 0.55)

var active: bool = false
var _time_left: float = 0.0
var _cooldown_left: float = 0.0
var _particles: CPUParticles2D
var _haze: Polygon2D


func _ready() -> void:
	add_to_group(VisionBlocker.GROUP)
	add_to_group("valve")
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.VALVE
		h.position = Vector2(0, -nozzle_height - 46)  # no volante
		h.hacked.connect(open)
	_build_steam()
	queue_redraw()


func can_be_hacked() -> bool:
	return not active and _cooldown_left <= 0.0


func is_blocking() -> bool:
	return active


## Retângulo global coberto pelo vapor.
func get_block_rect() -> Rect2:
	return Rect2(global_position + Vector2(-cloud_size.x / 2.0, -cloud_size.y), cloud_size)


func open() -> void:
	active = true
	_time_left = steam_time
	_particles.emitting = true
	_haze.visible = true
	steam_changed.emit(true)
	queue_redraw()


func close() -> void:
	active = false
	_cooldown_left = cooldown
	_particles.emitting = false
	_haze.visible = false
	steam_changed.emit(false)
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		_time_left -= delta
		# a névoa afina no último segundo, avisando que vai acabar
		_haze.color.a = 0.32 * clampf(_time_left, 0.0, 1.0)
		if _time_left <= 0.0:
			close()
	elif _cooldown_left > 0.0:
		_cooldown_left -= delta


func _build_steam() -> void:
	_haze = Polygon2D.new()
	_haze.name = "Haze"
	var w := cloud_size.x / 2.0
	var hgt := cloud_size.y
	# leque: estreito no bico, largo no chão
	_haze.polygon = PackedVector2Array([
		Vector2(-18, -nozzle_height), Vector2(18, -nozzle_height),
		Vector2(w, -hgt * 0.35), Vector2(w, 0), Vector2(-w, 0), Vector2(-w, -hgt * 0.35),
	])
	_haze.color = Color(STEAM, 0.32)
	_haze.visible = false
	add_child(_haze)

	_particles = CPUParticles2D.new()
	_particles.name = "Steam"
	_particles.emitting = false
	_particles.amount = 70
	_particles.lifetime = 1.4
	_particles.position = Vector2(0, -nozzle_height + 8)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(10, 4)
	_particles.direction = Vector2(0, 1)
	_particles.spread = 38.0
	_particles.gravity = Vector2(0, 40)
	_particles.initial_velocity_min = 90.0
	_particles.initial_velocity_max = 170.0
	_particles.damping_min = 40.0
	_particles.damping_max = 70.0
	_particles.scale_amount_min = 8.0
	_particles.scale_amount_max = 18.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	_particles.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(STEAM, 0.7))
	fade.set_color(1, Color(STEAM, 0.0))
	_particles.color_ramp = fade
	add_child(_particles)


func _draw() -> void:
	var top := -nozzle_height - pipe_length
	# cano vertical vindo do teto, com contorno escuro
	draw_rect(Rect2(-9, top, 18, pipe_length), PIPE_DARK)
	draw_rect(Rect2(-7, top, 14, pipe_length), PIPE)
	# bico
	draw_rect(Rect2(-13, -nozzle_height - 6, 26, 10), PIPE_DARK)
	draw_rect(Rect2(-11, -nozzle_height - 4, 22, 6), PIPE)
	# volante da válvula, ao lado do cano
	var c := Vector2(0, -nozzle_height - 46)
	var wheel := WHEEL_OPEN if active else WHEEL_IDLE
	draw_rect(Rect2(c.x - 13, c.y - 13, 26, 26), PIPE_DARK)
	draw_rect(Rect2(c.x - 11, c.y - 11, 22, 22), wheel)
	draw_rect(Rect2(c.x - 7, c.y - 7, 14, 14), PIPE_DARK)
	draw_rect(Rect2(c.x - 2, c.y - 11, 4, 22), wheel)
	draw_rect(Rect2(c.x - 11, c.y - 2, 22, 4), wheel)
