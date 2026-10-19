class_name AxiomaKiosk
extends Node2D
## Quiosque público da Axioma (propaganda). Hackeado, dispara um alarme sonoro
## por alguns segundos: guardas humanos num raio vão investigar o quiosque.
## Origem = base do quiosque (chão).

@export var lure_radius: float = 700.0
@export var alarm_time: float = 6.0
@export var cooldown_time: float = 20.0

var _alarm: float = 0.0
var _cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hackable: Hackable = $Hackable


func _ready() -> void:
	add_to_group("kiosk")
	hackable.kind = Hackable.Kind.KIOSK
	hackable.hacked.connect(_on_hacked)
	sprite.play(&"locked")


func can_be_hacked() -> bool:
	return _alarm <= 0.0 and _cooldown <= 0.0


func _process(delta: float) -> void:
	if _alarm > 0.0:
		_alarm -= delta
		queue_redraw()
		if _alarm <= 0.0:
			sprite.play(&"locked")
			_cooldown = cooldown_time
	elif _cooldown > 0.0:
		_cooldown -= delta


func _on_hacked() -> void:
	_alarm = alarm_time
	sprite.play(&"hacking")
	var lure_point := global_position + Vector2(0, -8)
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("investigate") and g.global_position.distance_to(lure_point) <= lure_radius:
			g.investigate(lure_point)


func _draw() -> void:
	if _alarm <= 0.0:
		return
	# Ondas sonoras saindo da tela do quiosque.
	var t := alarm_time - _alarm
	var c := Vector2(0, -64)
	for i in 3:
		var r := fmod(t * 90.0 + i * 40.0, 120.0) + 10.0
		var a := clampf(1.0 - r / 130.0, 0.0, 1.0) * 0.7
		draw_arc(c, r, -PI * 0.9, -PI * 0.1, 24, Color(1.0, 0.3, 0.25, a), 2.0)
