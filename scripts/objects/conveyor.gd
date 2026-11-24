class_name Conveyor
extends StaticBody2D
## Esteira (Fase 2). Quem pisa nela é arrastado a `speed` px/s (negativo =
## para a esquerda): o CharacterBody2D herda a velocidade do chão pelo
## constant_linear_velocity. Hackear para a esteira por `stop_time` segundos.
##
## Origem = centro da superfície da esteira (onde se pisa). Arte do PixelLab
## (tools/gen_industrial_art.py): pontas fixas + trecho do meio que se repete e
## "anda" no sentido da esteira.

signal running_changed(running: bool)

@export var width: float = 400.0
@export var speed: float = -140.0
@export var stop_time: float = 10.0
## Espessura desenhada/colidida da esteira, para baixo da superfície.
@export var thickness: float = 10.0

const BELT_DARK := Color(0.05, 0.04, 0.04)
const LIGHT_ON := Color(1.0, 0.45, 0.12)
const LIGHT_OFF := Color(0.0, 0.94, 1.0)
const TEX_LEFT: Texture2D = preload("res://assets/objects/conveyor/conveyor_left.png")
const TEX_MID: Texture2D = preload("res://assets/objects/conveyor/conveyor_mid.png")
const TEX_RIGHT: Texture2D = preload("res://assets/objects/conveyor/conveyor_right.png")
## As garras da lona ficam um pouco acima da superfície de colisão.
const SPRITE_TOP := -3.0

var running: bool = true
var _stop_left: float = 0.0
var _scroll: float = 0.0


func _ready() -> void:
	add_to_group("conveyor")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
		_scroll = fposmod(_scroll + speed * delta, TEX_MID.get_width())
		queue_redraw()
	else:
		_stop_left -= delta
		if _stop_left <= 0.0:
			start()


func _draw() -> void:
	var half := width / 2.0
	var cap := TEX_LEFT.get_width()
	var h := TEX_MID.get_height()
	var mid_w := width - cap * 2.0
	draw_texture(TEX_LEFT, Vector2(-half, SPRITE_TOP))
	draw_texture(TEX_RIGHT, Vector2(half - cap, SPRITE_TOP))
	draw_texture_rect_region(TEX_MID, Rect2(-half + cap, SPRITE_TOP, mid_w, h),
		Rect2(-_scroll, 0, mid_w, h))
	# luz de estado nas pontas: laranja rodando, ciano parada (hackeada)
	var lc := LIGHT_ON if running else LIGHT_OFF
	draw_rect(Rect2(-half - 10, -14, 8, 8), BELT_DARK)
	draw_rect(Rect2(-half - 9, -13, 6, 6), lc)
	draw_rect(Rect2(half + 2, -14, 8, 8), BELT_DARK)
	draw_rect(Rect2(half + 3, -13, 6, 6), lc)
