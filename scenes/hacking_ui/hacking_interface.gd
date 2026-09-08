extends CanvasLayer

signal hacking_succeeded
signal hacking_failed

@onready var equation_label: Label = find_child("EquationLabel", true, false)
@onready var subtitle_label: Label = find_child("SubtitleLabel", true, false)
@onready var math_visualizer: Control = find_child("MathVisualizer", true, false)
@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var input_line = find_child("InputLine", true, false)
@onready var hack_timer: Timer = find_child("HackTimer", true, false)

@onready var numpad_grid: GridContainer = find_child("NumpadGrid", true, false)
@onready var btn_0: Button = find_child("Btn0", true, false)
@onready var submit_button: Button = find_child("SubmitButton", true, false)

var math_generator = load("res://scenes/hacking_ui/MathGenerator.cs").new()

var max_steps: int = 2
var current_step: int = 0
var step1_target_solution: int = 0
var final_target_solution: int = 0

var current_input_text: String = ""
var eq_data: Dictionary = {}
var current_floor_level: int = 1
var current_sub_topic: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
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
	
	eq_data = math_generator.GenerateValidEquation(floor_level, sub_topic)
	final_target_solution = int(eq_data["Solution"])
	
	_setup_equation_steps(floor_level, sub_topic)
	_update_step_ui()
	show()
	
	await get_tree().process_frame
	if math_visualizer and math_visualizer.has_method("setup_visual"):
		math_visualizer.setup_visual(floor_level, sub_topic, eq_data, current_step)
	
	var time_limit = max(8.0, 25.0 - (floor_level * 1.5))
	if hack_timer:
		hack_timer.start(time_limit)

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
				var offset_val = int(eq_data.get("ParamOffset", 0)) # Nome corrigido para evitar conflito
				var total = int(eq_data.get("ParamTotal", 0))
				step1_target_solution = total - (k * offset_val)

func _update_step_ui() -> void:
	current_input_text = ""
	_update_input_display()
	
	if subtitle_label:
		if max_steps == 1:
			subtitle_label.text = str(eq_data.get("Topic", "DESAFIO MATEMÁTICO"))
		elif current_step == 0:
			subtitle_label.text = "PASSO 1/2: RESOLVA O PRIMEIRO TERMO DA FÓRMULA"
		else:
			subtitle_label.text = "PASSO 2/2: ISOLE A VARIÁVEL X"

func _on_submit_pressed() -> void:
	var user_val = current_input_text.to_int()
	
	if max_steps == 1:
		if user_val == final_target_solution and current_input_text != "":
			_complete_hack(true)
		else:
			_trigger_error()
	else:
		if current_step == 0:
			if user_val == step1_target_solution and current_input_text != "":
				current_step = 1
				_update_step_ui()
				if math_visualizer and math_visualizer.has_method("setup_visual"):
					math_visualizer.setup_visual(current_floor_level, current_sub_topic, eq_data, current_step)
			else:
				_trigger_error()
		else:
			if user_val == final_target_solution and current_input_text != "":
				_complete_hack(true)
			else:
				_trigger_error()

func _trigger_error() -> void:
	current_input_text = ""
	_update_input_display()
	if hack_timer:
		hack_timer.start(max(0.1, hack_timer.time_left - 3.0))

func _process(_delta: float) -> void:
	if hack_timer and hack_timer.time_left > 0 and timer_label:
		var minutes: int = int(hack_timer.time_left / 60.0)
		var seconds: int = int(hack_timer.time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_numpad_key_pressed(digit: String) -> void:
	if current_input_text.length() < 4:
		current_input_text += digit
		_update_input_display()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE and current_input_text.length() > 0:
			current_input_text = current_input_text.substr(0, current_input_text.length() - 1)
			_update_input_display()

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