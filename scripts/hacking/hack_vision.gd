class_name HackVision
extends Node
## Visão hacker (estilo Watch Dogs). Fica como filho do Eduardo.
## Segurar `hack_vision` desacelera o mundo e destaca os alvos (`Hackable`) ao
## alcance e com linha de visão. O alvo é o mais próximo do mouse (Tab troca).
## `hack_confirm` abre a HackingInterface; o resultado volta para o alvo.

signal target_changed(target: Hackable)

@export var vision_range: float = 520.0
@export var world_mask: int = 1
@export var tint: Color = Color(0.45, 0.6, 0.78)

const CYAN := Color(0.35, 0.95, 1.0)
const CYAN_DIM := Color(0.35, 0.95, 1.0, 0.35)
const RED := Color(1.0, 0.3, 0.25)

var active: bool = false
var candidates: Array[Hackable] = []
var target: Hackable = null

var _player: Node2D
var _layer: CanvasLayer
var _drawer: Node2D
var _modulate: CanvasModulate
var _hacking_ui: Node = null
var _cycle_index: int = -1
var _last_mouse: Vector2 = Vector2.ZERO
var _hacking_target: Hackable = null
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent() as Node2D
	_font = load("res://assets/fonts/Orbitron-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf") else ThemeDB.fallback_font
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.follow_viewport_enabled = true
	add_child(_layer)
	_drawer = Node2D.new()
	_drawer.draw.connect(_on_draw)
	_layer.add_child(_drawer)


func _process(_delta: float) -> void:
	if _hacking_target != null:
		return  # equação aberta
	var gm_state: int = GameManager.state
	if gm_state == GameManager.State.GAME_OVER or gm_state == GameManager.State.PAUSED or get_tree().paused:
		if active:
			_set_active(false)
		return
	var want: bool = Input.is_action_pressed("hack_vision") and not _player_busy()
	if want != active:
		_set_active(want)
	if active:
		_refresh_candidates()
		_pick_target()
		if target and Input.is_action_just_pressed("hack_confirm"):
			_start_hack(target)
	_drawer.queue_redraw()


func _player_busy() -> bool:
	return _player.get("is_dead") == true


func _set_active(on: bool) -> void:
	active = on
	if on:
		GameManager.set_state(GameManager.State.HACK_VISION)
		_ensure_modulate()
		_modulate.color = tint
		_modulate.visible = true
		_last_mouse = _drawer.get_global_mouse_position()
		_cycle_index = -1
	else:
		if GameManager.state == GameManager.State.HACK_VISION:
			GameManager.set_state(GameManager.State.PLAYING)
		if _modulate:
			_modulate.visible = false
		candidates.clear()
		_set_target(null)
	_drawer.queue_redraw()


func _ensure_modulate() -> void:
	if is_instance_valid(_modulate):
		return
	_modulate = CanvasModulate.new()
	_modulate.visible = false
	get_tree().current_scene.add_child(_modulate)


# --- Alvos ---------------------------------------------------------------

func eye_position() -> Vector2:
	if _player.has_method("get_aim_point"):
		return _player.get_aim_point() + Vector2(0, -24)
	return _player.global_position + Vector2(0, -100)


func _refresh_candidates() -> void:
	candidates.clear()
	var eye := eye_position()
	for node in get_tree().get_nodes_in_group("hackable"):
		var h := node as Hackable
		if h == null or not h.is_visible_in_tree() or not h.can_be_hacked():
			continue
		if eye.distance_to(h.global_position) > vision_range:
			continue
		if not _has_line_of_sight(eye, h):
			continue
		candidates.append(h)


func _has_line_of_sight(eye: Vector2, h: Hackable) -> bool:
	var space := _player.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(eye, h.global_position, world_mask)
	var exclude: Array[RID] = []
	if _player is CollisionObject2D:
		exclude.append((_player as CollisionObject2D).get_rid())
	if h.ignore_body:
		exclude.append(h.ignore_body.get_rid())
	q.exclude = exclude
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	# Bateu em um corpo do próprio alvo (ex.: guarda): conta como visível.
	var col: Object = hit.get("collider")
	return col != null and (col == h.get_parent() or (col is Node and (col as Node).is_ancestor_of(h)))


func _pick_target() -> void:
	if candidates.is_empty():
		_set_target(null)
		return
	var mouse := _drawer.get_global_mouse_position()
	if Input.is_action_just_pressed("hack_next_target"):
		_cycle_index = (candidates.find(target) + 1) % candidates.size()
		_last_mouse = mouse
	if mouse.distance_to(_last_mouse) > 12.0:
		_cycle_index = -1
	if _cycle_index >= 0 and _cycle_index < candidates.size():
		_set_target(candidates[_cycle_index])
		return
	var best: Hackable = null
	var best_d := INF
	for h in candidates:
		var d := mouse.distance_to(h.global_position)
		if d < best_d:
			best_d = d
			best = h
	_set_target(best)


func _set_target(h: Hackable) -> void:
	if h == target:
		return
	target = h
	target_changed.emit(h)


# --- Hack ----------------------------------------------------------------

func _start_hack(h: Hackable) -> void:
	_hacking_target = h
	_set_active(false)
	_hacking_ui = _find_hacking_ui()
	GameManager.set_state(GameManager.State.HACKING)
	if _hacking_ui == null or not _hacking_ui.has_method("start_hacking"):
		push_warning("HackVision: HackingInterface não encontrada; hack resolvido como sucesso.")
		_finish_hack(true)
		return
	if not _hacking_ui.hacking_succeeded.is_connected(_on_hack_success):
		_hacking_ui.hacking_succeeded.connect(_on_hack_success, CONNECT_ONE_SHOT)
	if not _hacking_ui.hacking_failed.is_connected(_on_hack_failed):
		_hacking_ui.hacking_failed.connect(_on_hack_failed, CONNECT_ONE_SHOT)
	var d := h.get_difficulty()
	_hacking_ui.start_hacking(d.x, d.y)


func _find_hacking_ui() -> Node:
	var found := get_tree().get_first_node_in_group("hacking_ui")
	if found:
		return found
	return get_tree().current_scene.find_child("HackingInterface", true, false)


func _on_hack_success() -> void:
	_finish_hack(true)


func _on_hack_failed() -> void:
	_finish_hack(false)


func _finish_hack(success: bool) -> void:
	if _hacking_ui:
		if _hacking_ui.hacking_succeeded.is_connected(_on_hack_success):
			_hacking_ui.hacking_succeeded.disconnect(_on_hack_success)
		if _hacking_ui.hacking_failed.is_connected(_on_hack_failed):
			_hacking_ui.hacking_failed.disconnect(_on_hack_failed)
	var h := _hacking_target
	_hacking_target = null
	GameManager.set_state(GameManager.State.PLAYING)
	if is_instance_valid(h):
		h.resolve(success)


## Usado pelos testes: resolve um hack sem abrir a interface.
func debug_hack(h: Hackable, success: bool = true) -> void:
	_hacking_target = h
	_finish_hack(success)


# --- Desenho -------------------------------------------------------------

func _on_draw() -> void:
	if not active:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var eye := eye_position()
	# Alcance: círculo pontilhado discreto.
	_drawer.draw_arc(eye, vision_range, 0.0, TAU, 96, CYAN_DIM, 1.0)
	for h in candidates:
		var sel := h == target
		_draw_brackets(h.global_position, 22.0 if sel else 16.0, CYAN if sel else CYAN_DIM, 2.0 if sel else 1.0)
	if target:
		var to := target.global_position
		var dash := 10.0
		var offset := fmod(t * 60.0, dash * 2.0)
		var dir := (to - eye).normalized()
		var length := eye.distance_to(to)
		var s := -offset
		while s < length:
			var a := maxf(s, 0.0)
			var b := minf(s + dash, length)
			if b > a:
				_drawer.draw_line(eye + dir * a, eye + dir * b, CYAN, 2.0)
			s += dash * 2.0
		var label := target.get_label()
		_drawer.draw_string(_font, to + Vector2(-60, -34), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, CYAN)
		_drawer.draw_string(_font, to + Vector2(-60, 40), "[E] HACKEAR", HORIZONTAL_ALIGNMENT_CENTER, 120, 9, CYAN)


func _draw_brackets(c: Vector2, r: float, col: Color, w: float) -> void:
	var l := r * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * r, sy * r)
			_drawer.draw_line(corner, corner - Vector2(sx * l, 0), col, w)
			_drawer.draw_line(corner, corner - Vector2(0, sy * l), col, w)
