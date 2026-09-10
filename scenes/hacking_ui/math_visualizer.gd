extends Control

# Permite arrastar o arquivo de fonte Orbitron (.ttf ou .otf) direto pelo Inspetor no nó MathVisualizer
@export var custom_font: Font

var current_stage: int = 1
var current_subtopic: int = 0
var eq_data: Dictionary = {}

const COLOR_CYAN := Color("#00f0ff")
const COLOR_GREEN := Color("#39ff14")
const COLOR_YELLOW := Color("#ffd700")
const COLOR_BLUE := Color("#3b82f6")
const COLOR_MUTED := Color("#5a708a")

func _ready() -> void:
	resized.connect(queue_redraw)

func setup_visual(stage: int, subtopic: int, data: Dictionary) -> void:
	current_stage = stage
	current_subtopic = subtopic
	eq_data = data
	call_deferred("queue_redraw")

func _draw() -> void:
	if eq_data.is_empty():
		return
		
	# Prioridade: 1. Custom Font (Inspetor) -> 2. Theme Font -> 3. Fallback
	var font: Font = custom_font
	if not font:
		font = get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
		
	var draw_size := size if (size.x > 0 and size.y > 0) else custom_minimum_size
	var center := draw_size / 2.0
	
	_draw_cyberpunk_hud_frame(draw_size)
	
	match current_stage:
		1:
			if current_subtopic == 0:
				_draw_clean_number_line(center, font)
			else:
				_draw_clean_algebra_blocks(center, font)
		2:
			_draw_clean_equation_balance(center, font)
		3:
			if current_subtopic == 0:
				_draw_clean_ratio_cross(center, font)
			else:
				_draw_clean_geometry_rectangle(center, font)
		4:
			if current_subtopic == 0:
				_draw_clean_distributive_blocks(center, font)
			else:
				_draw_clean_triangle(center, font)

# --- ELEMENTOS VISUAIS DE HUD CYBERPUNK ---
func _draw_cyberpunk_hud_frame(draw_size: Vector2) -> void:
	var grid_color := Color("#00f0ff", 0.05)
	var step_grid := 20.0
	var x_steps := int(draw_size.x / step_grid)
	for i in range(x_steps):
		draw_line(Vector2(i * step_grid, 0), Vector2(i * step_grid, draw_size.y), grid_color, 1.0)

	var corner_color := COLOR_CYAN
	var bracket_size := 10.0
	var thick := 2.0
	
	draw_line(Vector2(0, 0), Vector2(bracket_size, 0), corner_color, thick)
	draw_line(Vector2(0, 0), Vector2(0, bracket_size), corner_color, thick)
	
	draw_line(Vector2(draw_size.x, 0), Vector2(draw_size.x - bracket_size, 0), corner_color, thick)
	draw_line(Vector2(draw_size.x, 0), Vector2(draw_size.x, bracket_size), corner_color, thick)
	
	draw_line(Vector2(0, draw_size.y), Vector2(bracket_size, draw_size.y), corner_color, thick)
	draw_line(Vector2(0, draw_size.y), Vector2(0, draw_size.y - bracket_size), corner_color, thick)
	
	draw_line(Vector2(draw_size.x, draw_size.y), Vector2(draw_size.x - bracket_size, draw_size.y), corner_color, thick)
	draw_line(Vector2(draw_size.x, draw_size.y), Vector2(draw_size.x, draw_size.y - bracket_size), corner_color, thick)

# --- STAGE 1 (TEMA 0): RETA NUMÉRICA ---
func _draw_clean_number_line(center: Vector2, font: Font) -> void:
	var a: int = int(eq_data.get("ParamA", 3))
	var res: int = int(eq_data.get("ParamRes", 10))
	var line_y: float = center.y
	
	draw_line(Vector2(center.x - 100, line_y), Vector2(center.x + 100, line_y), COLOR_CYAN, 2.0, true)
	
	var step_px: float = clamp(float(a) * 8.0, -70.0, 70.0)
	if abs(step_px) < 15.0: step_px = 25.0 * (1.0 if a >= 0 else -1.0)
	
	var start_x: float = center.x - (step_px / 2.0)
	var end_x: float = center.x + (step_px / 2.0)
	
	draw_line(Vector2(start_x, line_y - 12), Vector2(end_x, line_y - 12), COLOR_YELLOW, 2.0, true)
	var dir: float = 1.0 if step_px >= 0 else -1.0
	draw_line(Vector2(end_x, line_y - 12), Vector2(end_x - (6 * dir), line_y - 16), COLOR_YELLOW, 2.0, true)
	draw_line(Vector2(end_x, line_y - 12), Vector2(end_x - (6 * dir), line_y - 8), COLOR_YELLOW, 2.0, true)
	
	draw_string(font, Vector2(start_x - 10, line_y + 18), "x", HORIZONTAL_ALIGNMENT_CENTER, 20, 13, COLOR_YELLOW)
	draw_string(font, Vector2(end_x - 10, line_y + 18), str(res), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, COLOR_GREEN)

# --- STAGE 1 (TEMA 1): BLOCOS DE ÁLGEBRA ---
func _draw_clean_algebra_blocks(center: Vector2, font: Font) -> void:
	var count: int = int(clamp(float(eq_data.get("ParamA", 3)), 2.0, 5.0))
	var res: int = int(eq_data.get("ParamRes", 15))
	
	var box_w: float = 32.0
	var total_w: float = count * (box_w + 6.0)
	var start_x: float = center.x - (total_w / 2.0) - 20.0
	
	for i in range(count):
		var box_rect := Rect2(start_x + (i * (box_w + 6.0)), center.y - 14, box_w, 28)
		draw_rect(box_rect, COLOR_CYAN, false, 2.0)
		draw_string(font, box_rect.position + Vector2(11, 19), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_CYAN)
	
	draw_string(font, Vector2(start_x + total_w + 10, center.y + 4), "=  " + str(res), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_GREEN)

# --- STAGE 2: EQUAÇÃO DO 1º GRAU (MODELO DE BARRAS / TAPE MODEL) ---
func _draw_clean_equation_balance(center: Vector2, font: Font) -> void:
	var mult: int = int(eq_data.get("ParamMult", 2))
	var b_val: int = int(eq_data.get("ParamB", 0))
	var total: int = int(eq_data.get("ParamTotal", 0))
	
	var total_w: float = 220.0
	var bar_h: float = 28.0
	var start_x: float = center.x - (total_w / 2.0)
	
	# --- BARRA SUPERIOR (TOTAL = C) ---
	var top_y: float = center.y - 28.0
	var top_rect := Rect2(start_x, top_y, total_w, bar_h)
	draw_rect(top_rect, COLOR_GREEN, false, 2.0)
	draw_string(font, Vector2(start_x, top_y + 19), "TOTAL = " + str(total), HORIZONTAL_ALIGNMENT_CENTER, total_w, 14, COLOR_GREEN)
	
	# --- BARRA INFERIOR DIVIDIDA (Ax + B) ---
	var bot_y: float = center.y + 6.0
	var abs_b: int = abs(b_val)
	
	var ratio: float = float(abs_b) / float(max(1, total))
	var w_b: float = clamp(total_w * ratio, 40.0, 90.0)
	var w_ax: float = total_w - w_b
	
	var rect_ax := Rect2(start_x, bot_y, w_ax, bar_h)
	var rect_b := Rect2(start_x + w_ax, bot_y, w_b, bar_h)
	
	# Bloco do Ax
	draw_rect(rect_ax, COLOR_CYAN, false, 2.0)
	draw_string(font, Vector2(start_x, bot_y + 19), str(mult) + "x", HORIZONTAL_ALIGNMENT_CENTER, w_ax, 13, COLOR_CYAN)
	
	# Bloco do B
	var sign_str: String = "+" if b_val >= 0 else "-"
	draw_rect(rect_b, COLOR_YELLOW, false, 2.0)
	draw_string(font, Vector2(start_x + w_ax, bot_y + 19), sign_str + " " + str(abs_b), HORIZONTAL_ALIGNMENT_CENTER, w_b, 13, COLOR_YELLOW)

# --- STAGE 3 (TEMA 0): REGRA DE TRÊS (VISUALIZADOR DE MULTIPLICAÇÃO CRUZADA) ---
func _draw_clean_ratio_cross(center: Vector2, font: Font) -> void:
	var base_val: int = int(eq_data.get("ParamBase", 3))
	var right_num: int = int(eq_data.get("ParamRightNum", 12))
	var right_den: int = int(eq_data.get("ParamRightDen", 6))
	
	draw_string(font, Vector2(center.x - 50, center.y - 15), "x", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, COLOR_GREEN)
	draw_string(font, Vector2(center.x + 30, center.y - 15), str(right_num), HORIZONTAL_ALIGNMENT_CENTER, 20, 16, COLOR_CYAN)
	draw_string(font, Vector2(center.x - 50, center.y + 20), str(base_val), HORIZONTAL_ALIGNMENT_CENTER, 20, 16, COLOR_CYAN)
	draw_string(font, Vector2(center.x + 30, center.y + 20), str(right_den), HORIZONTAL_ALIGNMENT_CENTER, 20, 16, COLOR_CYAN)
	
	draw_line(Vector2(center.x - 25, center.y - 10), Vector2(center.x + 25, center.y + 15), COLOR_MUTED, 1.5, true)
	draw_line(Vector2(center.x - 25, center.y + 15), Vector2(center.x + 25, center.y - 10), COLOR_MUTED, 1.5, true)

# --- STAGE 3 (TEMA 1): GEOMETRIA (RETÂNGULO) ---
func _draw_clean_geometry_rectangle(center: Vector2, font: Font) -> void:
	var altura: float = float(eq_data.get("ParamAltura", 5.0))
	var area: float = float(eq_data.get("ParamArea", 40.0))
	var base_val: float = float(eq_data.get("Solution", area / maxf(1.0, altura)))
	
	# Aspecto da forma (Base / Altura) com trava para não deformar excessivamente
	var aspect: float = clampf(base_val / maxf(1.0, altura), 0.5, 2.5)
	
	# Dimensões visuais ampliadas e legíveis
	var base_size: float = 100.0
	var rect_w: float = clampf(base_size * sqrt(aspect), 85.0, 150.0)
	var rect_h: float = clampf(rect_w / aspect, 38.0, 60.0)
	
	var rect := Rect2(center.x - (rect_w / 2.0), center.y - (rect_h / 2.0) + 2.0, rect_w, rect_h)
	
	# 1. Preenchimento sutil do Retângulo (Efeito Cyberpunk Área)
	var fill_color := Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.12)
	draw_rect(rect, fill_color, true)
	
	# 2. Moldura/Borda do Retângulo
	draw_rect(rect, COLOR_CYAN, false, 2.0)
	
	# 3. ÁREA (Centralizada no meio do retângulo)
	var area_text := "ÁREA = " + str(int(area))
	draw_string(font, Vector2(rect.position.x, center.y + 6.0), area_text, HORIZONTAL_ALIGNMENT_CENTER, rect_w, 12, COLOR_CYAN)
	
	# 4. BASE = x (Acima do retângulo em Verde)
	var base_text := "BASE = x"
	draw_string(font, Vector2(rect.position.x, rect.position.y - 8.0), base_text, HORIZONTAL_ALIGNMENT_CENTER, rect_w, 12, COLOR_GREEN)
	
	# 5. ALTURA (À esquerda do retângulo com margem em Amarelo)
	var alt_text := "ALT = " + str(int(altura))
	var alt_x: float = rect.position.x - 75.0
	draw_string(font, Vector2(alt_x, center.y + 5.0), alt_text, HORIZONTAL_ALIGNMENT_RIGHT, 65.0, 12, COLOR_YELLOW)

# --- STAGE 4 (TEMA 0): PROPRIEDADE DISTRIBUTIVA ---
func _draw_clean_distributive_blocks(center: Vector2, font: Font) -> void:
	var k: int = int(eq_data.get("ParamK", 3))
	var offset_val: int = int(eq_data.get("ParamOffset", 4))
	var total: int = int(eq_data.get("ParamTotal", 24))
	var mult_offset: int = k * offset_val
	
	var ratio: float = float(offset_val) / float(max(1, offset_val + 5))
	var total_w: float = 140.0
	var w_a: float = clamp(total_w * (1.0 - ratio), 45.0, 95.0)
	var w_b: float = total_w - w_a
	
	var rect_a := Rect2(center.x - (total_w / 2.0), center.y - 18, w_a, 36)
	var rect_b := Rect2(center.x - (total_w / 2.0) + w_a, center.y - 18, w_b, 36)
	
	draw_rect(rect_a, COLOR_CYAN, false, 2.0)
	draw_rect(rect_b, COLOR_GREEN, false, 2.0)
	
	draw_string(font, rect_a.position + Vector2(10, 22), str(k) + "·x", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_CYAN)
	draw_string(font, rect_b.position + Vector2(10, 22), str(mult_offset), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GREEN)
	draw_string(font, Vector2(center.x - 50, center.y + 32), "= " + str(total), HORIZONTAL_ALIGNMENT_CENTER, 100, 13, COLOR_YELLOW)

# --- STAGE 4 (TEMA 1): ÂNGULOS DO TRIÂNGULO ---
func _draw_clean_triangle(center: Vector2, font: Font) -> void:
	var ang_a: float = float(eq_data.get("ParamAngA", 50))
	var ang_b: float = float(eq_data.get("ParamAngB", 52))
	var ang_c: float = 180.0 - (ang_a + ang_b)
	
	var rad_a: float = deg_to_rad(ang_a)
	var rad_b: float = deg_to_rad(ang_b)
	var rad_c: float = deg_to_rad(ang_c)
	
	# Parâmetros de enquadramento
	var target_base_w: float = 100.0
	var max_h: float = 42.0 # Trava rígida de altura para nunca invadir o topo
	
	# Cálculo da geometria pura
	var denom: float = maxf(0.01, sin(rad_c))
	var raw_side_b: float = (target_base_w * sin(rad_b)) / denom
	var raw_h: float = raw_side_b * sin(rad_a)
	var raw_x_offset: float = raw_side_b * cos(rad_a)
	
	# Escala o triângulo proporcionalmente se ultrapassar a altura máxima
	var scale_factor: float = 1.0
	if raw_h > max_h:
		scale_factor = max_h / raw_h
		
	var base_w: float = target_base_w * scale_factor
	var h: float = raw_h * scale_factor
	var x_offset: float = raw_x_offset * scale_factor
	
	# Rebaixa a linha de base para garantir respiro superior
	var base_y: float = center.y + 22.0
	
	var tri_left := Vector2(center.x - (base_w / 2.0), base_y)
	var tri_right := Vector2(center.x + (base_w / 2.0), base_y)
	var tri_top := Vector2(tri_left.x + x_offset, base_y - h)

	# Linhas do Triângulo
	draw_line(tri_top, tri_left, COLOR_CYAN, 2.0, true)
	draw_line(tri_left, tri_right, COLOR_CYAN, 2.0, true)
	draw_line(tri_right, tri_top, COLOR_CYAN, 2.0, true)
	
	# Arcos dos Ângulos
	draw_arc(tri_left, 12, -rad_a, 0, 10, COLOR_YELLOW, 1.5, true)
	draw_arc(tri_right, 12, PI, PI + rad_b, 10, COLOR_YELLOW, 1.5, true)
	
	# Rótulos externos de alto contraste
	draw_string(font, tri_left + Vector2(-38, 4), str(int(ang_a)) + "°", HORIZONTAL_ALIGNMENT_RIGHT, 32, 12, COLOR_YELLOW)
	draw_string(font, tri_right + Vector2(6, 4), str(int(ang_b)) + "°", HORIZONTAL_ALIGNMENT_LEFT, 32, 12, COLOR_YELLOW)
	draw_string(font, tri_top + Vector2(-20, -8), "x°", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, COLOR_GREEN)