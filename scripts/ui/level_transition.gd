extends CanvasLayer
## Autoload. Transição entre andares (GDD §8 "Tela de Loading / Transições"):
## tela preta com o ícone da Axioma (icosaedro laranja girando) e
## "Acessando... <andar>". Carrega a cena em segundo plano; meta < 2 s.

const ORANGE := Color("FF6A1A")
const FADE_TIME := 0.25
## Tempo mínimo com o ícone na tela, para a transição não piscar.
const MIN_SHOW := 0.9
const ICON_RADIUS := 120.0
const PHI := 1.6180339887

var _busy: bool = false
var _black: ColorRect
var _icon: Control
var _label: Label
var _angle: float = 0.0
var _verts: Array[Vector3] = []
var _edges: Array[Vector2i] = []


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_geometry()
	_build_ui()
	visible = false


func is_busy() -> bool:
	return _busy


## Troca para a cena `path` com a tela de transição. `title` vazio usa o nome do
## andar registrado no GameManager.
func change_level(path: String, title: String = "") -> void:
	if _busy:
		return
	_busy = true
	if title == "":
		title = GameManager.level_title(path)
	_label.text = ("Acessando... %s" % title) if title != "" else "Acessando..."
	visible = true
	_icon.modulate.a = 0.0
	_label.modulate.a = 0.0
	await _fade(_black, 1.0)
	# Mundo parado e em velocidade normal durante a troca.
	get_tree().paused = true
	Engine.time_scale = 1.0
	_fade(_icon, 1.0)
	_fade(_label, 1.0)

	var started := Time.get_ticks_msec()
	var requested := ResourceLoader.load_threaded_request(path) == OK
	var packed: PackedScene = null
	while true:
		await get_tree().process_frame
		if requested:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(path)
			elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				requested = false  # falhou: tenta o load direto abaixo
		else:
			packed = load(path)
		var waited := (Time.get_ticks_msec() - started) / 1000.0
		if packed != null and waited >= MIN_SHOW:
			break
		if not requested and packed == null:
			push_error("LevelTransition: não consegui carregar %s" % path)
			break

	get_tree().paused = false
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame
	_fade(_icon, 0.0)
	_fade(_label, 0.0)
	await _fade(_black, 0.0)
	visible = false
	_busy = false


func _process(delta: float) -> void:
	if visible:
		_angle += delta
		_icon.queue_redraw()


func _fade(node: CanvasItem, to: float) -> Signal:
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(node, "modulate:a" if node != _black else "color:a", to, FADE_TIME)
	return t.finished


func _build_ui() -> void:
	_black = ColorRect.new()
	_black.color = Color(0.067, 0.07, 0.078, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)

	_icon = Control.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	add_child(_icon)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -900
	_label.offset_top = -90
	_label.offset_right = -60
	_label.offset_bottom = -40
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_color", ORANGE)
	_label.add_theme_font_size_override("font_size", 26)
	if ResourceLoader.exists("res://assets/fonts/ui_font.tres"):
		_label.add_theme_font_override("font", load("res://assets/fonts/ui_font.tres"))
	add_child(_label)


func _build_geometry() -> void:
	# Icosaedro: (0, ±1, ±φ) e permutações cíclicas; arestas = pares a distância 2.
	for a in [-1.0, 1.0]:
		for b in [-PHI, PHI]:
			_verts.append(Vector3(0, a, b))
			_verts.append(Vector3(a, b, 0))
			_verts.append(Vector3(b, 0, a))
	for i in _verts.size():
		for j in range(i + 1, _verts.size()):
			if absf(_verts[i].distance_to(_verts[j]) - 2.0) < 0.01:
				_edges.append(Vector2i(i, j))


func _draw_icon() -> void:
	var center := _icon.size * 0.5
	var basis := Basis(Vector3.UP, _angle * 0.9) * Basis(Vector3.RIGHT, 0.45 + sin(_angle * 0.5) * 0.2)
	var k := ICON_RADIUS / sqrt(1.0 + PHI * PHI)
	var pts: Array[Vector2] = []
	for v in _verts:
		var r := basis * v
		pts.append(center + Vector2(r.x, r.y) * k)
	# Brilho largo e translúcido por baixo, traço fino por cima (sem anti-aliasing).
	for e in _edges:
		_icon.draw_line(pts[e.x], pts[e.y], Color(ORANGE, 0.16), 9.0)
	for e in _edges:
		_icon.draw_line(pts[e.x], pts[e.y], ORANGE, 3.0)
	for p in pts:
		_icon.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.85, 0.6))
