class_name SonarPing
extends Node2D
## Ping Sonar (GDD §3 e §4, tecla V): pulso tático que revela, através das
## paredes, a posição e o cone de visão de guardas, Unidades Lógicas, drones e
## câmeras num raio, e marca os nós eletrônicos (alvos hackeáveis). Inimigos
## revelados fora da tela viram setas na borda. Recarrega com o tempo; o
## indicador fica no canto inferior esquerdo ("Módulos do Traje", GDD §8).
##
## Filho do Eduardo. Desenha em coordenadas do mundo (top_level) por cima do
## cenário (z_index alto).

signal pinged(revealed_count: int)

const RADIUS := 900.0
const WAVE_TIME := 0.6
const REVEAL_TIME := 5.0
const COOLDOWN := 12.0
const RED := Color(1.0, 0.2, 0.25)
const CYAN := Color(0.0, 0.94, 1.0)

var cooldown_left: float = 0.0
var reveal_left: float = 0.0
## Inimigos (guardas, drones, câmeras) e alvos hackeáveis revelados no último ping.
var revealed: Array[Node2D] = []
var nodes: Array[Hackable] = []

var _origin: Vector2
var _wave_t: float = 99.0
var _ui: CanvasLayer
var _arrows: Control
var _bar: ColorRect
var _label: Label


func _ready() -> void:
	top_level = true
	z_index = 60
	global_position = Vector2.ZERO
	_build_ui()


func ready_to_ping() -> bool:
	return cooldown_left <= 0.0


func can_ping() -> bool:
	if not ready_to_ping() or get_tree().paused:
		return false
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.HACK_VISION:
		return false
	var p := get_parent()
	return p != null and not p.get("is_dead")


func ping() -> bool:
	if not can_ping():
		return false
	_origin = (get_parent() as Node2D).global_position + Vector2(0, -60)
	revealed.clear()
	nodes.clear()
	for group in ["guards", "drones", "security_camera"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node2D and (n as Node2D).global_position.distance_to(_origin) <= RADIUS:
				revealed.append(n)
	for h in get_tree().get_nodes_in_group("hackable"):
		if h is Hackable and h.global_position.distance_to(_origin) <= RADIUS and h.can_be_hacked():
			nodes.append(h)
	reveal_left = REVEAL_TIME
	cooldown_left = COOLDOWN
	_wave_t = 0.0
	get_tree().call_group("stealth_hud", "_flash", "PING SONAR: %d AMEAÇA(S)" % revealed.size(), CYAN)
	pinged.emit(revealed.size())
	return true


## Revelados cuja posição na tela fica fora de `screen` (viram setas na borda).
func offscreen_in(screen: Rect2) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var xf := get_viewport().get_canvas_transform()
	for n in revealed:
		if is_instance_valid(n) and not screen.has_point(xf * n.global_position):
			out.append(n)
	return out


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("sonar_ping"):
		ping()
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if reveal_left > 0.0:
		reveal_left = maxf(reveal_left - delta, 0.0)
		if reveal_left == 0.0:
			revealed.clear()
			nodes.clear()
	_wave_t += delta
	queue_redraw()
	_arrows.queue_redraw()
	_bar.size.x = 160.0 * (1.0 - cooldown_left / COOLDOWN)
	_bar.color = CYAN if ready_to_ping() else Color(CYAN, 0.45)
	_label.text = "SONAR [V]  " + ("PRONTO" if ready_to_ping() else "%d s" % ceili(cooldown_left))


func _draw() -> void:
	if _wave_t < WAVE_TIME:
		var k := _wave_t / WAVE_TIME
		draw_arc(_origin, RADIUS * k, 0.0, TAU, 96, Color(CYAN, 0.7 * (1.0 - k)), 3.0)
		draw_arc(_origin, RADIUS * k * 0.92, 0.0, TAU, 96, Color(CYAN, 0.25 * (1.0 - k)), 1.0)
	if reveal_left <= 0.0:
		return
	var a := clampf(reveal_left, 0.0, 1.0)
	for n in revealed:
		if not is_instance_valid(n):
			continue
		var cone := _cone_of(n)
		if cone.size() > 2:
			var closed := cone.duplicate()
			closed.append(cone[0])
			draw_polyline(closed, Color(RED, 0.75 * a), 1.5)
			draw_colored_polygon(cone, Color(RED, 0.08 * a))
		_brackets(n.global_position + Vector2(0, -60), Vector2(46, 128), Color(RED, a))
	for h in nodes:
		if not is_instance_valid(h):
			continue
		var c := h.global_position
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]),
			Color(CYAN, 0.8 * a))


## Cone de visão completo (sem recorte das paredes: o sonar vê através delas).
func _cone_of(n: Node2D) -> PackedVector2Array:
	var origin: Vector2
	var center_deg: float
	var fov: float
	var reach: float
	if n is Enemy:
		var e := n as Enemy
		if e.is_blind() or e._current_state_name() in ["distracted", "stunned"]:
			return PackedVector2Array()
		origin = e.global_position + e.eye_offset
		center_deg = rad_to_deg(e.get_facing_direction().angle())
		fov = e.vision_angle_deg
		reach = e.vision_range
	elif n is PatrolDrone:
		var d := n as PatrolDrone
		origin = d.lens_global()
		center_deg = d.sensor_deg()
		fov = d.fov_deg
		reach = d.vision_range
	elif n is SecurityCamera:
		var c := n as SecurityCamera
		if not c.can_be_hacked():
			return PackedVector2Array()  # hackeada/desligada
		origin = c.global_position + c.lens_local()
		center_deg = c.aim_deg
		fov = c.fov_deg
		reach = c.vision_range
	else:
		return PackedVector2Array()
	var pts := PackedVector2Array([origin])
	for i in 9:
		var ang := deg_to_rad(center_deg - fov * 0.5 + fov * float(i) / 8.0)
		pts.append(origin + Vector2.from_angle(ang) * reach)
	return pts


func _brackets(center: Vector2, size: Vector2, col: Color) -> void:
	var h := size / 2.0
	var l := 10.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := center + Vector2(h.x * sx, h.y * sy)
			draw_line(corner, corner - Vector2(l * sx, 0), col, 2.0)
			draw_line(corner, corner - Vector2(0, l * sy), col, 2.0)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_arrows = Control.new()
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	_ui.add_child(_arrows)
	var font: Font = load("res://assets/fonts/ui_font.tres")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.05, 0.08, 0.8)
	bg.position = Vector2(28, 1020)
	bg.size = Vector2(160, 8)
	_ui.add_child(bg)
	_bar = ColorRect.new()
	_bar.position = bg.position
	_bar.size = bg.size
	_ui.add_child(_bar)
	_label = Label.new()
	_label.position = Vector2(28, 992)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", CYAN)
	_ui.add_child(_label)


## Setas na borda da tela para ameaças reveladas fora dela.
func _draw_arrows() -> void:
	if reveal_left <= 0.0:
		return
	var screen := Rect2(Vector2.ZERO, _arrows.size)
	var inner := screen.grow(-40.0)
	var center := screen.get_center()
	var xf := get_viewport().get_canvas_transform()
	var a := clampf(reveal_left, 0.0, 1.0)
	for n in offscreen_in(screen):
		var sp := xf * n.global_position
		var dir := (sp - center).normalized()
		var p := Vector2(clampf(sp.x, inner.position.x, inner.end.x), clampf(sp.y, inner.position.y, inner.end.y))
		var side := dir.orthogonal() * 10.0
		_arrows.draw_colored_polygon(PackedVector2Array([p + dir * 16.0, p - dir * 8.0 + side, p - dir * 8.0 - side]),
			Color(RED, 0.9 * a))
