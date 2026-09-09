extends CanvasLayer

signal hacking_succeeded
signal hacking_failed

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

var math_generator = load("res://scenes/hacking_ui/MathGenerator.cs").new()

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	if ai_assistant_panel:
		ai_assistant_panel.hide()
		ai_assistant_panel.modulate = Color(1, 1, 1, 1)
	
	if hack_timer:
		hack_timer.timeout.connect(_on_hack_timer_timeout)
		
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	
	if numpad_grid:
		for btn in numpad_grid.get_children():
			if btn is Button:
				btn.pressed.connect(func(): _on_numpad_key_pressed(btn.text))
				
	if btn_0:
		btn_0.pressed.connect(func(): _on_numpad_key_pressed("0"))
		
	if input_line and input_line is LineEdit:
		input_line.text_submitted.connect(func(_text): _on_submit_pressed())

func start_hacking(floor_level: int, sub_topic: int = 0) -> void:
	get_tree().paused = true
	current_floor_level = floor_level
	current_sub_topic = sub_topic
	error_count = 0
	
	if ai_assistant_panel:
		ai_assistant_panel.hide()
		ai_assistant_panel.modulate = Color(1, 1, 1, 1)
	
	eq_data = math_generator.GenerateValidEquation(floor_level, sub_topic)
	final_target_solution = int(eq_data["Solution"])
	
	if equation_label:
		equation_label.text = str(eq_data.get("Expression", ""))
		
	if subtitle_label:
		subtitle_label.text = str(eq_data.get("Topic", "DESAFIO MATEMÁTICO"))

	_setup_equation_steps(floor_level, sub_topic)
	current_input_text = ""
	_update_input_display()
	show()
	
	await get_tree().process_frame
	if math_visualizer and math_visualizer.has_method("setup_visual"):
		math_visualizer.setup_visual(floor_level, sub_topic, eq_data)
	
	var time_limit = _calculate_dynamic_time_limit()
	if hack_timer:
		hack_timer.start(time_limit)

	if equation_label:
		equation_label.text = str(eq_data.get("Expression", ""))
	
	# Efeito de pulso rápido na conta ao carregar
		equation_label.pivot_offset = equation_label.size / 2.0
		var tween = create_tween()
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

	# DOBRA O TEMPO CALCULADO TOTAL
	time_calculated *= 2.0

	# Ajusta os limites: mínimo de 30 segundos e máximo de 240 segundos (4 minutos)
	return clamp(time_calculated, 30.0, 240.0)

func _setup_equation_steps(stage: int, subtopic: int) -> void:
	if stage == 1 or (stage == 3 and subtopic == 1):
		max_steps = 1
		current_step = 1
		step1_target_solution = final_target_solution
		return
		
	max_steps = 2
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

func _get_current_user_value() -> String:
	if current_input_text != "":
		return current_input_text
	if input_line and input_line is LineEdit:
		return input_line.text.replace("X = [", "").replace("]", "").strip_edges()
	return ""

func _on_submit_pressed() -> void:
	var raw_input = _get_current_user_value()
	if raw_input == "":
		_trigger_error()
		return
		
	var user_val = raw_input.to_int()
	
	if user_val == final_target_solution:
		_complete_hack(true)
	else:
		_trigger_error()

func _trigger_error() -> void:
	error_count += 1
	current_input_text = ""
	_update_input_display()
	
	# Penalidade de tempo
	if hack_timer:
		hack_timer.start(max(0.1, hack_timer.time_left - 3.0))
		
	# Ativa ou faz a I.A. piscar no 2º erro em diante
	if error_count >= 2:
		_activate_ai_assistant()

func _activate_ai_assistant() -> void:
	if not ai_assistant_panel:
		return
		
	# Se a I.A. AINDA NÃO estiver visível (1ª vez ativando)
	if not ai_assistant_panel.visible:
		var hint_text = _generate_step_by_step_hint()
		if ai_hint_label:
			ai_hint_label.text = hint_text
			ai_assistant_panel.show()
			
			# Garante que a I.A. comece com a cor Laranja/Amarela base
			ai_assistant_panel.modulate = Color("#ffaa00")
			
			var tween = create_tween()
			tween.tween_property(ai_hint_label, "visible_ratio", 1.0, 1.2).from(0.0)
	else:
		# Se JÁ estiver visível: pisca o painel entre Vermelho e Laranja
		_flash_ai_assistant()

func _flash_ai_assistant() -> void:
	if not ai_assistant_panel:
		return
		
	var tween = create_tween()
	var alert_red := Color("#ff0055")   # Vermelho de Erro
	var base_amber := Color("#ffaa00")  # Laranja Alerta da IA
	
	# Pulso rápido chamando a atenção
	tween.tween_property(ai_assistant_panel, "modulate", alert_red, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", base_amber, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", alert_red, 0.08)
	tween.tween_property(ai_assistant_panel, "modulate", base_amber, 0.08)
	

func _generate_step_by_step_hint() -> String:
	var text = ">>> A.I. ASSISTANT PROTOCOL\n"
	text += "---------------------------\n"
	
	match current_floor_level:
		1:
			if current_sub_topic == 0:
				var a = int(eq_data.get("ParamA", 0))
				var res = int(eq_data.get("ParamRes", 0))
				var op = " - " + str(a) if a >= 0 else " - (" + str(a) + ")"
				text += "[!] ANÁLISE DE RETA REAL:\n"
				text += " > Isolando a variável X:\n"
				text += "   X = " + str(res) + op + "\n"
				text += " > Calcule o valor final."
			else:
				var count = int(eq_data.get("ParamA", 1))
				var res = int(eq_data.get("ParamRes", 0))
				text += "[!] BLOCOS ÁLGEBRICOS:\n"
				text += " > Divida a soma total:\n"
				text += "   X = " + str(res) + " / " + str(count)
		2:
			var mult = int(eq_data.get("ParamMult", 1))
			var b_val = int(eq_data.get("ParamB", 0))
			var total = int(eq_data.get("ParamTotal", 0))
			var op = " - " + str(b_val) if b_val >= 0 else " + " + str(abs(b_val))
			var diff = total - b_val
			text += "[!] EQUAÇÃO DE 1º GRAU:\n"
			text += " 1. Transfira a constante:\n"
			text += "    " + str(mult) + "X = " + str(total) + op + " = " + str(diff) + "\n"
			text += " 2. Divida pelo multiplicador:\n"
			text += "    X = " + str(diff) + " / " + str(mult)
		3:
			if current_sub_topic == 0:
				var base_val = int(eq_data.get("ParamBase", 1))
				var r_num = int(eq_data.get("ParamRightNum", 1))
				var r_den = int(eq_data.get("ParamRightDen", 1))
				var prod = base_val * r_num
				text += "[!] REGRA DE TRÊS:\n"
				text += " 1. Multiplicação cruzada:\n"
				text += "    " + str(base_val) + " · " + str(r_num) + " = " + str(prod) + "\n"
				text += " 2. Divida por " + str(r_den) + ":\n"
				text += "    X = " + str(prod) + " / " + str(r_den)
			else:
				var area = int(eq_data.get("ParamArea", 1))
				var alt = int(eq_data.get("ParamAltura", 1))
				text += "[!] GEOMETRIA PLANAR:\n"
				text += " > Fórmula: Base · Altura = Área\n"
				text += " > Isolando Base (X):\n"
				text += "   X = " + str(area) + " / " + str(alt)
		4:
			if current_sub_topic == 0:
				var k = int(eq_data.get("ParamK", 1))
				var offset_val = int(eq_data.get("ParamOffset", 0))
				var total = int(eq_data.get("ParamTotal", 0))
				var mult_off = k * offset_val
				var diff = total - mult_off
				text += "[!] DISTRIBUTIVA:\n"
				text += " 1. Expanda os termos:\n"
				text += "    " + str(k) + "X + " + str(mult_off) + " = " + str(total) + "\n"
				text += " 2. Subtraia e divida por " + str(k) + ":\n"
				text += "    X = " + str(diff) + " / " + str(k)
			else:
				var a = int(eq_data.get("ParamAngA", 0))
				var b = int(eq_data.get("ParamAngB", 0))
				var soma = a + b
				text += "[!] GEOMETRIA TRIANGULAR:\n"
				text += " > Soma interna = 180°\n"
				text += " > Ângulos: " + str(a) + "° + " + str(b) + "° = " + str(soma) + "°\n"
				text += " > X = 180° - " + str(soma) + "°"
				
	return text

func _process(delta: float) -> void:
	# Atualiza o Temporizador e muda para vermelho no final
	if hack_timer and hack_timer.time_left > 0 and timer_label:
		var minutes: int = int(hack_timer.time_left / 60.0)
		var seconds: int = int(hack_timer.time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		if hack_timer.time_left < 10.0:
			timer_label.add_theme_color_override("font_color", Color("#ff0055"))
		else:
			timer_label.add_theme_color_override("font_color", Color("#00f0ff"))

	# Cursor do Rodapé Piscando (_)
	_blink_timer += delta
	var footer_label: Label = find_child("FooterStatusLabel", true, false)
	if footer_label:
		var cursor = "_" if fmod(_blink_timer, 0.8) < 0.4 else " "
		footer_label.text = "SYS_STATUS // AGUARDANDO ENTRADA" + cursor

func _on_numpad_key_pressed(digit: String) -> void:
	if current_input_text.length() < 4:
		current_input_text += digit
		_update_input_display()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE and current_input_text.length() > 0:
			current_input_text = current_input_text.substr(0, current_input_text.length() - 1)
			_update_input_display()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_submit_pressed()
		elif event.unicode >= 48 and event.unicode <= 57:
			_on_numpad_key_pressed(String.chr(event.unicode))

func _update_input_display() -> void:
	if input_line:
		if current_input_text == "":
			input_line.text = "X = [   ]"
		else:
			input_line.text = "X = [ " + current_input_text + " ]"

func _on_hack_timer_timeout() -> void:
	_complete_hack(false)

func _complete_hack(success: bool) -> void:
	if hack_timer:
		hack_timer.stop()
	hide()
	get_tree().paused = false
	
	if success:
		emit_signal("hacking_succeeded")
	else:
		emit_signal("hacking_failed")
