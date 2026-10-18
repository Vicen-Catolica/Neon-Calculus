class_name RoutineSweep
extends Node2D
## "Varredura de Rotina" da Axioma (WDD): quando a variância estoura, um feixe de
## laser vertical varre a área em volta do jogador. Encostar no feixe dispara o
## alarme. Esconder-se não protege — é preciso se mover/subir para fugir dele.
## Depois da varredura a variância cai pela metade.

@export var half_width: float = 520.0
@export var height: float = 900.0
@export var speed: float = 260.0
@export var warning_time: float = 1.2

var _active: bool = false
var _x: float = 0.0
var _end_x: float = 0.0
var _dir: float = 1.0
var _warn: float = 0.0
var _hit_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("routine_sweep")
	z_index = 20
	GameManager.sweep_triggered.connect(start)


func start() -> void:
	if _active:
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	_dir = 1.0 if randf() < 0.5 else -1.0
	global_position = Vector2(player.global_position.x, player.global_position.y)
	_x = -half_width * _dir
	_end_x = half_width * _dir
	_warn = warning_time
	_active = true


func is_active() -> bool:
	return _active


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if _warn > 0.0:
		_warn -= delta
	else:
		_x += _dir * speed * delta
		_check_hit()
		if (_dir > 0.0 and _x >= _end_x) or (_dir < 0.0 and _x <= _end_x):
			_active = false
			GameManager.add_variance(-GameManager.variance * 0.5)
	queue_redraw()


func _check_hit() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null or _hit_cooldown > 0.0:
		return
	var beam_x := global_position.x + _x
	var top := global_position.y - height * 0.7
	var bottom := global_position.y + height * 0.3
	if absf(player.global_position.x - beam_x) < 10.0 and player.global_position.y > top and player.global_position.y < bottom:
		_hit_cooldown = 3.0
		GameManager.raise_alarm(player.global_position)


func _draw() -> void:
	if not _active:
		return
	var top := -height * 0.7
	var bottom := height * 0.3
	if _warn > 0.0:
		# Aviso: linha tracejada onde o feixe vai começar.
		var a := 0.3 + 0.5 * absf(sin(Time.get_ticks_msec() / 90.0))
		draw_dashed_line(Vector2(_x, top), Vector2(_x, bottom), Color(1.0, 0.3, 0.2, a), 2.0, 12.0)
		return
	draw_rect(Rect2(_x - 6, top, 12, bottom - top), Color(1.0, 0.15, 0.15, 0.18))
	draw_line(Vector2(_x, top), Vector2(_x, bottom), Color(1.0, 0.35, 0.3, 0.95), 3.0)
