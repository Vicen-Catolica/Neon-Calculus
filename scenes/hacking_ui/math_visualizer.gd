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
	
	# Equações (níveis 1, 2, 4.0 e 5): balança em equilíbrio. Geometria e
	# proporção (3 e 4.1) continuam com o desenho da figura.
	var sides := scale_sides()
	if not sides.is_empty():
		_draw_balance(draw_size, font, sides[0], sides[1])
		return
	match current_stage:
		3:
			if current_subtopic == 0:
				_draw_clean_ratio_cross(center, font)
			else:
				_draw_clean_geometry_rectangle(center, font)
		4:
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

# --- STAGE 3 (TEMA 0): REGRA DE TRÊS ---
# x / base = num / den, desenhado como duas frações (a multiplicação cruzada
# fica no passo a passo da SINE).
func _draw_clean_ratio_cross(center: Vector2, font: Font) -> void:
	var base_val: int = int(eq_data.get("ParamBase", 3))
	var right_num: int = int(eq_data.get("ParamRightNum", 12))
	var right_den: int = int(eq_data.get("ParamRightDen", 6))
	var lx := center.x - 50.0
	var rx := center.x + 50.0
	var w := 44.0
	# frações
	draw_string(font, Vector2(lx - w / 2.0, center.y - 8), "x", HORIZONTAL_ALIGNMENT_CENTER, w, 18, COLOR_GREEN)
	draw_line(Vector2(lx - w / 2.0, center.y), Vector2(lx + w / 2.0, center.y), COLOR_CYAN, 2.0)
	draw_string(font, Vector2(lx - w / 2.0, center.y + 22), str(base_val), HORIZONTAL_ALIGNMENT_CENTER, w, 18, COLOR_CYAN)
	draw_string(font, Vector2(center.x - 15, center.y + 7), "=", HORIZONTAL_ALIGNMENT_CENTER, 30, 20, COLOR_CYAN)
	draw_string(font, Vector2(rx - w / 2.0, center.y - 8), str(right_num), HORIZONTAL_ALIGNMENT_CENTER, w, 18, COLOR_CYAN)
	draw_line(Vector2(rx - w / 2.0, center.y), Vector2(rx + w / 2.0, center.y), COLOR_CYAN, 2.0)
	draw_string(font, Vector2(rx - w / 2.0, center.y + 22), str(right_den), HORIZONTAL_ALIGNMENT_CENTER, w, 18, COLOR_CYAN)

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
	var alt_text := "ALTURA = " + str(int(altura))
	var alt_x: float = rect.position.x - 105.0
	draw_string(font, Vector2(alt_x, center.y + 5.0), alt_text, HORIZONTAL_ALIGNMENT_RIGHT, 95.0, 12, COLOR_YELLOW)

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


# --- BALANÇA EM EQUILÍBRIO (equações) -----------------------------------------
# Cada prato é um lado da equação: caixas "x" (ciano) e pesos com número
# (amarelo; vermelho quando é para tirar). k(x + a) vira k grupos [x a].
# A ideia que a criança precisa ver: a balança está equilibrada, e tirar (ou
# pôr) o mesmo dos dois pratos mantém o equilíbrio.

const COLOR_RED := Color("#ff4d6d")
const MAX_BOXES := 6

## Itens de cada prato: [esquerdo, direito]; vazio se o tipo não usa balança.
## Item: {"t": "x", "n": quantas caixas} | {"t": "n", "v": número} |
##       {"t": "g", "k": vezes, "a": número}  (k grupos de x + a)
func scale_sides() -> Array:
	match current_stage:
		1:
			var a := int(eq_data.get("ParamA", 0))
			var res := int(eq_data.get("ParamRes", 0))
			if current_subtopic == 0:
				return [[{"t": "x", "n": 1}, {"t": "n", "v": a}], [{"t": "n", "v": res}]]
			return [[{"t": "x", "n": a}], [{"t": "n", "v": res}]]
		2:
			return [[{"t": "x", "n": int(eq_data.get("ParamMult", 1))}, {"t": "n", "v": int(eq_data.get("ParamB", 0))}],
				[{"t": "n", "v": int(eq_data.get("ParamTotal", 0))}]]
		4:
			if current_subtopic == 0:
				return [[{"t": "g", "k": int(eq_data.get("ParamK", 2)), "a": int(eq_data.get("ParamOffset", 0))}],
					[{"t": "n", "v": int(eq_data.get("ParamTotal", 0))}]]
		5:
			var c := int(eq_data.get("ParamC", 1))
			if current_subtopic == 1:
				return [[{"t": "g", "k": int(eq_data.get("ParamK", 2)), "a": int(eq_data.get("ParamM", 1))}],
					[{"t": "x", "n": c}, {"t": "n", "v": int(eq_data.get("ParamN", 0))}]]
			return [[{"t": "x", "n": int(eq_data.get("ParamA", 2))}, {"t": "n", "v": int(eq_data.get("ParamB", 0))}],
				[{"t": "x", "n": c}, {"t": "n", "v": int(eq_data.get("ParamD", 0))}]]
	return []


func _draw_balance(draw_size: Vector2, font: Font, left: Array, right: Array) -> void:
	var cx := draw_size.x / 2.0
	var beam_y := 30.0
	var pan_y := draw_size.y - 34.0
	var half := minf(draw_size.x * 0.27, 170.0)
	# legenda
	draw_string(font, Vector2(0, 16), "BALANÇA EM EQUILÍBRIO: os dois lados valem o mesmo", HORIZONTAL_ALIGNMENT_CENTER, draw_size.x, 11, COLOR_MUTED)
	# coluna e base
	draw_line(Vector2(cx, beam_y), Vector2(cx, draw_size.y - 10), COLOR_MUTED, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 22, draw_size.y - 4), Vector2(cx + 22, draw_size.y - 4), Vector2(cx, draw_size.y - 18)]), Color(COLOR_MUTED, 0.8))
	# travessão
	draw_line(Vector2(cx - half, beam_y), Vector2(cx + half, beam_y), COLOR_CYAN, 3.0)
	draw_circle(Vector2(cx, beam_y), 4.0, COLOR_YELLOW)
	# "=" no meio, para ligar a balança à equação
	draw_string(font, Vector2(cx - 20, pan_y - 10), "=", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, COLOR_YELLOW)
	for side in [-1.0, 1.0]:
		var px: float = cx + half * side
		var pan_w := half * 1.15
		# cordas e prato
		draw_line(Vector2(px, beam_y), Vector2(px - pan_w / 2.0, pan_y), Color(COLOR_MUTED, 0.9), 1.0)
		draw_line(Vector2(px, beam_y), Vector2(px + pan_w / 2.0, pan_y), Color(COLOR_MUTED, 0.9), 1.0)
		draw_line(Vector2(px - pan_w / 2.0 - 6, pan_y), Vector2(px + pan_w / 2.0 + 6, pan_y), COLOR_CYAN, 3.0)
		draw_line(Vector2(px - pan_w / 2.0 + 6, pan_y + 6), Vector2(px + pan_w / 2.0 - 6, pan_y + 6), Color(COLOR_CYAN, 0.5), 2.0)
		var items: Array = left if side < 0 else right
		_draw_pan_items(font, items, px, pan_y - 2.0, pan_w)
		# o lado da equação escrito embaixo do prato
		draw_string(font, Vector2(px - pan_w / 2.0, pan_y + 24), side_label(items), HORIZONTAL_ALIGNMENT_CENTER, pan_w, 14, COLOR_GREEN if side < 0 else COLOR_YELLOW)


## Texto do lado (ex.: "4x - 2", "3(x + 4)", "22").
func side_label(items: Array) -> String:
	var parts: Array[String] = []
	for it in items:
		match String(it["t"]):
			"x":
				var n := int(it["n"])
				parts.append("x" if n == 1 else "%dx" % n)
			"g":
				var a := int(it["a"])
				parts.append("%d(x %s %d)" % [int(it["k"]), "+" if a >= 0 else "-", absi(a)])
			"n":
				var v := int(it["v"])
				if v == 0 and not parts.is_empty():
					continue
				if parts.is_empty():
					parts.append(str(v))
				else:
					parts.append(("+ %d" if v > 0 else "- %d") % absi(v))
	return " ".join(parts)


func _item_width(it: Dictionary) -> float:
	match String(it["t"]):
		"x":
			var n := int(it["n"])
			return 30.0 if n > MAX_BOXES else n * 26.0 - 4.0
		"g":
			var k := int(it["k"])
			return 50.0 * mini(k, 4) + (30.0 if k > 4 else 0.0)
		"n":
			return 0.0 if int(it["v"]) == 0 else 40.0
	return 0.0


func _draw_pan_items(font: Font, items: Array, px: float, base_y: float, pan_w: float) -> void:
	var total := 0.0
	var shown: Array = []
	for it in items:
		var w := _item_width(it)
		if w > 0.0:
			shown.append(it)
			total += w + 8.0
	total -= 8.0
	var x := px - total / 2.0
	for it in shown:
		var w := _item_width(it)
		match String(it["t"]):
			"x":
				_draw_x_boxes(font, int(it["n"]), x, base_y)
			"n":
				_draw_weight(font, int(it["v"]), x, base_y)
			"g":
				_draw_groups(font, int(it["k"]), int(it["a"]), x, base_y)
		x += w + 8.0


func _draw_x_boxes(font: Font, n: int, x: float, base_y: float) -> void:
	if n > MAX_BOXES:
		# muitas caixas: uma só, com a quantidade
		var r := Rect2(x, base_y - 30, 30, 30)
		draw_rect(r, Color(COLOR_CYAN, 0.18))
		draw_rect(r, COLOR_CYAN, false, 2.0)
		draw_string(font, Vector2(x, base_y - 9), "%dx" % n, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, COLOR_CYAN)
		return
	for i in n:
		var r := Rect2(x + i * 26.0, base_y - 22, 22, 22)
		draw_rect(r, Color(COLOR_CYAN, 0.18))
		draw_rect(r, COLOR_CYAN, false, 2.0)
		draw_string(font, Vector2(r.position.x, base_y - 6), "x", HORIZONTAL_ALIGNMENT_CENTER, 22, 14, COLOR_CYAN)


## Peso com o número (trapézio, como um peso de balança). Negativo: vermelho e
## com "-" (é o que está sendo tirado daquele lado).
func _draw_weight(font: Font, v: int, x: float, base_y: float) -> void:
	var col := COLOR_YELLOW if v > 0 else COLOR_RED
	var w := 40.0
	var h := 26.0
	var pts := PackedVector2Array([Vector2(x, base_y), Vector2(x + w, base_y), Vector2(x + w - 6, base_y - h), Vector2(x + 6, base_y - h)])
	draw_colored_polygon(pts, Color(col, 0.2))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.0)
	draw_arc(Vector2(x + w / 2.0, base_y - h - 3), 5.0, PI, TAU, 8, col, 2.0)
	draw_string(font, Vector2(x, base_y - 7), (str(v) if v > 0 else "-" + str(-v)), HORIZONTAL_ALIGNMENT_CENTER, w, 13, col)


## k grupos [x a] (propriedade distributiva): cada grupo numa bandeja.
func _draw_groups(font: Font, k: int, a: int, x: float, base_y: float) -> void:
	var shown := mini(k, 4)
	var gw := 50.0
	for i in shown:
		var gx := x + i * gw
		var tray := Rect2(gx, base_y - 30, gw - 6, 30)
		draw_rect(tray, Color(COLOR_GREEN, 0.07))
		draw_rect(tray, Color(COLOR_GREEN, 0.7), false, 1.0)
		var r := Rect2(gx + 3, base_y - 23, 18, 18)
		draw_rect(r, Color(COLOR_CYAN, 0.18))
		draw_rect(r, COLOR_CYAN, false, 2.0)
		draw_string(font, Vector2(r.position.x, base_y - 9), "x", HORIZONTAL_ALIGNMENT_CENTER, 18, 11, COLOR_CYAN)
		var col := COLOR_YELLOW if a >= 0 else COLOR_RED
		draw_string(font, Vector2(gx + 22, base_y - 9), ("+" if a >= 0 else "-") + str(absi(a)), HORIZONTAL_ALIGNMENT_CENTER, gw - 28, 11, col)
	if k > 4:
		draw_string(font, Vector2(x + shown * gw, base_y - 9), "×%d" % k, HORIZONTAL_ALIGNMENT_LEFT, 40, 13, COLOR_GREEN)

