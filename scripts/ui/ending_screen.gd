class_name EndingScreen
extends Control
## Tela de encerramento (GDD §9, roteiro de vitória): "Nova Gödel livre", as
## estatísticas da partida e os créditos. Entra depois do branco da vitória.
## Enter/Esc ou o botão voltam ao menu principal.

const GREEN := Color("39ff14")
const CYAN := Color("00f0ff")
const ORANGE := Color("ff6a1a")
const TEXT := Color(0.86, 0.92, 0.95)

const STORY := "A Axioma tentou computar a Variável Infinita e não conseguiu parar de calcular. Os neons laranja apagaram andar por andar, as portas da mega-torre se abriram e o Projeto Determinismo foi abortado.\n\nPela primeira vez desde 2115, ninguém em Nova Gödel sabe o que vai acontecer amanhã."

const AUTHORS := ["Adrian Riegel", "Eduardo Selzer", "Giovani Micheluzzi Zermiani", "Juliana Maria de Azevedo", "Vicenzo Luiggi Mori"]

var _fade: ColorRect


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.set_state(GameManager.State.PLAYING)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# Chega do branco da vitória: o branco se desfaz.
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_menu()


func back_to_menu() -> void:
	get_tree().change_scene_to_file(GameManager.MAIN_MENU_SCENE)


## Texto das estatísticas (também usado pelos testes).
static func stats_lines() -> Array[String]:
	var s: Dictionary = GameManager.stats
	var t := int(float(s.get("time", 0.0)))
	var lines: Array[String] = []
	lines.append("Tempo de infiltração: %02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60])
	lines.append("Hacks bem-sucedidos: %d" % int(s.get("hacks", 0)))
	lines.append("Erros de cálculo: %d" % int(s.get("hack_errors", 0)))
	lines.append("Alarmes disparados: %d" % int(s.get("alarms", 0)))
	lines.append("Fragmentos de dados lidos: %d de %d" % [GameManager.lore_read.size(), LoreDatabase.count()])
	lines.append("Dr. Vance: " + ("resgatado" if GameManager.has_flag("vance_rescued") else "não resgatado"))
	return lines


func _build() -> void:
	var font: Font = load("res://assets/fonts/ui_font.tres")
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# A torre com as portas abertas ao amanhecer (PixelLab), escurecida sob o texto.
	var art := TextureRect.new()
	art.name = "EndingArt"
	art.texture = load("res://assets/backgrounds/core/ending.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.03, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var row := HBoxContainer.new()
	row.position = Vector2(140, 110)
	row.size = Vector2(1640, 860)
	row.add_theme_constant_override("separation", 120)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(900, 0)
	left.add_theme_constant_override("separation", 22)
	row.add_child(left)
	_label(left, font, "NOVA GÖDEL LIVRE", 64, GREEN).name = "Title"
	_label(left, font, "O Paradoxo foi inserido. A Axioma entrou em colapso.", 26, CYAN)
	var story := _label(left, font, STORY, 24, TEXT)
	story.name = "Story"
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(900, 0)
	_label(left, font, "// REGISTRO DA INFILTRAÇÃO", 24, ORANGE)
	var stats := _label(left, font, "\n".join(stats_lines()), 24, TEXT)
	stats.name = "Stats"

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(620, 0)
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	_label(right, font, "NEON CALCULUS", 40, CYAN)
	_label(right, font, "PAC 3 — Engenharia de Software\nCatólica de Santa Catarina\nJaraguá do Sul, 2026", 20, TEXT)
	_label(right, font, "// AUTORES", 22, ORANGE)
	var authors := _label(right, font, "\n".join(AUTHORS), 22, TEXT)
	authors.name = "Authors"
	_label(right, font, "// FEITO COM", 22, ORANGE)
	_label(right, font, "Godot Engine 4 (.NET)\nFontes Exo 2 e Orbitron (SIL Open Font License)\nArte em pixel gerada com PixelLab e ajustada pela equipe\nTrilha: The Axioma Resolve, Overclocked Resolve, Hydraulic Tomb", 18, TEXT)
	_label(right, font, "Obrigado por jogar.", 22, GREEN)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "VOLTAR AO MENU  (Enter)"
	back.position = Vector2(760, 980)
	back.custom_minimum_size = Vector2(400, 56)
	back.add_theme_font_override("font", font)
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", GREEN)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.02, 0.08, 0.05, 0.9)
	bs.border_color = GREEN
	bs.set_border_width_all(2)
	back.add_theme_stylebox_override("normal", bs)
	back.add_theme_stylebox_override("hover", bs)
	back.add_theme_stylebox_override("focus", bs)
	back.pressed.connect(back_to_menu)
	add_child(back)

	_fade = ColorRect.new()
	_fade.name = "FadeFromWhite"
	_fade.color = Color(1, 1, 1, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _label(parent: Node, font: Font, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
