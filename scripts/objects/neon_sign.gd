class_name NeonSign
extends Sprite2D
## Letreiro neon. A textura "_flicker_2f" tem 2 quadros lado a lado
## (aceso / apagado) e hframes = 2. Hackeável no futuro: set_powered(false).

signal power_changed(powered: bool)

@export var flicker: bool = true
@export var min_wait: float = 1.5
@export var max_wait: float = 5.0

var powered: bool = true : set = set_powered
var _timer: float = 0.0


func _ready() -> void:
	add_to_group("neon")
	_timer = randf_range(min_wait, max_wait)


func _process(delta: float) -> void:
	if not powered or not flicker or hframes < 2:
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
	power_changed.emit(value)