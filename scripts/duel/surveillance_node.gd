class_name SurveillanceNode
extends Node2D
## Nodo de Vigilância da Axioma (WDD: pontos de interesse; GDD: Duelo). Só
## aceita hack quando é a vez dele (ACTIVE). Hack de nível 5 (x dos dois lados),
## sem Esc. Derrubado, fica verde e emite `broken`.

signal broken

enum State { IDLE, ACTIVE, BROKEN }

## Subtópico da equação do nível 5: 0 = x dos dois lados, 1 = com parênteses.
@export var sub_topic: int = 0

const CYAN := Color(0.0, 0.94, 1.0)
const GREEN := Color(0.22, 1.0, 0.08)
const GREY := Color(0.35, 0.4, 0.48)

var state: State = State.IDLE


func _ready() -> void:
	add_to_group("surveillance_node")
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.NODE
		h.difficulty_bonus = 1
		h.sub_topic_override = sub_topic
		h.abortable = false
		h.position = Vector2(0, -70)
		h.hacked.connect(_on_hacked)


func activate() -> void:
	if state == State.IDLE:
		state = State.ACTIVE
		queue_redraw()


func deactivate() -> void:
	if state == State.ACTIVE:
		state = State.IDLE
		queue_redraw()


func can_be_hacked() -> bool:
	return state == State.ACTIVE


func _on_hacked() -> void:
	state = State.BROKEN
	broken.emit()
	queue_redraw()


func _process(_delta: float) -> void:
	if state == State.ACTIVE:
		queue_redraw()


func _draw() -> void:
	var col := GREY
	if state == State.ACTIVE:
		col = CYAN.lerp(Color.WHITE, 0.25 + 0.25 * sin(Time.get_ticks_msec() / 150.0))
	elif state == State.BROKEN:
		col = GREEN
	# pedestal
	draw_rect(Rect2(-18, -10, 36, 10), Color(0.08, 0.1, 0.14))
	draw_rect(Rect2(-18, -10, 36, 10), Color(col, 0.6), false, 1.0)
	# cristal (losango) flutuando
	var y := -70.0 + (3.0 * sin(Time.get_ticks_msec() / 400.0) if state != State.BROKEN else 0.0)
	var pts := PackedVector2Array([Vector2(0, y - 34), Vector2(18, y), Vector2(0, y + 34), Vector2(-18, y)])
	draw_colored_polygon(pts, Color(col, 0.22))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, 2.0)
	if state == State.BROKEN:
		draw_line(Vector2(-10, y - 12), Vector2(8, y + 14), Color(0.02, 0.03, 0.05), 2.0)
	if state == State.ACTIVE:
		draw_arc(Vector2(0, y), 44.0, 0.0, TAU, 32, Color(col, 0.35), 2.0)
