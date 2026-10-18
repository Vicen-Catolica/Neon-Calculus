class_name LoreReader
extends CanvasLayer
## Leitor de logs de lore: painel holográfico com efeito de digitação.
## Pausa o jogo enquanto aberto. Fecha com F/Esc/E (ou clique).

signal closed

const CYAN := Color(0.35, 0.95, 1.0)
const CHARS_PER_SEC := 90.0

var _panel: PanelContainer
var _source: Label
var _title: Label
var _author: Label
var _body: Label
var _hint: Label
var _full_text: String = ""
var _shown: float = 0.0
var _open: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("lore_reader")
	_build()
	visible = false


func _build() -> void:
	var font: Font = load("res://assets/fonts/Orbitron-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf") else null
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.1, 0.94)
	style.border_color = CYAN
	style.set_border_width_all(2)
	style.set_content_margin_all(36)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(1100, 0)
	# CenterContainer em tela cheia: o painel fica centralizado em qualquer
	# resolução. (Antes, âncora central + position fixa somava o deslocamento
	# ao centro e o painel saía pela direita/baixo.)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	_source = _label(box, font, 18, Color(0.6, 0.8, 0.85))
	_title = _label(box, font, 34, CYAN)
	_author = _label(box, font, 18, Color(0.45, 1.0, 0.55))
	var sep := HSeparator.new()
	box.add_child(sep)
	_body = _label(box, null, 24, Color(0.85, 0.95, 0.97))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(1020, 360)
	_hint = _label(box, font, 16, Color(0.6, 0.8, 0.85))
	_hint.text = "[F] FECHAR"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(parent: Node, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func show_entry(entry: Dictionary) -> void:
	_source.text = String(entry.get("source", "")).to_upper()
	_title.text = String(entry.get("title", ""))
	_author.text = "— " + String(entry.get("author", ""))
	_full_text = String(entry.get("text", ""))
	_body.text = ""
	_body.visible_characters = -1
	_shown = 0.0
	_open = true
	visible = true
	# set_state mexe em get_tree().paused; por isso pausa depois dele.
	GameManager.set_state(GameManager.State.PAUSED)
	get_tree().paused = true


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	if not _open:
		return
	if _shown < _full_text.length():
		_shown = minf(_shown + CHARS_PER_SEC * delta, _full_text.length())
		_body.text = _full_text.substr(0, int(_shown))


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var close_pressed := event.is_action_pressed("interact_world") or event.is_action_pressed("ui_cancel") \
		or event.is_action_pressed("hack_confirm")
	if not close_pressed:
		return
	get_viewport().set_input_as_handled()
	if _shown < _full_text.length():
		_shown = _full_text.length()  # primeiro aperto completa o texto
		_body.text = _full_text
		return
	_close()


func _close() -> void:
	_open = false
	visible = false
	GameManager.set_state(GameManager.State.PLAYING)
	get_tree().paused = false
	closed.emit()
