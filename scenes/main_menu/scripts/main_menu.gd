extends Control

@export_file("*.tscn") var start_scene: String = "res://scenes/Stage1/stage1.tscn"
@export_file("*.tscn") var option_scene: String = "res://scenes/options/OptionsMenu.tscn"

# ── Cores Cyberpunk ──
const NEON_CYAN := Color("00FBFC")
const NEON_CYAN_DIM := Color("00FBFC", 0.45)
const NEON_GREEN := Color("5AE300")
const DARK_BG := Color(0.018, 0.038, 0.075, 0.88)
const DARK_PANEL_BG := Color(0.01, 0.02, 0.045, 0.94)
const BTN_NORMAL_BG := Color(0.025, 0.05, 0.09, 0.85)
const BTN_HOVER_BG := Color(0.05, 0.16, 0.10, 0.9)
const BTN_PRESSED_BG := Color(0.08, 0.24, 0.14, 0.95)

# ── Nós da Cena ──
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var bgm: AudioStreamPlayer = get_node_or_null("BGM")
@onready var hover_sfx: AudioStreamPlayer = get_node_or_null("HoverSFX")
@onready var click_sfx: AudioStreamPlayer = get_node_or_null("ClickSFX")
@onready var logo: TextureRect = get_node_or_null("Logo")

var options_menu_instance: Control = null
var terminal_panel: PanelContainer = null
var hud_elements: Array[Control] = []
var _font: Font = null
var _logo_base_scale: Vector2 = Vector2(0.55, 0.55)
var _btn_tweens: Dictionary = {}


func _ready() -> void:
	_font = load("res://assets/fonts/Orbitron-Bold.ttf")
	
	_create_crt_overlay()
	_create_hud_frames_and_brackets()
	_build_terminal_console()
	_create_logo_enhancements()
	_setup_buttons()
	_setup_options_menu()
	_animate_logo()
	_animate_logo_glow_pulse()
	_animate_buttons_glitch()
	_play_music_with_fade_in()

	await get_tree().process_frame
	_animate_intro()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  1. CRT OVERLAY CYBERPUNK (Scanlines, Vinheta, Grão)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _create_crt_overlay() -> void:
	var crt_shader = load("res://scenes/GameOver/crt_cyberpunk.gdshader")
	if not crt_shader:
		return

	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = crt_shader
	crt_mat.set_shader_parameter("scanline_count", 380.0)
	crt_mat.set_shader_parameter("scanline_intensity", 0.12)
	crt_mat.set_shader_parameter("noise_amount", 0.018)
	crt_mat.set_shader_parameter("vignette_intensity", 0.45)
	crt_mat.set_shader_parameter("static_flicker", 0.012)

	var crt := ColorRect.new()
	crt.name = "CRTOverlay"
	crt.material = crt_mat
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  2. MOLDURA TÁTICA HUD & TELEMETRIA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _create_hud_frames_and_brackets() -> void:
	# Linha Superior Neon Ciano
	var top_line := ColorRect.new()
	top_line.name = "TopDecLine"
	top_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_left = 40
	top_line.offset_top = 28
	top_line.offset_right = -40
	top_line.offset_bottom = 30
	top_line.color = Color(NEON_CYAN, 0.3)
	add_child(top_line)
	hud_elements.append(top_line)

	# Linha Inferior Neon Ciano
	var btm_line := ColorRect.new()
	btm_line.name = "BtmDecLine"
	btm_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btm_line.offset_left = 40
	btm_line.offset_top = -30
	btm_line.offset_right = -40
	btm_line.offset_bottom = -28
	btm_line.color = Color(NEON_CYAN, 0.3)
	add_child(btm_line)
	hud_elements.append(btm_line)

	# Telemetria Superior Esquerda
	var top_left_lbl := Label.new()
	top_left_lbl.name = "TopLeftTelemetry"
	top_left_lbl.offset_left = 50
	top_left_lbl.offset_top = 8
	top_left_lbl.text = "[ SEC-SYS // AUTH: LVL_5 ]   NODE: CALCULUS-PRIME"
	_apply_font_style(top_left_lbl, 11, Color(NEON_CYAN, 0.6))
	add_child(top_left_lbl)
	hud_elements.append(top_left_lbl)

	# Telemetria Superior Direita
	var top_right_lbl := Label.new()
	top_right_lbl.name = "TopRightTelemetry"
	top_right_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_lbl.offset_left = -460
	top_right_lbl.offset_top = 8
	top_right_lbl.offset_right = -50
	top_right_lbl.offset_bottom = 26
	top_right_lbl.text = "DATALINK: ESTABELECIDO   |   PING: 14ms   |   FPS: 60"
	top_right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font_style(top_right_lbl, 11, Color(NEON_CYAN, 0.6))
	add_child(top_right_lbl)
	hud_elements.append(top_right_lbl)

	# Rodapé Esquerdo (Créditos / Versão)
	var btm_left_lbl := Label.new()
	btm_left_lbl.name = "BtmLeftCredits"
	btm_left_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btm_left_lbl.offset_left = 50
	btm_left_lbl.offset_top = -24
	btm_left_lbl.text = "NEON CALCULUS  v1.0.4  //  PROJETO EXPERIMENTAL"
	_apply_font_style(btm_left_lbl, 11, Color(NEON_CYAN, 0.45))
	add_child(btm_left_lbl)
	hud_elements.append(btm_left_lbl)

	# Rodapé Direito (Status do Sistema)
	var sys_info := Label.new()
	sys_info.name = "SysInfoLabel"
	sys_info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sys_info.offset_left = -400
	sys_info.offset_top = -24
	sys_info.offset_right = -50
	sys_info.offset_bottom = -6
	sys_info.text = "CALCULUS CORE // PRONTO  [ ONLINE ]"
	sys_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font_style(sys_info, 11, Color(NEON_GREEN, 0.8))
	add_child(sys_info)
	hud_elements.append(sys_info)

	# Cantoneiras Táticas nos 4 Cantos da Tela
	_create_corner_bracket(Vector2(20, 16), false, false)
	_create_corner_bracket(Vector2(-20, 16), true, false)
	_create_corner_bracket(Vector2(20, -16), false, true)
	_create_corner_bracket(Vector2(-20, -16), true, true)


func _create_corner_bracket(pos: Vector2, right: bool, bottom: bool) -> void:
	var bracket := Control.new()
	bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		bracket.set_anchors_preset(Control.PRESET_TOP_RIGHT if not bottom else Control.PRESET_BOTTOM_RIGHT)
	else:
		bracket.set_anchors_preset(Control.PRESET_TOP_LEFT if not bottom else Control.PRESET_BOTTOM_LEFT)
	bracket.position = pos

	# Traço horizontal
	var h_line := ColorRect.new()
	h_line.size = Vector2(24, 2)
	h_line.position = Vector2(-24 if right else 0, -2 if bottom else 0)
	h_line.color = Color(NEON_CYAN, 0.7)
	bracket.add_child(h_line)

	# Traço vertical
	var v_line := ColorRect.new()
	v_line.size = Vector2(2, 24)
	v_line.position = Vector2(-2 if right else 0, -24 if bottom else 0)
	v_line.color = Color(NEON_CYAN, 0.7)
	bracket.add_child(v_line)

	add_child(bracket)
	hud_elements.append(bracket)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  3. TERMINAL CONSOLE GLASSMORPHIC (Painel dos Botões)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _build_terminal_console() -> void:
	terminal_panel = PanelContainer.new()
	terminal_panel.name = "TerminalConsole"
	
	# Posicionamento à esquerda, abaixo da Logo
	terminal_panel.offset_left = 60
	terminal_panel.offset_top = 370
	terminal_panel.offset_right = 530
	terminal_panel.offset_bottom = 980
	terminal_panel.custom_minimum_size = Vector2(470, 610)

	# Estilo do Painel (Glassmorphism Cyberpunk)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = DARK_PANEL_BG
	panel_style.border_width_left = 4
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(NEON_CYAN, 0.5)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.shadow_color = Color(NEON_CYAN, 0.08)
	panel_style.shadow_size = 20
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	terminal_panel.add_theme_stylebox_override("panel", panel_style)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 18)
	terminal_panel.add_child(content_vbox)

	# Cabeçalho do Terminal
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	
	var header_title := Label.new()
	header_title.text = "// CONSOLE DE ACESSO //"
	_apply_font_style(header_title, 14, NEON_CYAN)
	header_hbox.add_child(header_title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)

	var status_dot := Label.new()
	status_dot.name = "StatusDot"
	status_dot.text = "● ONLINE"
	_apply_font_style(status_dot, 12, NEON_GREEN)
	header_hbox.add_child(status_dot)
	_animate_status_pulse(status_dot)

	content_vbox.add_child(header_hbox)

	# Separador Neon Ciano
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(NEON_CYAN, 0.4)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	content_vbox.add_child(sep)

	# Reparent do MenuContainer existente para dentro do Terminal
	if menu_container:
		menu_container.get_parent().remove_child(menu_container)
		content_vbox.add_child(menu_container)
		menu_container.add_theme_constant_override("separation", 16)
		menu_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		menu_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Separador Inferior
	var btm_sep := HSeparator.new()
	var btm_sep_style := StyleBoxFlat.new()
	btm_sep_style.bg_color = Color(NEON_CYAN, 0.25)
	btm_sep.add_theme_stylebox_override("separator", btm_sep_style)
	content_vbox.add_child(btm_sep)

	# Rodapé do Terminal
	var footer_hbox := HBoxContainer.new()
	var terminal_id := Label.new()
	terminal_id.text = "ID: NC-07 // CÁLCULO CORE"
	_apply_font_style(terminal_id, 11, Color(NEON_CYAN, 0.5))
	footer_hbox.add_child(terminal_id)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(footer_spacer)

	var sys_ready := Label.new()
	sys_ready.text = "PROTOCOLO: ATIVO"
	_apply_font_style(sys_ready, 11, Color(NEON_GREEN, 0.7))
	footer_hbox.add_child(sys_ready)
	content_vbox.add_child(footer_hbox)

	add_child(terminal_panel)



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  5. MELHORIAS E SUBTÍTULO DA LOGO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _create_logo_enhancements() -> void:
	if not logo:
		return
	
	_logo_base_scale = logo.scale

	# Subtítulo formatado em baixo da logo
	var subtitle := Label.new()
	subtitle.name = "LogoSubtitle"
	subtitle.text = "// PROTOCOLO TÁTICO MATEMÁTICO //"
	_apply_font_style(subtitle, 13, Color(NEON_CYAN, 0.75))
	subtitle.offset_left = logo.offset_left + 10
	subtitle.offset_top = logo.offset_top + (logo.size.y * logo.scale.y) + 6
	add_child(subtitle)
	hud_elements.append(subtitle)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  6. ESTILIZAÇÃO E CONEXÃO DOS BOTÕES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _setup_buttons() -> void:
	var button_configs = {
		"BtnStart": "[ 01 ]  INICIAR",
		"BtnContinue": "[ 02 ]  CONTINUAR",
		"BtnOptions": "[ 03 ]  OPÇÕES",
		"BtnExit": "[ 04 ]  SAIR"
	}

	for btn in menu_container.get_children():
		if btn is Button:
			if btn.name in button_configs:
				btn.text = button_configs[btn.name]

			btn.custom_minimum_size = Vector2(0, 58)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pivot_offset = Vector2(200, 29)

			_apply_button_styles(btn)

			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			btn.pressed.connect(_on_btn_pressed.bind(btn))


func _apply_button_styles(btn: Button) -> void:
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 20)

	btn.add_theme_color_override("font_color", NEON_CYAN)
	btn.add_theme_color_override("font_hover_color", NEON_GREEN)
	btn.add_theme_color_override("font_pressed_color", NEON_GREEN)
	btn.add_theme_color_override("font_focus_color", NEON_CYAN)

	# Normal
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = BTN_NORMAL_BG
	normal_style.border_width_left = 6
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = NEON_CYAN
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.content_margin_left = 22
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal_style)

	# Hover
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = BTN_HOVER_BG
	hover_style.border_width_left = 8
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = NEON_GREEN
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.shadow_color = Color(NEON_GREEN, 0.25)
	hover_style.shadow_size = 10
	hover_style.content_margin_left = 34
	hover_style.content_margin_right = 20
	hover_style.content_margin_top = 12
	hover_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = BTN_PRESSED_BG
	pressed_style.border_width_left = 8
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = NEON_GREEN
	pressed_style.corner_radius_top_left = 6
	pressed_style.corner_radius_top_right = 6
	pressed_style.corner_radius_bottom_right = 6
	pressed_style.corner_radius_bottom_left = 6
	pressed_style.content_margin_left = 26
	pressed_style.content_margin_right = 20
	pressed_style.content_margin_top = 12
	pressed_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Focus
	btn.add_theme_stylebox_override("focus", hover_style)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  7. ANIMAÇÃO DE ENTRADA SUAVE (INTRO)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _animate_intro() -> void:
	# Painel do Terminal surge deslizando da esquerda
	if terminal_panel:
		var target_x: float = terminal_panel.position.x
		terminal_panel.modulate.a = 0.0
		terminal_panel.position.x = target_x - 50.0
		var t1 = create_tween().set_parallel(true)
		t1.tween_property(terminal_panel, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t1.tween_property(terminal_panel, "position:x", target_x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Botões entram de forma escalonada (fade e leve escala, sem mover position dentro do container)
	var delay: float = 0.18
	for btn in menu_container.get_children():
		if btn is Button:
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.96, 0.96)
			
			var tween = create_tween().set_parallel(true)
			tween.tween_property(btn, "modulate:a", 1.0, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay += 0.07


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  8. INTERAÇÃO E EVENTOS DE BOTÕES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_btn_hover(btn: Button) -> void:
	_play_hover_sfx()
	if _btn_tweens.has(btn) and is_instance_valid(_btn_tweens[btn]):
		_btn_tweens[btn].kill()

	if btn.size.x > 0 and btn.size.y > 0:
		btn.pivot_offset = btn.size / 2.0

	var tween = create_tween().set_parallel(true)
	_btn_tweens[btn] = tween
	tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.1)


func _on_btn_unhover(btn: Button) -> void:
	if _btn_tweens.has(btn) and is_instance_valid(_btn_tweens[btn]):
		_btn_tweens[btn].kill()

	var tween = create_tween().set_parallel(true)
	_btn_tweens[btn] = tween
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


func _on_btn_pressed(btn: Button) -> void:
	_play_click_sfx()
	
	if _btn_tweens.has(btn) and is_instance_valid(_btn_tweens[btn]):
		_btn_tweens[btn].kill()

	var click_tween = create_tween()
	_btn_tweens[btn] = click_tween
	click_tween.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.06)
	click_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

	match btn.name:
		"BtnStart":
			_change_scene_with_fade(start_scene)
		"BtnContinue":
			pass
		"BtnOptions":
			_open_options()
		"BtnExit":
			get_tree().quit()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  9. MENU DE OPÇÕES (OVERLAY COM FADE COMPLETO)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _setup_options_menu() -> void:
	if option_scene and ResourceLoader.exists(option_scene):
		var scene_res = load(option_scene)
		options_menu_instance = scene_res.instantiate()
		add_child(options_menu_instance)
		options_menu_instance.hide()
		
		if options_menu_instance.has_signal("menu_closed"):
			options_menu_instance.menu_closed.connect(_on_options_closed)


func _open_options() -> void:
	if options_menu_instance:
		var tween = create_tween().set_parallel(true)
		if terminal_panel:
			tween.tween_property(terminal_panel, "modulate:a", 0.0, 0.18)
		if logo:
			tween.tween_property(logo, "modulate:a", 0.0, 0.18)
		for h in hud_elements:
			if is_instance_valid(h):
				tween.tween_property(h, "modulate:a", 0.0, 0.18)

		await tween.finished
		
		if terminal_panel: terminal_panel.hide()
		if logo: logo.hide()

		options_menu_instance.modulate.a = 0.0
		options_menu_instance.show()
		var in_tween = create_tween()
		in_tween.tween_property(options_menu_instance, "modulate:a", 1.0, 0.22)
	else:
		_change_scene_with_fade(option_scene)


func _on_options_closed() -> void:
	if terminal_panel:
		terminal_panel.show()
		terminal_panel.modulate.a = 1.0
	if logo:
		logo.show()
		logo.modulate.a = 1.0
	for h in hud_elements:
		if is_instance_valid(h):
			h.modulate.a = 1.0

	_animate_intro()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  10. ÁUDIO, SFX E TRANSIÇÕES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_hover_sfx() -> void:
	if hover_sfx and hover_sfx.stream:
		hover_sfx.stop()
		hover_sfx.pitch_scale = randf_range(0.96, 1.04)
		hover_sfx.play()


func _play_click_sfx() -> void:
	if click_sfx and click_sfx.stream:
		click_sfx.stop()
		click_sfx.play()


func _play_music_with_fade_in() -> void:
	if bgm and bgm.stream:
		bgm.volume_db = -80.0
		bgm.play()
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -6.0, 1.5)


func _change_scene_with_fade(target_scene: String) -> void:
	if bgm and bgm.playing:
		var tween = create_tween()
		tween.tween_property(bgm, "volume_db", -80.0, 0.3)
		await tween.finished
	get_tree().change_scene_to_file(target_scene)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  11. PULSO DA LOGO E GLITCH SHADERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _animate_logo_glow_pulse() -> void:
	if not logo: return

	var pulse = create_tween().set_loops()
	pulse.tween_property(logo, "scale", _logo_base_scale * 1.02, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(logo, "modulate", Color(1.15, 1.15, 1.25, 1.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(logo, "scale", _logo_base_scale, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(logo, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_logo() -> void:
	if not logo: return
	var mat = logo.material as ShaderMaterial
	if not mat: return

	while is_instance_valid(logo):
		await get_tree().create_timer(randf_range(2.0, 4.5)).timeout
		if not is_instance_valid(logo): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.5, 0.9))
		await get_tree().create_timer(randf_range(0.05, 0.12)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)


func _animate_buttons_glitch() -> void:
	for btn in menu_container.get_children():
		if btn is Button:
			if btn.material:
				btn.material = btn.material.duplicate()
			_loop_button_glitch(btn)


func _loop_button_glitch(btn: Button) -> void:
	var mat = btn.material as ShaderMaterial
	if not mat: return
	
	await get_tree().create_timer(randf_range(0.3, 2.5)).timeout
	
	while is_instance_valid(btn):
		await get_tree().create_timer(randf_range(2.0, 6.0)).timeout
		if not is_instance_valid(btn): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.4, 0.8))
		await get_tree().create_timer(randf_range(0.04, 0.09)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)


func _animate_status_pulse(lbl: Label) -> void:
	var pulse = create_tween().set_loops()
	pulse.tween_property(lbl, "modulate:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(lbl, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  12. UTILITÁRIOS DE ESTILO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _apply_font_style(lbl: Label, font_sz: int, color: Color) -> void:
	if _font:
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", color)