class_name StealthHUD
extends CanvasLayer
## HUD de furtividade: barra do Score de Variância, aviso de alarme e dica de
## interação (esconder / ler terminal / visão hacker).

const CYAN := Color(0.35, 0.95, 1.0)
const ORANGE := Color(1.0, 0.6, 0.15)
const RED := Color(1.0, 0.2, 0.25)

var _bar_bg: ColorRect
var _bar: ColorRect
var _bar_label: Label
var _hint: Label
var _alert: Label
var _alert_timer: float = 0.0
var _font: Font
var _variance_ratio: float = 0.0

const BAR_W := 360.0


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("stealth_hud")
	_font = load("res://assets/fonts/Orbitron-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf") else null
	_build()
	GameManager.variance_changed.connect(_on_variance_changed)
	GameManager.alarm_raised.connect(_on_alarm)
	GameManager.sweep_triggered.connect(_on_sweep)
	_on_variance_changed(GameManager.variance, GameManager.variance_limit)


func _build() -> void:
	_bar_label = _make_label(18, CYAN)
	_bar_label.text = "VARIÂNCIA"
	_bar_label.position = Vector2(1920 - BAR_W - 48, 34)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.02, 0.06, 0.09, 0.85)
	_bar_bg.position = Vector2(1920 - BAR_W - 48, 62)
	_bar_bg.size = Vector2(BAR_W, 14)
	add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = CYAN
	_bar.position = _bar_bg.position + Vector2(2, 2)
	_bar.size = Vector2(0, 10)
	add_child(_bar)

	_hint = _make_label(22, CYAN)
	_hint.position = Vector2(0, 980)
	_hint.size = Vector2(1920, 40)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_alert = _make_label(40, RED)
	_alert.position = Vector2(0, 150)
	_alert.size = Vector2(1920, 60)
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.visible = false


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _on_variance_changed(value: float, limit: float) -> void:
	_variance_ratio = clampf(value / maxf(limit, 1.0), 0.0, 1.0)
	_bar.size.x = (BAR_W - 4) * _variance_ratio
	_bar.color = CYAN if _variance_ratio < 0.5 else (ORANGE if _variance_ratio < 0.8 else RED)


func _on_alarm(_pos: Vector2) -> void:
	_flash("ALARME — AGENTES A CAMINHO", RED)


func _on_sweep() -> void:
	_flash("PICO DE VARIÂNCIA — VARREDURA DE ROTINA", ORANGE)


func _flash(text: String, color: Color) -> void:
	_alert.text = text
	_alert.add_theme_color_override("font_color", color)
	_alert.visible = true
	_alert_timer = 2.5


func _process(delta: float) -> void:
	if _alert_timer > 0.0:
		_alert_timer -= delta / maxf(Engine.time_scale, 0.01)
		_alert.modulate.a = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 120.0))
		if _alert_timer <= 0.0:
			_alert.visible = false
	_hint.text = _current_hint()
	visible = GameManager.state != GameManager.State.GAME_OVER and not get_tree().paused


func _current_hint() -> String:
	if GameManager.state == GameManager.State.HACK_VISION:
		return "[MOUSE] MIRAR   [TAB] PRÓXIMO ALVO   [E / CLIQUE] HACKEAR"
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return ""
	for t in get_tree().get_nodes_in_group("data_terminal"):
		if t.is_player_near():
			return t.get_interaction_hint()
	if player.has_method("get_interaction_hint"):
		var h: String = player.get_interaction_hint()
		if h != "":
			return h
	return ""
