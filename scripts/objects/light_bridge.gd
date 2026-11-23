class_name LightBridge
extends Node2D
## Ponte de luz (Fase 4, GDD §6: "pontes de luz" no Núcleo). Plataforma de mão
## única que só existe quando ligada. O emissor fica na ponta esquerda.
##
## Modos:
##   HACK:  apagada; hackear o emissor materializa a ponte por `solid_time` s.
##   TIMED: liga `on_time` s / desliga `off_time` s; hackear segura ligada por
##          `solid_time` s e depois o ciclo volta.
## Antes de sumir, a ponte pisca por `warn_time` s.
##
## Origem = ponta esquerda, na altura da superfície. Filhos: Hackable (emissor)
## e Body (StaticBody2D com Shape, mão única).

signal solid_changed(solid: bool)

enum Mode { HACK, TIMED }

@export var mode: Mode = Mode.HACK
@export var width: float = 224.0
@export var solid_time: float = 10.0
@export var on_time: float = 3.0
@export var off_time: float = 2.0
@export var phase: float = 0.0
@export var warn_time: float = 1.5

const CYAN := Color(0.0, 0.94, 1.0)
const THICK := 8.0

var _hold_left: float = 0.0
var _cycle: float = 0.0
var _was_solid: bool = false
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("light_bridge")
	_cycle = phase
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.BRIDGE
		h.position = Vector2(6, -18)  # emissor
		h.hacked.connect(_on_hacked)
	var body := get_node_or_null("Body") as StaticBody2D
	if body:
		_shape = body.get_node("Shape") as CollisionShape2D
		var r := RectangleShape2D.new()
		r.size = Vector2(width, THICK)
		_shape.shape = r
		_shape.position = Vector2(width / 2.0, THICK / 2.0)
		_shape.one_way_collision = true
	_was_solid = is_solid()
	_apply()


func is_solid() -> bool:
	if _hold_left > 0.0:
		return true
	if mode == Mode.TIMED:
		return fmod(_cycle, on_time + off_time) < on_time
	return false


## Piscando: vai sumir em breve.
func is_warning() -> bool:
	if _hold_left > 0.0:
		return _hold_left <= warn_time
	if mode == Mode.TIMED and is_solid():
		return on_time - fmod(_cycle, on_time + off_time) <= minf(warn_time, on_time) * 0.5
	return false


func can_be_hacked() -> bool:
	return _hold_left <= 0.0


func _on_hacked() -> void:
	_hold_left = solid_time


func _process(delta: float) -> void:
	if _hold_left > 0.0:
		_hold_left = maxf(_hold_left - delta, 0.0)
	elif mode == Mode.TIMED:
		_cycle += delta
	var s := is_solid()
	if s != _was_solid:
		_was_solid = s
		_apply()
		solid_changed.emit(s)
	queue_redraw()


func _apply() -> void:
	if _shape:
		_shape.set_deferred("disabled", not is_solid())


func _draw() -> void:
	# Emissores nas pontas.
	for x in [0.0, width]:
		draw_rect(Rect2(x - 6, -6, 12, 14), Color(0.08, 0.1, 0.14))
		draw_rect(Rect2(x - 3, -3, 6, 4), CYAN if is_solid() else Color(0.3, 0.4, 0.45))
	if is_solid() and not (is_warning() and int(Time.get_ticks_msec() / 100) % 2 == 0):
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(Rect2(0, 0, width, THICK), Color(CYAN, 0.18 * pulse))
		draw_rect(Rect2(0, 0, width, 2), Color(CYAN, 0.95 * pulse))
		draw_rect(Rect2(0, THICK - 1, width, 1), Color(CYAN, 0.5 * pulse))
		var x := 8.0
		while x < width:
			draw_line(Vector2(x, 2), Vector2(x + 6, THICK - 1), Color(CYAN, 0.35 * pulse), 1.0)
			x += 16.0
	else:
		# Apagada: tracejado fraco marcando onde a ponte aparece.
		var x := 0.0
		while x < width:
			draw_line(Vector2(x, 1), Vector2(minf(x + 6.0, width), 1), Color(CYAN, 0.18), 1.0)
			x += 14.0


func hack_time_left() -> float:
	return _hold_left / maxf(solid_time, 0.01) if _hold_left > 0.0 else 0.0
