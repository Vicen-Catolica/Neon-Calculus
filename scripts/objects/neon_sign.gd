class_name NeonSign
extends Sprite2D
## Letreiro neon. A textura "_flicker_2f" tem 2 quadros lado a lado
## (aceso / apagado) e hframes = 2.
## Filhos opcionais:
##  - Hackable: hackear apaga o letreiro por `off_time` segundos (0 = para sempre).
##  - LightZone (Area2D): enquanto aceso, o jogador dentro dela fica exposto
##    (não consegue se esconder).

signal power_changed(powered: bool)

@export var flicker: bool = true
@export var min_wait: float = 1.5
@export var max_wait: float = 5.0
@export var off_time: float = 25.0

var powered: bool = true : set = set_powered
var _timer: float = 0.0
var _off_timer: float = 0.0
var _light: Area2D


func _ready() -> void:
	add_to_group("neon")
	_timer = randf_range(min_wait, max_wait)
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.LIGHT
		h.hacked.connect(_on_hacked)
	_light = get_node_or_null("LightZone") as Area2D
	if _light:
		_light.body_entered.connect(_on_light_body_entered)
		_light.body_exited.connect(_on_light_body_exited)


func can_be_hacked() -> bool:
	return powered


func _process(delta: float) -> void:
	if not powered:
		if off_time > 0.0:
			_off_timer -= delta
			if _off_timer <= 0.0:
				set_powered(true)
		return
	if not flicker or hframes < 2:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	# Pisca rápido (apagado por um instante) e volta.
	frame = 1 if frame == 0 else 0
	_timer = randf_range(0.04, 0.12) if frame == 1 else randf_range(min_wait, max_wait)


func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	frame = 0 if value else (1 if hframes > 1 else 0)
	modulate = Color.WHITE if value else Color(0.25, 0.25, 0.3)
	if _light:
		_light.set_deferred("monitoring", value)
		if not value:
			for b in _light.get_overlapping_bodies():
				_on_light_body_exited(b)
	power_changed.emit(value)


func _on_hacked() -> void:
	_off_timer = off_time
	set_powered(false)


func _on_light_body_entered(body: Node2D) -> void:
	if powered and body.has_method("enter_light"):
		body.enter_light(self)


func _on_light_body_exited(body: Node2D) -> void:
	if body.has_method("exit_light"):
		body.exit_light(self)
