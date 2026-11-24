extends CanvasLayer

signal hacking_succeeded
signal hacking_failed
## Esc no meio do hack (GDD §4). `alert`: o abandono deixou rastro e soou um alarme.
signal hacking_aborted(alert: bool)

@onready var equation_label: Label = find_child("EquationLabel", true, false)
@onready var subtitle_label: Label = find_child("SubtitleLabel", true, false)
@onready var math_visualizer: Control = find_child("MathVisualizer", true, false)
@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var input_line = find_child("InputLine", true, false)
@onready var hack_timer: Timer = find_child("HackTimer", true, false)

# Painel do Assistente I.A. (Lado Esquerdo)
@onready var ai_assistant_panel: Control = find_child("AIAssistantPanel", true, false)
@onready var ai_hint_label: Label = find_child("AIHintLabel", true, false)

# Botões e Controles
@onready var numpad_grid: GridContainer = find_child("NumpadGrid", true, false)
@onready var btn_0: Button = find_child("Btn0", true, false)
@onready var submit_button: Button = find_child("SubmitButton", true, false)

# Player de Áudio para a Trilha Sonora do Hacking
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

var math_generator = load("res://scenes/hacking_ui/MathGenerator.cs").new()

## Opacidade do fundo durante o hack: o mapa congelado continua visível atrás.
@export_range(0.0, 1.0) var background_opacity: float = 0.75

var max_steps: int = 2
var current_step: int = 0
var step1_target_solution: int = 0
var final_target_solution: int = 0
var error_count: int = 0

var current_input_text: String = ""
var eq_data: Dictionary = {}
var current_floor_level: int = 1
var current_sub_topic: int = 0
var _blink_timer: float = 0.0
## Multiplicador do tempo limite do próximo hack (definido por quem abre a
## interface; volta a 1 depois de usado). < 1 = desafio rápido (lockdown).
var time_limit_mult: float = 1.0
## Alvo numa área de segurança máxima (tempo reduzido): aviso no rodapé.
var max_security: bool = false
## Abre o passo a passo da SINE já no começo (Protocolo Vance na última camada do Duelo).
var sine_at_start: bool = false
## Paradoxo final do Duelo (GDD §1/§9: a "Variável Infinita"): x = x + 1 não tem
## solução; a resposta é o botão "⌀ SEM SOLUÇÃO" (ou a tecla N).
## (⌀ U+2300 no lugar de ∅ U+2205: a Exo2 não tem o glifo do conjunto vazio.)
var paradox_mode: bool = false
var _paradox_btn: Button
const PARADOX_TIME := 60.0

## Penalidade de tempo por resposta errada (segundos).
const ERROR_PENALTY := 3.0
## Quanto tempo (real) o resultado fica na tela antes de fechar.
const RESULT_HOLD := 0.9
const FEEDBACK_OK := Color("#39ff14")
const FEEDBACK_ERR := Color("#ff2d55")
const FEEDBACK_WARN := Color("#ffd23f")

## Linha de retorno logo abaixo da resposta (acerto, erro, tempo esgotado).
var _feedback: Label
## Fechando a tela (acerto/tempo esgotado): ignora teclado e botões.
var _busy: bool = false
## Falso sob lockdown: o hack da saída não pode ser abandonado (GDD §4).
var can_abort: bool = true
var _time_total: float = 0.0
## Chance máxima de alerta ao abortar com o relógio cheio (cai com o tempo gasto).
## Protocolo Vance (resgate do Dr. Vance na Fase 3): tempo extra e SINE mais cedo.
const VANCE_FLAG := "vance_rescued"
const VANCE_TIME_MULT := 1.15
const ABORT_ALERT_MAX := 0.6

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Por cima de todo o HUD do mundo (furtividade 8, lockdown 9, lore 20); abaixo
	# só de diálogo (40), pausa (50) e game over/transição.
	layer = 30
	add_to_group("hacking_ui")
	hide()
	
	if ai_assistant_panel:
		ai_assistant_panel.hide()
		ai_assistant_panel.modulate = Color(1, 1, 1, 1)
	
	if hack_timer:
		# O mundo fica a 5% da velocidade durante o hack (Engine.time_scale), mas o
		# cronômetro do jogador é sempre em tempo real.
		hack_timer.ignore_time_scale = true
		hack_timer.timeout.connect(_on_hack_timer_timeout)
		
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color.a = background_opacity

	if numpad_grid:
		_add_edit_buttons()
		for btn in numpad_grid.get_children():
			if btn is Button and (btn as Button).text.is_valid_int():
				btn.pressed.connect(func(): _on_numpad_key_pressed(btn.text))
				
	# O 0 normalmente está no numpad_grid e já foi ligado acima; ligar de novo
	# fazia um clique no 0 digitar "00" (10 virava 100).
	if btn_0 and not (numpad_grid and btn_0.get_parent() == numpad_grid):
		btn_0.pressed.connect(func(): _on_numpad_key_pressed("0"))
		
	if input_line and input_line is LineEdit:
		input_line.text_submitted.connect(func(_text): _on_submit_pressed())

	_build_feedback()
	_build_formula()
	_update_accessibility_equation_size()
	if SettingsManager.has_signal("accessibility_settings_changed"):
		SettingsManager.accessibility_settings_changed.connect(_update_accessibility_equation_size)

## Troca os espaços vazios ao lado do 0 por "C" (limpa tudo) e "DEL" (apaga
## o último dígito), com o mesmo estilo dos botões numéricos.
func _add_edit_buttons() -> void:
	var template := numpad_grid.get_node_or_null("Btn1") as Button
	if template == null:
		return
	var slots := [["SpacerLeft", "BtnClear", "C", _clear_input],
		["SpacerRight", "BtnDelete", "DEL", _delete_last_digit]]
	for slot in slots:
		var spacer := numpad_grid.get_node_or_null(String(slot[0]))
		if spacer == null:
			continue
		var btn := template.duplicate() as Button
		btn.name = slot[1]
		btn.text = slot[2]
		if btn.text.length() > 1:
			btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(slot[3])
		var idx := spacer.get_index()
		numpad_grid.remove_child(spacer)
		spacer.queue_free()
		numpad_grid.add_child(btn)
		numpad_grid.move_child(btn, idx)


## Tween que ignora o Engine.time_scale (o mundo está em câmera lenta no hack).
func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _build_feedback() -> void:
	_feedback = Label.new()
	_feedback.name = "FeedbackLabel"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(380, 44)
	_feedback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_feedback.add_theme_font_override("font", load("res://assets/fonts/ui_font.tres"))
	_feedback.add_theme_font_size_override("font_size", 16)
	_feedback.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_feedback.add_theme_constant_override("outline_size", 4)
	var box := find_child("InputBoxPanel", true, false)
	if box and box.get_parent():
		box.get_parent().add_child(_feedback)
		box.get_parent().move_child(_feedback, box.get_index() + 1)
	else:
		add_child(_feedback)


func _show_feedback(text: String, color: Color) -> void:
	if _feedback == null:
		return
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.modulate.a = 1.0
	_feedback.pivot_offset = _feedback.size / 2.0
	var t := _tween()
	t.tween_property(_feedback, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(_feedback, "scale", Vector2.ONE, 0.12)


## Pisca a caixa da resposta numa cor (verde = certo, vermelho = errado).
func _flash_input(color: Color) -> void:
	var box := find_child("InputBoxPanel", true, false) as CanvasItem
	if box == null:
		return
	var t := _tween()
	for i in 2:
		t.tween_property(box, "modulate", color, 0.07)
		t.tween_property(box, "modulate", Color.WHITE, 0.09)


func _delete_last_digit() -> void:
	if current_input_text.length() > 0:
		current_input_text = current_input_text.substr(0, current_input_text.length() - 1)
		_update_input_display()


func _clear_input() -> void:
	current_input_text = ""
	_update_input_display()


func _update_accessibility_equation_size() -> void:
	if equation_label:
		equation_label.add_theme_font_size_override("font_size", SettingsManager.get_equation_font_size())

func start_hacking(floor_level: int, sub_topic: int = 0) -> void:
	get_tree().paused = true
	# Oculta a barra de vida do HUD durante o minigame de hacking
	get_tree().call_group("hud", "hide_hud")
	
	current_floor_level = floor_level
	current_sub_topic = sub_topic
	Sfx.play("hack_open", -6.0)
	error_count = 0
	_busy = false
	if _feedback:
		_feedback.text = "Digite o valor de x e confirme (Enter)." + ("   [Esc] abortar" if can_abort else "   Lockdown: não há como abortar.")
		_feedback.add_theme_color_override("font_color", Color(0.6, 0.8, 0.85))
	
	if ai_assistant_panel:
		ai_assistant_panel.hide()
		ai_assistant_panel.modulate = Color(1, 1, 1, 1)
	
	# Inicia a trilha sonora do minigame de hacking caso exista o player e o stream configurado
	if bgm_player and bgm_player.stream and not bgm_player.playing:
		bgm_player.play()
	
	eq_data = math_generator.GenerateValidEquation(floor_level, sub_topic)
	final_target_solution = int(eq_data["Solution"])
	
	if equation_label:
		equation_label.text = str(eq_data.get("Expression", ""))
		
	if subtitle_label:
		subtitle_label.text = str(eq_data.get("Topic", "DESAFIO MATEMÁTICO"))

	_setup_equation_steps(floor_level, sub_topic)
	_show_formula(formula_for(floor_level, sub_topic))
	current_input_text = ""
	_update_input_display()
	show()
	
	await get_tree().process_frame
	if math_visualizer and math_visualizer.has_method("setup_visual"):
		math_visualizer.setup_visual(floor_level, sub_topic, eq_data)
	
	var time_limit = _calculate_dynamic_time_limit()
	_time_total = time_limit
	if hack_timer:
		hack_timer.start(time_limit)

	if sine_at_start:
		sine_at_start = false
		_activate_ai_assistant()
		# Sem isso a SINE "aparece do nada" (playtest): diz que é o prêmio do resgate.
		_show_feedback("PROTOCOLO VANCE: a SINE já abriu o passo a passo ao lado.", Color("#ffaa00"))

	if equation_label:
		equation_label.text = str(eq_data.get("Expression", ""))
	
		equation_label.pivot_offset = equation_label.size / 2.0
		var tween = _tween()
		tween.tween_property(equation_label, "scale", Vector2(1.15, 1.15), 0.15)
		tween.tween_property(equation_label, "scale", Vector2(1.0, 1.0), 0.15)

func _calculate_dynamic_time_limit() -> float:
	var time_calculated: float = 12.0
	time_calculated += (max_steps * 14.0)
	
	match current_floor_level:
		1:
			time_calculated += 3.5 if current_sub_topic == 0 else 6.125
		2:
			time_calculated += 8.75
		3:
			time_calculated += 12.25 if current_sub_topic == 0 else 8.75
		4:
			time_calculated += 14.0 if current_sub_topic == 0 else 10.5
		5:
			# x dos dois lados (Núcleo): 3 passos; com parênteses, 4.
			time_calculated += 10.5 if current_sub_topic == 0 else 14.0
			
	var param_total = abs(int(eq_data.get("ParamTotal", eq_data.get("ParamRes", 0))))
	var param_b = int(eq_data.get("ParamB", eq_data.get("ParamA", 0)))
	var sol_val = abs(final_target_solution)
	
	if sol_val >= 100 or param_total >= 100:
		time_calculated += 8.1
	elif sol_val >= 25 or param_total >= 30:
		time_calculated += 4.725
		
	if param_b < 0 or int(eq_data.get("ParamA", 0)) < 0:
		time_calculated += 3.9
		
	if current_floor_level == 4 and current_sub_topic == 1:
		var ang_a = int(eq_data.get("ParamAngA", 0))
		var ang_b = int(eq_data.get("ParamAngB", 0))
		if (ang_a + ang_b) >= 100:
			time_calculated += 5.2

	time_calculated *= 2.0
	if vance_protocol():
		time_calculated *= VANCE_TIME_MULT
	var mult := time_limit_mult
	time_limit_mult = 1.0
	if mult < 1.0:
		return clamp(time_calculated * mult, 15.0, 240.0)
	return clamp(time_calculated * mult, 30.0, 240.0)

func _setup_equation_steps(stage: int, subtopic: int) -> void:
	if stage == 1 or (stage == 3 and subtopic == 1):
		max_steps = 1
		current_step = 1
		step1_target_solution = final_target_solution
		return
		
	max_steps = 3 if stage == 5 else 2
	current_step = 0
	
	match stage:
		2:
			var total = int(eq_data.get("ParamTotal", 0))
			var b_val = int(eq_data.get("ParamB", 0))
			step1_target_solution = total - b_val
		3:
			var base_val = int(eq_data.get("ParamBase", 1))
			var right_num = int(eq_data.get("ParamRightNum", 1))
			step1_target_solution = base_val * right_num
		4:
			if subtopic == 1:
				var ang_a = int(eq_data.get("ParamAngA", 0))
				var ang_b = int(eq_data.get("ParamAngB", 0))
				step1_target_solution = ang_a + ang_b
			else:
				var k = int(eq_data.get("ParamK", 1))
				var offset_val = int(eq_data.get("ParamOffset", 0))
				var total = int(eq_data.get("ParamTotal", 0))
				step1_target_solution = total - (k * offset_val)
		5:
			# 1º passo: juntar os x num lado só (coeficiente que sobra).
			if subtopic == 1:
				step1_target_solution = int(eq_data.get("ParamK", 1)) - int(eq_data.get("ParamC", 0))
			else:
				step1_target_solution = int(eq_data.get("ParamA", 1)) - int(eq_data.get("ParamC", 0))

func _get_current_user_value() -> String:
	if current_input_text != "":
		return current_input_text
	if input_line and input_line is LineEdit:
		return input_line.text.replace("x = [", "").replace("]", "").strip_edges()
	return ""

func _on_submit_pressed() -> void:
	if _busy or not visible:
		return
	var raw_input = _get_current_user_value()
	if raw_input == "":
		# Confirmar vazio não pune: só avisa.
		_show_feedback("Digite um número antes de confirmar.", FEEDBACK_WARN)
		return

	var user_val = raw_input.to_int()

	if user_val == final_target_solution:
		_busy = true
		if input_line:
			input_line.text = "x = %d" % user_val
		_show_feedback("CORRETO! x = %d. ACESSO CONCEDIDO." % user_val, FEEDBACK_OK)
		Sfx.play("hack_ok", -4.0)
		_flash_input(FEEDBACK_OK)
		if hack_timer:
			hack_timer.paused = true
		await _wait_real(RESULT_HOLD)
		_complete_hack(true)
	else:
		_trigger_error(user_val)

## Paradoxo final: a "equação" x = x + 1, sem gerador. Nenhum número serve.
func start_paradox() -> void:
	_show_formula("")  # a descoberta é do jogador; a SINE explica depois do 1º erro
	paradox_mode = true
	get_tree().paused = true
	get_tree().call_group("hud", "hide_hud")
	current_floor_level = 5
	current_sub_topic = 0
	error_count = 0
	_busy = false
	max_steps = 1
	eq_data = {"Expression": "x = x + 1", "Topic": "PARADOXO // VARIÁVEL INFINITA"}
	final_target_solution = -999999  # nenhum número digitável
	if equation_label:
		equation_label.text = "x = x + 1"
	if subtitle_label:
		subtitle_label.text = "PARADOXO // VARIÁVEL INFINITA"
	if ai_assistant_panel:
		ai_assistant_panel.hide()
	if math_visualizer:
		math_visualizer.visible = false
	_ensure_paradox_button()
	_paradox_btn.visible = true
	current_input_text = ""
	_update_input_display()
	_show_feedback("Encontre x... ou prove que ele não existe. Número + Enter, ou [⌀ SEM SOLUÇÃO] (tecla N).", Color(0.6, 0.8, 0.85))
	show()
	_time_total = PARADOX_TIME
	if hack_timer:
		hack_timer.start(PARADOX_TIME)


func _ensure_paradox_button() -> void:
	if _paradox_btn or submit_button == null:
		return
	_paradox_btn = Button.new()
	_paradox_btn.name = "ParadoxButton"
	_paradox_btn.text = "⌀ SEM SOLUÇÃO  [N]"
	_paradox_btn.custom_minimum_size = Vector2(submit_button.custom_minimum_size.x, 44)
	_paradox_btn.size_flags_horizontal = submit_button.size_flags_horizontal
	_paradox_btn.add_theme_font_override("font", load("res://assets/fonts/ui_font.tres"))
	_paradox_btn.add_theme_font_size_override("font_size", 20)
	_paradox_btn.add_theme_color_override("font_color", FEEDBACK_WARN)
	_paradox_btn.focus_mode = Control.FOCUS_NONE
	# Mesmo visual do "Confirmar", em amarelo (antes ficava no cinza padrão do Godot).
	for st in ["normal", "hover", "pressed"]:
		var base := submit_button.get_theme_stylebox(st)
		if base is StyleBoxFlat:
			var sb := base.duplicate() as StyleBoxFlat
			sb.border_color = FEEDBACK_WARN
			if st != "normal":
				sb.bg_color = FEEDBACK_WARN
			_paradox_btn.add_theme_stylebox_override(st, sb)
	for c in ["font_hover_color", "font_focus_color", "font_hover_pressed_color", "font_pressed_color"]:
		_paradox_btn.add_theme_color_override(c, Color(0.02, 0.055, 0.094))
	_paradox_btn.pressed.connect(_on_paradox_answer)
	submit_button.get_parent().add_child(_paradox_btn)
	submit_button.get_parent().move_child(_paradox_btn, submit_button.get_index() + 1)


## Resposta certa do Paradoxo: nenhum número satisfaz a equação.
func _on_paradox_answer() -> void:
	if not paradox_mode or _busy or not visible:
		return
	_busy = true
	if hack_timer:
		hack_timer.paused = true
	if input_line:
		input_line.text = "x = ⌀"
	_show_feedback("PARADOXO ACEITO: nenhum x satisfaz x = x + 1.\nA AXIOMA NÃO CONSEGUE COMPUTAR A VARIÁVEL INFINITA.", FEEDBACK_OK)
	_flash_input(FEEDBACK_OK)
	await _wait_real(RESULT_HOLD * 2.0)
	_complete_hack(true)


func _trigger_error(wrong_value: int = 0) -> void:
	error_count += 1
	Sfx.play("hack_fail", -5.0)
	GameManager.add_stat("hack_errors")
	current_input_text = ""
	_update_input_display()

	if hack_timer:
		hack_timer.start(max(0.1, hack_timer.time_left - ERROR_PENALTY))

	var msg := "INCORRETO: x = %d não resolve a equação. -%d s. Tente de novo." % [wrong_value, int(ERROR_PENALTY)]
	if paradox_mode:
		msg = "x = %d? Então %d = %d. Falso: nenhum número funciona aqui. -%d s." % [wrong_value, wrong_value, wrong_value + 1, int(ERROR_PENALTY)]
	if error_count >= sine_after_errors():
		msg += "\nA SINE abriu o passo a passo ao lado." + (" (Protocolo Vance: já no 1º erro)" if vance_protocol() and error_count == 1 else "")
	_show_feedback(msg, FEEDBACK_ERR)
	_flash_input(FEEDBACK_ERR)

	if error_count >= sine_after_errors():
		_activate_ai_assistant()

## Passo a passo do nível 5 (x dos dois lados): juntar os x num lado, os
## números no outro, dividir. Com parênteses, distribuir antes.
func _hint_both_sides() -> String:
	var c := int(eq_data.get("ParamC", 1))
	var cx := "x" if c == 1 else str(c) + "x"
	var text := ""
	var coef := 0
	var num := 0
	var rhs := 0
	var n := 1
	if current_sub_topic == 1:
		var k := int(eq_data.get("ParamK", 2))
		var m := int(eq_data.get("ParamM", 1))
		rhs = int(eq_data.get("ParamN", 0))
		coef = k - c
		num = k * m
		text += "[!] x DOS DOIS LADOS (PARÊNTESES):\n"
		text += " %d. Distribua o %d:\n" % [n, k]
		text += "    %dx + %d = %s + %d\n" % [k, num, cx, rhs]
		n += 1
	else:
		coef = int(eq_data.get("ParamA", 2)) - c
		num = int(eq_data.get("ParamB", 0))
		rhs = int(eq_data.get("ParamD", 0))
		text += "[!] x DOS DOIS LADOS:\n"
	var coef_x := "x" if coef == 1 else str(coef) + "x"
	text += " %d. Tire %s dos dois lados (os x ficam juntos):\n" % [n, cx]
	text += "    %s %s %d = %d\n" % [coef_x, "+" if num >= 0 else "-", absi(num), rhs]
	n += 1
	var diff := rhs - num
	if num >= 0:
		text += " %d. Tire %d dos dois lados:\n" % [n, num]
	else:
		text += " %d. Some %d aos dois lados:\n" % [n, -num]
	if coef == 1:
		# Aqui já seria o resultado: mostra só a conta a fazer.
		text += "    x = %d %s %d\n" % [rhs, "-" if num >= 0 else "+", absi(num)]
		return text.trim_suffix("\n")
	text += "    %s = %d\n" % [coef_x, diff]
	n += 1
	if coef != 1:
		text += " %d. Divida por %d:\n" % [n, coef]
		text += "    x = %d / %d" % [diff, coef]
	return text.trim_suffix("\n")


# --- Fórmula na tela ----------------------------------------------------
# Quem joga tem 10–12 anos: a regra geral do tipo de equação fica sempre à
# vista, embaixo da equação (em letras, sem os números da conta). O passo a
# passo da SINE aplica a regra aos números, mas para antes do resultado.

var _formula_label: Label


func _build_formula() -> void:
	var eq_panel := find_child("EquationPanel", true, false) as Control
	if eq_panel == null:
		return
	_formula_label = Label.new()
	_formula_label.name = "FormulaLabel"
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_formula_label.add_theme_font_size_override("font_size", 20)
	_formula_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	var parent := eq_panel.get_parent()
	parent.add_child(_formula_label)
	parent.move_child(_formula_label, eq_panel.get_index() + 1)


func _show_formula(text: String) -> void:
	if _formula_label:
		_formula_label.text = ("FÓRMULA:  " + text) if text != "" else ""
		_formula_label.visible = text != ""


func formula_text() -> String:
	return _formula_label.text if _formula_label else ""


## Regra geral de cada tipo de equação (mesmos tipos do EquationGenerator.cs).
func formula_for(floor_level: int, sub_topic: int) -> String:
	match floor_level:
		1:
			return "x + a = b   →   x = b − a" if sub_topic == 0 else "a · x = b   →   x = b ÷ a"
		2:
			return "a · x + b = c   →   x = (c − b) ÷ a"
		3:
			return "x ÷ a = b ÷ c   →   x = a · b ÷ c" if sub_topic == 0 else "Área = base · altura   →   base = Área ÷ altura"
		4:
			return "k · (x + a) = c   →   x = (c − k · a) ÷ k" if sub_topic == 0 else "A + B + x = 180°   →   x = 180° − (A + B)"
		5:
			if sub_topic == 1:
				return "k · (x + m) = c · x + n   →   distribua o k primeiro"
			return "a · x + b = c · x + d   →   x = (d − b) ÷ (a − c)"
	return ""


func vance_protocol() -> bool:
	return GameManager.has_flag(VANCE_FLAG)


## Erros até a SINE abrir o passo a passo: 2, ou 1 com o Protocolo Vance.
func sine_after_errors() -> int:
	return 1 if vance_protocol() else 2


func _activate_ai_assistant() -> void:
	if not ai_assistant_panel:
		return
		
	if not ai_assistant_panel.visible:
		var hint_text = _generate_step_by_step_hint()
		if ai_hint_label:
			ai_hint_label.text = hint_text
			ai_assistant_panel.show()
			ai_assistant_panel.modulate = Color("#ffaa00")
			
			var tween = _tween()
			tween.tween_property(ai_hint_label, "visible_ratio", 1.0, 1.2).from(0.0)
	else:
		_flash_ai_assistant()

func _flash_ai_assistant() -> void:
	if not ai_assistant_panel:
		return
		
	var tween = _tween()
	var alert_red := Color("#ff0055")
	var base_amber := Color("#ffaa00")
	
	tween.tween_property(ai_assistant_panel, "modulate", alert_red, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", base_amber, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", alert_red, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", base_amber, 0.08)

## Passo a passo da SINE. Usa o "x" minúsculo da equação e as mesmas contas
## que o gerador (scripts/hacking/EquationGenerator.cs) usou para montá-la.
func _generate_step_by_step_hint() -> String:
	var text = ">>> SINE // PASSO A PASSO\n"
	text += "---------------------------\n"
	if paradox_mode:
		text += "[!] PARADOXO:\n"
		text += " 1. Tire x dos dois lados:\n"
		text += "    0 = 1\n"
		text += " 2. Isso é sempre falso.\n"
		text += " > Nenhum número satisfaz a equação.\n"
		text += " > Responda: ⌀ SEM SOLUÇÃO (tecla N).\n"
		text += " > A Axioma vai tentar calcular para sempre."
		return text

	match current_floor_level:
		1:
			if current_sub_topic == 0:
				# x + a = res
				var a = int(eq_data.get("ParamA", 0))
				var res = int(eq_data.get("ParamRes", 0))
				text += "[!] ADIÇÃO E SUBTRAÇÃO:\n"
				if a >= 0:
					text += " > Tire " + str(a) + " dos dois lados:\n"
					text += "    x = " + str(res) + " - " + str(a) + "\n"
				else:
					text += " > Some " + str(-a) + " aos dois lados:\n"
					text += "    x = " + str(res) + " + " + str(-a) + "\n"
				text += " > Calcule o resultado."
			else:
				# count·x = res
				var count = int(eq_data.get("ParamA", 1))
				var res = int(eq_data.get("ParamRes", 0))
				text += "[!] MULTIPLICAÇÃO:\n"
				text += " > " + str(count) + " vezes x dá " + str(res) + ".\n"
				text += " > Divida os dois lados por " + str(count) + ":\n"
				text += "    x = " + str(res) + " / " + str(count)
		2:
			# mult·x ± b = total
			var mult = int(eq_data.get("ParamMult", 1))
			var b_val = int(eq_data.get("ParamB", 0))
			var total = int(eq_data.get("ParamTotal", 0))
			var diff = total - b_val
			text += "[!] EQUAÇÃO DO 1º GRAU:\n"
			if b_val >= 0:
				text += " 1. Tire " + str(b_val) + " dos dois lados:\n"
				text += "    " + str(mult) + "x = " + str(total) + " - " + str(b_val) + " = " + str(diff) + "\n"
			else:
				text += " 1. Some " + str(-b_val) + " aos dois lados:\n"
				text += "    " + str(mult) + "x = " + str(total) + " + " + str(-b_val) + " = " + str(diff) + "\n"
			text += " 2. Divida por " + str(mult) + ":\n"
			text += "    x = " + str(diff) + " / " + str(mult)
		3:
			if current_sub_topic == 0:
				# x / base = num / den
				var base_val = int(eq_data.get("ParamBase", 1))
				var r_num = int(eq_data.get("ParamRightNum", 1))
				var r_den = int(eq_data.get("ParamRightDen", 1))
				var prod = base_val * r_num
				text += "[!] REGRA DE TRÊS:\n"
				text += " 1. Multiplique em cruz:\n"
				text += "    x · " + str(r_den) + " = " + str(base_val) + " · " + str(r_num) + " = " + str(prod) + "\n"
				text += " 2. Divida por " + str(r_den) + ":\n"
				text += "    x = " + str(prod) + " / " + str(r_den)
			else:
				var area = int(eq_data.get("ParamArea", 1))
				var alt = int(eq_data.get("ParamAltura", 1))
				text += "[!] ÁREA DO RETÂNGULO:\n"
				text += " > Área = base · altura\n"
				text += " > A base é o x:\n"
				text += "    x = " + str(area) + " / " + str(alt)
		4:
			if current_sub_topic == 0:
				# k(x + offset) = total
				var k = int(eq_data.get("ParamK", 1))
				var offset_val = int(eq_data.get("ParamOffset", 0))
				var total = int(eq_data.get("ParamTotal", 0))
				var mult_off = k * offset_val
				var diff = total - mult_off
				text += "[!] PROPRIEDADE DISTRIBUTIVA:\n"
				text += " 1. Distribua o " + str(k) + ":\n"
				text += "    " + str(k) + "x + " + str(mult_off) + " = " + str(total) + "\n"
				text += " 2. Tire " + str(mult_off) + " e divida por " + str(k) + ":\n"
				text += "    x = " + str(diff) + " / " + str(k)
			else:
				var a = int(eq_data.get("ParamAngA", 0))
				var b = int(eq_data.get("ParamAngB", 0))
				var soma = a + b
				text += "[!] ÂNGULOS DO TRIÂNGULO:\n"
				text += " > Os três ângulos somam 180°.\n"
				text += " > " + str(a) + "° + " + str(b) + "° = " + str(soma) + "°\n"
				text += " > x = 180° - " + str(soma) + "°"
		5:
			text += _hint_both_sides()

	# A SINE monta a conta, mas quem calcula é o jogador.
	text += "\n > Agora faça a conta e digite o x."
	return text

func _process(delta: float) -> void:
	if hack_timer and hack_timer.time_left > 0 and timer_label:
		var minutes: int = int(hack_timer.time_left / 60.0)
		var seconds: int = int(hack_timer.time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		if hack_timer.time_left < 10.0:
			timer_label.add_theme_color_override("font_color", Color("#ff0055"))
		else:
			timer_label.add_theme_color_override("font_color", Color("#00f0ff"))

	# delta já vem multiplicado pelo time_scale; o cursor pisca em tempo real.
	_blink_timer += delta / maxf(Engine.time_scale, 0.01)
	var footer_label: Label = find_child("FooterStatusLabel", true, false)
	if footer_label:
		var cursor = "_" if fmod(_blink_timer, 0.8) < 0.4 else " "
		footer_label.text = "SYS_STATUS // AGUARDANDO ENTRADA" + cursor \
			+ ("   //   SEGURANÇA MÁXIMA: TEMPO REDUZIDO" if max_security else "") \
			+ ("   //   PROTOCOLO VANCE: +15% TEMPO, SINE NO 1º ERRO" if vance_protocol() else "")

func _on_numpad_key_pressed(digit: String) -> void:
	if _busy:
		return
	if current_input_text.length() < 4:
		Sfx.play("hack_key", -10.0, 0.06)
		current_input_text += digit
		_update_input_display()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		abort_hack()
		return
	if paradox_mode and event is InputEventKey and event.pressed and event.keycode == KEY_N:
		get_viewport().set_input_as_handled()
		_on_paradox_answer()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE:
			_delete_last_digit()
		elif event.keycode == KEY_DELETE:
			_clear_input()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_submit_pressed()
		elif event.unicode >= 48 and event.unicode <= 57:
			_on_numpad_key_pressed(String.chr(event.unicode))

func _update_input_display() -> void:
	if input_line:
		if current_input_text == "":
			input_line.text = "x = [    ]"
		else:
			input_line.text = "x = [ " + current_input_text + " ]"

## Chance de o abandono soar um alarme: proporcional ao tempo que ainda restava
## (GDD §4: "chance essa que escala com o tempo restante do hacking").
func abort_alert_chance() -> float:
	if hack_timer == null or _time_total <= 0.0:
		return 0.0
	return ABORT_ALERT_MAX * clampf(hack_timer.time_left / _time_total, 0.0, 1.0)


## Esc: fecha o hack sem resolver (conta como falha). `roll` < 0 sorteia; os
## testes passam um valor fixo. Sob lockdown só avisa e continua.
func abort_hack(roll: float = -1.0) -> void:
	if not visible or _busy:
		return
	if not can_abort:
		_show_feedback("LOCKDOWN: a saída precisa ser hackeada. Não há como abortar.", FEEDBACK_WARN)
		_flash_input(FEEDBACK_WARN)
		return
	_busy = true
	if hack_timer:
		hack_timer.paused = true
	var alert := (randf() if roll < 0.0 else roll) < abort_alert_chance()
	Sfx.play("hack_abort", -5.0)
	if alert:
		_show_feedback("HACK ABORTADO. A Axioma rastreou a conexão: ALERTA!", FEEDBACK_ERR)
		_flash_input(FEEDBACK_ERR)
	else:
		_show_feedback("HACK ABORTADO. Conexão encerrada sem rastro.", FEEDBACK_WARN)
	await _wait_real(0.6)
	_complete_hack(false)
	hacking_aborted.emit(alert)
	if alert:
		var p := get_tree().get_first_node_in_group("Player") as Node2D
		if p:
			GameManager.raise_alarm(p.global_position)


func _on_hack_timer_timeout() -> void:
	if _busy:
		return
	_busy = true
	if timer_label:
		timer_label.text = "00:00"
	_show_feedback("TEMPO ESGOTADO. A invasão falhou.", FEEDBACK_ERR)
	Sfx.play("hack_fail", -5.0)
	_flash_input(FEEDBACK_ERR)
	await _wait_real(RESULT_HOLD)
	_complete_hack(false)

func _complete_hack(success: bool) -> void:
	_busy = false
	max_security = false
	if paradox_mode:
		paradox_mode = false
		if _paradox_btn:
			_paradox_btn.visible = false
		if math_visualizer:
			math_visualizer.visible = true
	if hack_timer:
		hack_timer.stop()
		hack_timer.paused = false
		
	# Para a música de hacking ao concluir (sucesso ou falha)
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
		
	hide()
	get_tree().paused = false
	
	# Restaura a visualização da barra de vida ao fechar a interface
	get_tree().call_group("hud", "show_hud")
	
	if success:
		emit_signal("hacking_succeeded")
	else:
		emit_signal("hacking_failed")	