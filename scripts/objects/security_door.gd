class_name SecurityDoor
extends StaticBody2D
## Porta biométrica. Bloqueia a passagem até ser hackeada; então sobe e libera.
## Origem = base da porta (chão), centro horizontal.

signal opened

@export var start_open: bool = false

var is_open: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var hackable: Hackable = $Hackable

var _blink: float = 0.0


func _ready() -> void:
	add_to_group("door")
	hackable.kind = Hackable.Kind.DOOR
	hackable.ignore_body = self
	hackable.hacked.connect(open)
	if start_open:
		is_open = true
		sprite.frame = 6
		shape.set_deferred("disabled", true)


func can_be_hacked() -> bool:
	return not is_open


func _process(delta: float) -> void:
	if is_open:
		return
	_blink += delta
	sprite.frame = 0 if fmod(_blink, 1.0) < 0.6 else 1


func open() -> void:
	if is_open:
		return
	is_open = true
	var tw := create_tween()
	for f in [2, 3, 4, 5, 6]:
		tw.tween_callback(func(): sprite.frame = f)
		tw.tween_interval(0.09)
	tw.tween_callback(func():
		shape.set_deferred("disabled", true)
		opened.emit())
