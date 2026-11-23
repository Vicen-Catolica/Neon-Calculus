extends CanvasLayer
## Autoload "Dialogue". Caixa de diálogo do GDD §8 (centro inferior): falas de
## SINE, Eduardo, Axioma e Dr. Vance, escritas letra a letra.
##
##   Dialogue.play_id("rnd_elevator")          # roteiro de data/dialogue/*.json
##   Dialogue.play("id", [{"who": "SINE", "text": "..."}])
##
## Pausa o jogo enquanto aberta (como o leitor de lore). A digitação usa o
## relógio real, então não depende de Engine.time_scale.
## E / clique / F / Enter: completa a fala ou passa para a próxima. Esc: pula tudo.
## Ao terminar, marca o id como visto (vai para o save) e emite `finished`.
## Falas podem ter "if_flag"/"unless_flag" (marcos da história, ex.: Vance).
## Quando a Axioma fala, a tela ganha uma interferência vermelha (GDD §9: ela
## se manifesta pelos monitores e alto-falantes).

signal finished(dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogue/"
const CHARS_PER_SEC := 55.0

## Nome exibido e cor de cada falante (GDD §8: ciano = SINE, vermelho/laranja = Axioma).
## Retratos (PixelLab, tools/gen_core_art.py); sem arquivo, a caixa mostra a inicial.
const PORTRAITS := {
	"SINE": "res://assets/ui/portraits/sine.png",
	"EDUARDO": "res://assets/ui/portraits/eduardo.png",
	"AXIOMA": "res://assets/ui/portraits/axioma.png",
	"VANCE": "res://assets/ui/portraits/vance.png",
}

const SPEAKERS := {
	"SINE": ["S.I.N.E.", Color("00f0ff")],
	"EDUARDO": ["EDUARDO", Color("e8eef2")],
	"AXIOMA": ["AXIOMA", Color("ff6a1a")],
	"VANCE": ["DR. VANCE", Color("39ff14")],
}

var _root: Control
var _glitch: ColorRect
var _portrait: Label
var _portrait_tex: TextureRect
var _portrait_box: PanelContainer
var _portrait_style: StyleBoxFlat
var _panel_style: StyleBoxFlat
var _name: Label
var _body: Label
var _hint: Label

var _id: String = ""
var _lines: Array = []
var _index: int = 0
var _shown: float = 0.0
var _last_ticks: int = 0
var _open: bool = false
var _cache: Dictionary = {}


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_open() -> bool:
	return _open


## Roteiro pelo id, procurado em todos os JSON de data/dialogue/, já filtrado
## pelos marcos da história do save.
func lines_for(dialogue_id: String) -> Array:
	if _cache.is_empty():
		_load_all()
	return (_cache.get(dialogue_id, []) as Array).filter(_line_allowed)


func _line_allowed(line: Dictionary) -> bool:
	if line.has("if_flag") and not GameManager.has_flag(String(line["if_flag"])):
		return false
	if line.has("unless_flag") and GameManager.has_flag(String(line["unless_flag"])):
		return false
	return true


func play_id(dialogue_id: String) -> bool:
	var lines := lines_for(dialogue_id)
	if lines.is_empty():
		push_warning("Dialogue: roteiro '%s' não encontrado" % dialogue_id)
		return false
	return play(dialogue_id, lines)


func play(dialogue_id: String, lines: Array) -> bool:
	if _open or lines.is_empty():
		return false
	_id = dialogue_id
	_lines = lines
	_index = 0
	_open = true
	visible = true
	# set_state mexe em get_tree().paused; por isso pausa depois dele.
	GameManager.set_state(GameManager.State.PAUSED)
	get_tree().paused = true
	_show_line()
	return true


## Pula o roteiro inteiro (Esc).
func skip() -> void:
	if _open:
		_finish()


## Avança como o jogador: completa a fala atual ou vai para a próxima.
func advance() -> void:
	if not _open:
		return
	var text := _current_text()
	if _shown < text.length():
		_shown = text.length()
		_body.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


func current_speaker() -> String:
	return String(_lines[_index].get("who", "SINE")).to_upper() if _open else ""


func is_line_complete() -> bool:
	return _open and _shown >= _current_text().length()


func _current_text() -> String:
	return String(_lines[_index].get("text", "")) if _open else ""


func _show_line() -> void:
	var who := current_speaker()
	var info: Array = SPEAKERS.get(who, [who, Color.WHITE])
	var color: Color = info[1]
	_name.text = info[0]
	_name.add_theme_color_override("font_color", color)
	_portrait.text = String(info[0]).left(1)
	_portrait.add_theme_color_override("font_color", color)
	var tex_path: String = PORTRAITS.get(who, "")
	_portrait_tex.texture = load(tex_path) if tex_path != "" and ResourceLoader.exists(tex_path) else null
	_portrait.visible = _portrait_tex.texture == null
	_portrait_style.border_color = color
	_panel_style.border_color = Color(color, 0.85)
	_body.text = _current_text()
	_body.visible_characters = 0
	_shown = 0.0
	_last_ticks = Time.get_ticks_msec()
	_hint.text = "[E] CONTINUAR    [ESC] PULAR" if _index < _lines.size() - 1 else "[E] FECHAR"
	_glitch.visible = who == "AXIOMA"


func _process(_delta: float) -> void:
	if not _open:
		return
	var now := Time.get_ticks_msec()
	if _glitch.visible:
		_glitch.color.a = 0.05 + (0.08 if (now / 70) % 5 == 0 else 0.0)
		_body.position.x = 2.0 if (now / 50) % 9 == 0 else 0.0
	var dt := (now - _last_ticks) / 1000.0
	_last_ticks = now
	var total := _current_text().length()
	if _shown < total:
		var before := int(_shown)
		_shown = minf(_shown + CHARS_PER_SEC * dt, total)
		_body.visible_characters = -1 if _shown >= total else int(_shown)
		_blip(before, int(_shown))


## Voice blips (GDD §9): um bipe a cada BLIP_EVERY letras escritas, com o
## timbre de quem fala (assets/sfx/blip_<falante>.wav).
const BLIP_EVERY := 3


func _blip(from_char: int, to_char: int) -> void:
	var text := _current_text()
	for i in range(from_char, mini(to_char, text.length())):
		if i % BLIP_EVERY != 0 or text[i] == " ":
			continue
		var who := current_speaker().to_lower()
		var sfx := "blip_" + who if Sfx.stream("blip_" + who) else "blip_ui"
		Sfx.play(sfx, -8.0, 0.08)
		return


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()
	elif event.is_action_pressed("hack_confirm") or event.is_action_pressed("interact_world") \
			or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func _finish() -> void:
	var id := _id
	_open = false
	visible = false
	_glitch.visible = false
	_lines = []
	_id = ""
	if id != "":
		GameManager.mark_dialogue_seen(id)
	GameManager.set_state(GameManager.State.PLAYING)
	get_tree().paused = false
	finished.emit(id)


func _load_all() -> void:
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + f))
		if data is Dictionary:
			for k in data:
				_cache[k] = data[k]


func _build() -> void:
	var font: Font = load("res://assets/fonts/ui_font.tres")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_glitch = ColorRect.new()
	_glitch.name = "AxiomaGlitch"
	_glitch.color = Color(1.0, 0.15, 0.1, 0.06)
	_glitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch.visible = false
	_root.add_child(_glitch)

	var panel := PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.012, 0.03, 0.055, 0.94)
	_panel_style.border_color = Color("00f0ff")
	_panel_style.set_border_width_all(2)
	_panel_style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", _panel_style)
	# Centro inferior (GDD §8), em 1920x1080.
	panel.position = Vector2(310, 790)
	panel.size = Vector2(1300, 230)
	_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	# "Retrato" holográfico: inicial do falante (até existir arte de retrato).
	_portrait_box = PanelContainer.new()
	_portrait_style = StyleBoxFlat.new()
	_portrait_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_portrait_style.set_border_width_all(2)
	_portrait_box.add_theme_stylebox_override("panel", _portrait_style)
	_portrait_box.custom_minimum_size = Vector2(150, 150)
	_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_box)
	_portrait = Label.new()
	_portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait.add_theme_font_override("font", font)
	_portrait.add_theme_font_size_override("font_size", 72)
	_portrait_box.add_child(_portrait)
	_portrait_tex = TextureRect.new()
	_portrait_tex.name = "PortraitArt"
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_tex.custom_minimum_size = Vector2(142, 142)
	_portrait_box.add_child(_portrait_tex)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	_name = Label.new()
	_name.add_theme_font_override("font", font)
	_name.add_theme_font_size_override("font_size", 26)
	col.add_child(_name)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("font", font)
	_body.add_theme_font_size_override("font_size", 24)
	_body.add_theme_color_override("font_color", Color(0.88, 0.94, 0.96))
	col.add_child(_body)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.75, 0.8))
	col.add_child(_hint)
