class_name LockdownZone
extends Area2D
## Lockdown (GDD/WDD "Eventos Dinâmicos"): se um alarme soar com o jogador
## dentro da zona, a Axioma fecha as portas da sala e manda unidades pesadas.
## O jogador tem `countdown` segundos para hackear a porta de saída — uma
## equação mais difícil (+1 nível) e mais curta. O hack não pode ser abortado
## (a interface não tem saída). Tempo esgotado = capturado (game over).
## Dispara uma vez por carregamento da fase.
##
## Formato: a forma de colisão filha define a sala. `door_paths` são as portas
## que fecham; `exit_door_path` é a que vira o desafio de saída.

signal lockdown_started
signal lockdown_cleared
signal lockdown_failed

@export var door_paths: Array[NodePath] = []
@export var exit_door_path: NodePath
@export var countdown: float = 25.0
@export var exit_difficulty_bonus: int = 1
@export var exit_time_mult: float = 0.5
@export_multiline var axioma_message: String = "Variância intolerável detectada.\nSetor isolado. Unidades pesadas a caminho."
## Retângulo (global) tingido de vermelho durante o lockdown.
@export var tint_rect: Rect2 = Rect2()

const RED := Color(1.0, 0.12, 0.2)

var active: bool = false
var done: bool = false
var time_left: float = 0.0
var _player_inside: bool = false
var _ui: CanvasLayer
var _title: Label
var _msg: Label
var _clock: Label
var _hint: Label
var _tint: ColorRect


func _ready() -> void:
	add_to_group("lockdown")
	monitorable = false
	body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("Player"):
			_player_inside = true)
	body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("Player"):
			_player_inside = false)
	GameManager.alarm_raised.connect(func(_p: Vector2) -> void: _on_alarm())
	# Guardas em alerta máximo não passam pelo GameManager: escuta cada um
	# (adiado: os guardas entram no grupo no _ready deles, depois do nosso).
	_connect_guards.call_deferred()
	_build_ui()


func _connect_guards() -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_signal("alarm_triggered"):
			g.alarm_triggered.connect(func(_p: Vector2) -> void: _on_alarm())


func is_player_inside() -> bool:
	return _player_inside


func _on_alarm() -> void:
	if not active and not done and _player_inside:
		start()


func start() -> void:
	active = true
	_hint.text = "HACKEIE A PORTA DE SAÍDA  [%s]" % Tutorial.key_of("hack_vision")  # tecla atual (remapeável)
	time_left = countdown
	for d in _doors():
		if d.has_method("close"):
			d.close()
	var exit := _exit_door()
	if exit:
		var h := exit.get_node_or_null("Hackable") as Hackable
		if h:
			h.enabled = true
			h.difficulty_bonus = exit_difficulty_bonus
			h.time_limit_mult = exit_time_mult
			h.abortable = false
		if not exit.opened.is_connected(_on_exit_opened):
			exit.opened.connect(_on_exit_opened, CONNECT_ONE_SHOT)
	_msg.text = axioma_message
	_ui.visible = true
	_tint.visible = true
	lockdown_started.emit()
	Sfx.play("alarm", -4.0)


func _process(delta: float) -> void:
	if not active:
		return
	time_left = maxf(time_left - delta, 0.0)
	_clock.text = "%02d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	_title.modulate.a = 0.55 + 0.45 * pulse
	_tint.color.a = 0.06 + 0.08 * pulse
	if time_left <= 0.0:
		_fail()


func _on_exit_opened() -> void:
	if not active:
		return
	active = false
	done = true
	for d in _doors():
		if d.has_method("open"):
			d.open()
	var exit := _exit_door()
	if exit:
		var h := exit.get_node_or_null("Hackable") as Hackable
		if h:
			h.difficulty_bonus = 0
			h.time_limit_mult = 1.0
			h.abortable = true
	_ui.visible = false
	_tint.visible = false
	get_tree().call_group("stealth_hud", "_flash", "LOCKDOWN ANULADO", Color(0.35, 0.95, 1.0))
	lockdown_cleared.emit()


func _fail() -> void:
	active = false
	done = true
	_title.text = "UNIDADES PESADAS NO SETOR"
	lockdown_failed.emit()
	var p := get_tree().get_first_node_in_group("Player")
	if p and p.has_method("die"):
		p.die()


func _doors() -> Array:
	var out := []
	for path in door_paths:
		var d := get_node_or_null(path)
		if d:
			out.append(d)
	var exit := _exit_door()
	if exit and not out.has(exit):
		out.append(exit)
	return out


func _exit_door() -> SecurityDoor:
	return get_node_or_null(exit_door_path) as SecurityDoor


func _build_ui() -> void:
	_tint = ColorRect.new()
	_tint.name = "LockdownTint"
	_tint.color = Color(RED, 0.1)
	_tint.position = tint_rect.position - global_position
	_tint.size = tint_rect.size
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.z_index = 15
	_tint.visible = false
	add_child(_tint)

	_ui = CanvasLayer.new()
	_ui.name = "LockdownUI"
	_ui.layer = 9
	_ui.visible = false
	add_child(_ui)
	var font: Font = load("res://assets/fonts/ui_font.tres") if ResourceLoader.exists("res://assets/fonts/ui_font.tres") else null
	_title = _label(font, 44, RED, 230)  # abaixo do aviso de alarme do HUD (y 150)
	_title.text = "AXIOMA // LOCKDOWN"
	_msg = _label(font, 20, Color(1, 0.75, 0.75), 295)
	_clock = _label(font, 56, Color(1, 0.9, 0.9), 365)
	_hint = _label(font, 18, Color(0.35, 0.95, 1.0), 445)
	_hint.text = "HACKEIE A PORTA DE SAÍDA  [%s]" % Tutorial.key_of("hack_vision")


func _label(font: Font, size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1920, 60)
	_ui.add_child(l)
	return l
