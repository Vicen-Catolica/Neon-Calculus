extends Control

var current_stage: int = 1
var current_subtopic: int = 0
var current_step: int = 0
var eq_data: Dictionary = {}

const COLOR_CYAN := Color("#00f0ff")
const COLOR_GREEN := Color("#39ff14")
const COLOR_YELLOW := Color("#ffd700")
const COLOR_BLUE := Color("#3b82f6")
const COLOR_MUTED := Color("#5a708a")

func _ready() -> void:
	resized.connect(queue_redraw)

func setup_visual(stage: int, subtopic: int, data: Dictionary, step: int = 0) -> void:
	current_stage = stage
	current_subtopic = subtopic
	eq_data = data
	current_step = step
	call_deferred("queue_redraw")

func _draw() -> void:
	if eq_data.is_empty():
		return
		
	var font = ThemeDB.fallback_font
	var draw_size = size if (size.x > 0 and size.y > 0) else custom_minimum_size
	var center = draw_size / 2.0
	
	match current_stage:
		1, 2:
			_draw_equation_steps(center, font)
		3:
			if current_subtopic == 1:
				_draw_geometry_steps(center, font)
			else:
				_draw_equation_steps(center, font)
		4:
			if current_subtopic == 1:
				_draw_triangle_steps(center, font)
			else:
				_draw_equation_steps(center, font)

func _draw_equation_steps(center: Vector2, font: Font) -> void:
	var mult = int(eq_data.get("ParamMult", eq_data.get("ParamA", 1)))
	var b_val = int(eq_data.get("ParamB", 0))
	var total = int(eq_data.get("ParamTotal", eq_data.get("ParamRes", 0)))
	
	var box_rect = Rect2(center.x - 110, center.y - 25, 220, 50)
	draw_rect(box_rect, COLOR_CYAN, false, 2.0)
	
	var text_display = ""
	var prompt_hint = ""
	
	if current_stage == 1:
		text_display = str(eq_data.get("Expression", ""))
		prompt_hint = "Digite a resposta do valor de X"
	elif current_step == 0:
		var sign_str = " + " if b_val >= 0 else " - "
		text_display = str(mult) + "x" + sign_str + str(abs(b_val)) + " = " + str(total)
		prompt_hint = "Passo 1: " + str(total) + (" - " if b_val >= 0 else " + ") + str(abs(b_val)) + " = ?"
	else:
		var diff = total - b_val
		text_display = str(mult) + "x = " + str(diff)
		prompt_hint = "Passo 2: Isole o X (" + str(diff) + " / " + str(mult) + " = ?)"
	
	draw_string(font, Vector2(center.x - 90, center.y + 5), text_display, HORIZONTAL_ALIGNMENT_CENTER, 180, 14, COLOR_GREEN if current_step == 1 else COLOR_CYAN)
	draw_string(font, Vector2(center.x - 110, center.y + 40), prompt_hint, HORIZONTAL_ALIGNMENT_CENTER, 220, 11, COLOR_YELLOW)

func _draw_triangle_steps(center: Vector2, font: Font) -> void:
	var ang_a = int(eq_data.get("ParamAngA", 37))
	var ang_b = int(eq_data.get("ParamAngB", 64))
	var soma = ang_a + ang_b
	
	var base_len = 110.0
	var tri_left = Vector2(center.x - (base_len / 2.0), center.y + 10)
	var tri_right = Vector2(center.x + (base_len / 2.0), center.y + 10)
	var tri_top = Vector2(center.x, center.y - 35)
	
	draw_line(tri_top, tri_left, COLOR_CYAN, 2.0, true)
	draw_line(tri_left, tri_right, COLOR_CYAN, 2.0, true)
	draw_line(tri_right, tri_top, COLOR_CYAN, 2.0, true)
	
	draw_string(font, tri_left + Vector2(10, -4), str(ang_a) + "°", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_BLUE)
	draw_string(font, tri_right + Vector2(-30, -4), str(ang_b) + "°", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_BLUE)
	draw_string(font, tri_top + Vector2(-8, 20), "x°", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_YELLOW)
	
	var formula_text = ""
	var prompt_hint = ""
	
	if current_step == 0:
		formula_text = str(ang_a) + "° + " + str(ang_b) + "° + x° = 180°"
		prompt_hint = "Passo 1: Somar " + str(ang_a) + " + " + str(ang_b)
	else:
		formula_text = str(soma) + "° + x° = 180°"
		prompt_hint = "Passo 2: Calcule x (180 - " + str(soma) + ")"

	draw_string(font, Vector2(center.x - 100, center.y + 32), formula_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 12, COLOR_CYAN)
	draw_string(font, Vector2(center.x - 110, center.y + 48), prompt_hint, HORIZONTAL_ALIGNMENT_CENTER, 220, 11, COLOR_YELLOW)

func _draw_geometry_steps(center: Vector2, font: Font) -> void:
	var altura = int(eq_data.get("ParamAltura", 4))
	var area = int(eq_data.get("ParamArea", 20))
	
	var rect = Rect2(center.x - 50, center.y - 30, 100, 40)
	draw_rect(rect, COLOR_CYAN, false, 2.0)
	draw_string(font, Vector2(center.x - 35, center.y - 5), "Área = " + str(area), HORIZONTAL_ALIGNMENT_CENTER, 70, 11, COLOR_CYAN)
	
	var prompt_hint = "Base (x) = Área (" + str(area) + ") / Altura (" + str(altura) + ")"
	draw_string(font, Vector2(center.x - 110, center.y + 35), prompt_hint, HORIZONTAL_ALIGNMENT_CENTER, 220, 11, COLOR_YELLOW)