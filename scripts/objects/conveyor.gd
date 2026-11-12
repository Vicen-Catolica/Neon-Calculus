class_name Conveyor
extends StaticBody2D
## Esteira (Fase 2). Quem pisa nela é arrastado a `speed` px/s (negativo =
## para a esquerda): o CharacterBody2D herda a velocidade do chão pelo
## constant_linear_velocity. Hackear para a esteira por `stop_time` segundos.
##
## Origem = centro da superfície da esteira (onde se pisa). Arte provisória
## desenhada em código (greybox).

signal running_changed(running: bool)

@export var width: float = 400.0
@export var speed: float = -140.0
@export var stop_time: float = 10.0
## Espessura desenhada/colidida da esteira, para baixo da superfície.
@export var thickness: float = 10.0

const BELT := Color(0.16, 0.14, 0.13)
const BELT_DARK := Color(0.05, 0.04, 0.04)
const STRIPE := Color(0.36, 0.3, 0.22)
const ROLLER := Color(0.3, 0.26, 0.24)
const LIGHT_ON := Color(1.0, 0.45, 0.12)
const LIGHT_OFF := Color(0.0, 0.94, 1.0)
const STRIPE_GAP := 16.0

var running: bool = true
var _stop_left: float = 0.0
var _scroll: float = 0.0


func _ready() -> void:
	add_to_group("conveyor")
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var r := RectangleShape2D.new()
	r.size = Vector2(width, thickness)
	shape.shape = r
	shape.position = Vector2(0, thickness / 2.0)
	add_child(shape)
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.CONVEYOR
		h.ignore_body = self
		h.hacked.connect(stop)
	_apply()


func can_be_hacked() -> bool:
	return running


func stop() -> void:
	running = false
	_stop_left = stop_time
	_apply()


func start() -> void:
	running = true
	_apply()


func _apply() -> void:
	constant_linear_velocity = Vector2(speed if running else 0.0, 0.0)
	running_changed.emit(running)
	queue_redraw()


func _process(delta: float) -> void:
	if running:
		_scroll = fposmod(_scroll + speed * delta, STRIPE_GAP)
		queue_redraw()
	else:
		_stop_left -= delta
		if _stop_left <= 0.0:
			start()


func _draw() -> void:
	var half := width / 2.0
	# rolos nas pontas e no meio
	var n := int(width / 64.0)
	for i in n + 1:
		var x := -half + 8.0 + (width - 16.0) * float(i) / float(maxi(n, 1))
		draw_rect(Rect2(x - 7, thickness - 2, 14, 10), BELT_DARK)
		draw_rect(Rect2(x - 5, thickness, 10, 6), ROLLER)
	# lona com faixas que andam no sentido da esteira
	draw_rect(Rect2(-half, -2, width, thickness + 4), BELT_DARK)
	draw_rect(Rect2(-half + 2, 0, width - 4, thickness), BELT)
	var x0 := -half + 2.0 + _scroll
	while x0 < half - 6.0:
		draw_rect(Rect2(x0, 2, 4, thickness - 4), STRIPE)
		x0 += STRIPE_GAP
	# luz de estado na ponta: laranja rodando, ciano parada (hackeada)
	var lc := LIGHT_ON if running else LIGHT_OFF
	draw_rect(Rect2(-half - 10, -14, 8, 8), BELT_DARK)
	draw_rect(Rect2(-half - 9, -13, 6, 6), lc)
	draw_rect(Rect2(half + 2, -14, 8, 8), BELT_DARK)
	draw_rect(Rect2(half + 3, -13, 6, 6), lc)
