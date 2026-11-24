class_name OpticalCamo
extends Node
## Variável Oculta (GDD §3 e §4): camuflagem óptica de até 5 s. Enquanto ativa,
## o Eduardo fica invisível para guardas, Unidades Lógicas, câmeras e drones;
## os passos ainda podem ser ouvidos (correr faz barulho) e os lasers ainda
## disparam (são feixes físicos). Gasta uma bateria dedicada que recarrega aos
## poucos depois de 1 s desligada.
##
## Tecla C (o Q do GDD já é a visão hacker). Apertar de novo desliga antes.
## O indicador fica no canto inferior esquerdo, sob o do sonar ("Módulos do Traje").

signal camo_changed(active: bool)

## Segundos de camuflagem com a bateria cheia.
const CAPACITY := 5.0
## Bateria mínima para ligar (evita liga-desliga de frações de segundo).
const MIN_TO_START := 1.0
## Segundos de recarga por segundo, depois de RECHARGE_DELAY desligada (cheia em ~20 s).
const RECHARGE_RATE := 0.25
const RECHARGE_DELAY := 1.0
const CYAN := Color(0.0, 0.94, 1.0)

var active: bool = false
var battery: float = CAPACITY
var _idle: float = 99.0
var _bar: ColorRect
var _label: Label
var _ui: CanvasLayer


func _ready() -> void:
	add_to_group("hud")  # some com o resto do HUD durante o hack
	_build_ui()


func can_start() -> bool:
	if active or battery < MIN_TO_START or get_tree().paused:
		return false
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.HACK_VISION:
		return false
	var p := get_parent()
	return p != null and not p.get("is_dead")


func toggle() -> void:
	if active:
		stop()
	else:
		start()


func start() -> bool:
	if not can_start():
		return false
	_set_active(true)
	Sfx.play("camo", -6.0)
	get_tree().call_group("stealth_hud", "_flash", "VARIÁVEL OCULTA ATIVA", CYAN)
	return true


func stop() -> void:
	if active:
		_set_active(false)


func _set_active(value: bool) -> void:
	active = value
	_idle = 0.0
	var p := get_parent()
	if p:
		p.set("camouflaged", value)
	camo_changed.emit(value)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("camo"):
		toggle()
	var p := get_parent()
	if active:
		battery = maxf(battery - delta, 0.0)
		if battery <= 0.0 or (p and p.get("is_dead")):
			stop()
	else:
		_idle += delta
		if _idle >= RECHARGE_DELAY:
			battery = minf(battery + RECHARGE_RATE * delta, CAPACITY)
	# Visual: translúcido com tremulação ciano; pisca no último segundo.
	var spr := p.get_node_or_null("Sprite") as CanvasItem if p else null
	if spr:
		if active:
			var t := Time.get_ticks_msec() / 1000.0
			var a := 0.22 + 0.08 * sin(t * 18.0)
			if battery < 1.0 and int(t * 8.0) % 2 == 0:
				a = 0.6
			spr.self_modulate = Color(0.55, 1.0, 1.0, a)
		else:
			spr.self_modulate = Color.WHITE
	_bar.size.x = 160.0 * battery / CAPACITY
	_bar.color = CYAN if battery >= MIN_TO_START else Color(1.0, 0.4, 0.3)
	if active:
		_label.text = "CAMUFLAGEM [%s]  ATIVA %.1f s" % [Tutorial.key_of("camo"), battery]
	elif battery >= CAPACITY:
		_label.text = "CAMUFLAGEM [%s]  PRONTA" % Tutorial.key_of("camo")
	else:
		_label.text = "CAMUFLAGEM [%s]  %d%%" % [Tutorial.key_of("camo"), int(100.0 * battery / CAPACITY)]


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	_ui = ui
	var font: Font = load("res://assets/fonts/ui_font.tres")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.05, 0.08, 0.8)
	bg.position = Vector2(28, 1060)
	bg.size = Vector2(160, 8)
	ui.add_child(bg)
	_bar = ColorRect.new()
	_bar.position = bg.position
	_bar.size = bg.size
	_bar.color = CYAN  # estado inicial (antes do 1º _process)
	ui.add_child(_bar)
	_label = Label.new()
	_label.position = Vector2(28, 1032)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", CYAN)
	_label.text = "CAMUFLAGEM [%s]  PRONTA" % Tutorial.key_of("camo")
	ui.add_child(_label)


## Grupo "hud": a tela de hack esconde e mostra o HUD inteiro.
func hide_hud() -> void:
	_ui.visible = false


func show_hud() -> void:
	_ui.visible = true
