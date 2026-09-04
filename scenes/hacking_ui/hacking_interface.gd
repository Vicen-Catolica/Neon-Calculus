extends CanvasLayer

signal hacking_succeeded
signal hacking_failed

# Procura os nós pelo nome em qualquer lugar da hierarquia (sem erro de caminho ou %):
@onready var equation_label: Label = find_child("EquationLabel", true, false)
@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var input_line = find_child("InputLine", true, false)
@onready var hack_timer: Timer = find_child("HackTimer", true, false)

@onready var numpad_grid: GridContainer = find_child("NumpadGrid", true, false)
@onready var btn_0: Button = find_child("Btn0", true, false)
@onready var submit_button: Button = find_child("SubmitButton", true, false)

var math_generator = load("res://scenes/hacking_ui/MathGenerator.cs").new()
var current_solution: int = 0
var current_input_text: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	if hack_timer:
		hack_timer.timeout.connect(_on_hack_timer_timeout)
		
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	
	# Conecta os botões numéricos (1 a 9)
	if numpad_grid:
		for btn in numpad_grid.get_children():
			if btn is Button:
				btn.pressed.connect(func(): _on_numpad_key_pressed(btn.text))
				
	# Conecta o botão 0
	if btn_0:
		btn_0.pressed.connect(func(): _on_numpad_key_pressed("0"))
		
	if input_line:
		if input_line is LineEdit:
			input_line.text_submitted.connect(func(_text): _on_submit_pressed())

func start_hacking(floor_level: int) -> void:
	get_tree().paused = true
	
	var eq_data = math_generator.GenerateValidEquation(floor_level)
	current_solution = eq_data["Solution"]
	
	if equation_label:
		equation_label.text = str(eq_data["Expression"])
	
	current_input_text = ""
	_update_input_display()
	show()
	
	var time_limit = max(5.0, 20.0 - (floor_level * 1.5))
	if hack_timer:
		hack_timer.start(time_limit)

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

func _on_submit_pressed() -> void:
	var user_val = current_input_text.to_int()
	if user_val == current_solution and current_input_text != "":
		_complete_hack(true)
	else:
		current_input_text = ""
		_update_input_display()
		if hack_timer:
			hack_timer.start(max(0.1, hack_timer.time_left - 3.0))

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
