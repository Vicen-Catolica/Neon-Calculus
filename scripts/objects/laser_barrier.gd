class_name LaserBarrier
extends Node2D
## Barreira a laser (Fase 3, GDD/WDD: "portas de segurança a laser"). Um feixe
## vertical do chão até o emissor no teto. Encostar no feixe ligado dispara o
## alarme e soma variância; não machuca (quem pega o Eduardo é o taser).
##
## Modos:
##   ALWAYS: sempre ligado; hackear desliga por `hack_off_time` s.
##   TIMED:  liga `on_time` s / desliga `off_time` s; hackear segura desligado
##           por `hack_off_time` s e depois o ciclo volta.
## Antes de religar, o feixe pisca por `warn_time` s (aviso).
##
## Origem = chão sob o feixe. Filhos: Hackable (no emissor) e Beam (Area2D).

const Supports := preload("res://scripts/core/supports.gd")

signal tripped(body: Node2D)
signal power_changed(on: bool)

enum Mode { ALWAYS, TIMED }

@export var mode: Mode = Mode.ALWAYS
## Do chão até o emissor do teto.
@export var height: float = 192.0
@export var on_time: float = 2.5
@export var off_time: float = 1.6
## Desloca o ciclo do TIMED (lasers vizinhos fora de sincronia).
@export var phase: float = 0.0
@export var hack_off_time: float = 8.0
@export var warn_time: float = 1.5
@export var variance_on_touch: float = 20.0

const RED := Color(1.0, 0.16, 0.24)
const OFF := Color(0.5, 0.55, 0.6, 0.35)
const TOUCH_COOLDOWN := 2.0

var _hack_left: float = 0.0
var _cycle: float = 0.0
var _touch_cooldown: float = 0.0
var _was_on: bool = true
var _beam: Area2D


func _ready() -> void:
	add_to_group("laser")
	_cycle = phase
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.LASER
		h.position = Vector2(0, -height + 10.0)  # no emissor do teto
		h.hacked.connect(_on_hacked)
	_beam = get_node_or_null("Beam") as Area2D
	if _beam:
		var cs := _beam.get_node("Shape") as CollisionShape2D
		var r := RectangleShape2D.new()
		r.size = Vector2(8, height - 8.0)
		cs.shape = r
		cs.position = Vector2(0, -height / 2.0)
	_was_on = is_on()
	queue_redraw()
	_add_support.call_deferred()


## Emissor do alto sem teto em cima: haste até o teto.
func _add_support() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var top := global_position + Vector2(0, -height)
	var up = Supports.hit(self, top + Vector2(0, -2), top + Vector2(0, -420))
	if up != null and top.y - (up as Vector2).y > 3.0:
		Supports.pole(self, top + Vector2(0, -4), up, 4.0, "EmitterPole")


## Feixe ligado agora (perigoso).
func is_on() -> bool:
	if _hack_left > 0.0:
		return false
	if mode == Mode.TIMED:
		return fmod(_cycle, on_time + off_time) < on_time
	return true


func is_hacked() -> bool:
	return _hack_left > 0.0


## Piscando: hack acabando, ou (TIMED) prestes a religar.
func is_warning() -> bool:
	if _hack_left > 0.0:
		return _hack_left <= warn_time
	if mode == Mode.TIMED and not is_on():
		return on_time + off_time - fmod(_cycle, on_time + off_time) <= minf(warn_time, off_time) * 0.5
	return false


func can_be_hacked() -> bool:
	return _hack_left <= 0.0


func _on_hacked() -> void:
	_hack_left = hack_off_time


func _process(delta: float) -> void:
	if _hack_left > 0.0:
		_hack_left = maxf(_hack_left - delta, 0.0)
	elif mode == Mode.TIMED:
		_cycle += delta
	_touch_cooldown = maxf(_touch_cooldown - delta, 0.0)
	var on := is_on()
	if on != _was_on:
		_was_on = on
		power_changed.emit(on)
	if on and _beam and _touch_cooldown <= 0.0:
		for b in _beam.get_overlapping_bodies():
			if b.is_in_group("Player") and not b.get("is_dead"):
				_trip(b)
				break
	queue_redraw()


func _trip(body: Node2D) -> void:
	_touch_cooldown = TOUCH_COOLDOWN
	GameManager.add_variance(variance_on_touch)
	GameManager.raise_alarm(body.global_position)
	get_tree().call_group("stealth_hud", "_flash", "LASER CRUZADO — ALARME", RED)
	tripped.emit(body)


func _draw() -> void:
	var top := -height
	# Emissores (teto e chão).
	for y in [top, -6.0]:
		draw_rect(Rect2(-9, y, 18, 6), Color(0.08, 0.09, 0.11))
		draw_rect(Rect2(-9, y, 18, 6), Color(0.05, 0.04, 0.04), false, 1.0)
	var lamp := RED if is_on() else (Color(0.0, 0.94, 1.0) if is_hacked() else Color(0.6, 0.15, 0.15))
	draw_rect(Rect2(-3, top + 6, 6, 3), lamp)
	draw_rect(Rect2(-3, -9, 6, 3), lamp)
	var a := Vector2(0, top + 9)
	var b := Vector2(0, -9)
	if is_on():
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 70.0)
		draw_line(a, b, Color(RED, 0.18 * pulse), 12.0)
		draw_line(a, b, Color(RED, 0.9 * pulse), 3.0)
		draw_line(a, b, Color(1, 0.85, 0.85, pulse), 1.0)
	elif is_warning() and int(Time.get_ticks_msec() / 90) % 2 == 0:
		draw_line(a, b, Color(RED, 0.45), 2.0)
	else:
		# desligado: pontilhado fraco marcando onde o feixe passa
		var y := a.y
		while y < b.y:
			draw_line(Vector2(0, y), Vector2(0, minf(y + 4.0, b.y)), OFF, 1.0)
			y += 12.0


func hack_time_left() -> float:
	return _hack_left / maxf(hack_off_time, 0.01)
