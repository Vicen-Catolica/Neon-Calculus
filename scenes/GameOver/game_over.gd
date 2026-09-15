class_name GameOver
extends CanvasLayer

@onready var color_rect: ColorRect = find_child("CRTOverlay", true, false)
@onready var center_container: CenterContainer = find_child("CenterContainer", true, false)
@onready var vbox_container: VBoxContainer = find_child("VBoxContainer", true, false)
@onready var title_label: Label = find_child("TitleLabel", true, false)
@onready var button_restart: Button = find_child("ButtonRestart", true, false)
@onready var button_menu: Button = find_child("ButtonMenu", true, false)
@onready var eduardo_sprite: Control = find_child("EduardoSprite", true, false)
@onready var audio_player: AudioStreamPlayer = find_child("AudioStreamPlayer", true, false)

# Cores Cyberpunk do Game Over (Vermelho Neon Intenso)
const NEON_RED := Color("FF1A4B")
const NEON_RED_BRIGHT := Color("FF4D73")
const NEON_RED_DARK := Color("3B0612")
const NEON_RED_BG := Color(0.12, 0.02, 0.04, 0.88)
const NEON_RED_HOVER_BG := Color(0.25, 0.04, 0.08, 0.95)

var subtitle_label: Label
var custom_font: Font = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true    
	get_tree().call_group("hud", "hide_hud")

	if audio_player:
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.play()

	_create_extra_cyberpunk_elements()
	_apply_visual_styles()
	_connect_signals()
	
	await get_tree().process_frame
	_play_cinematic_intro()


func _create_extra_cyberpunk_elements() -> void:
	# Carrega a fonte Orbitron padrão do projeto
	if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf"):
		custom_font = load("res://assets/fonts/Orbitron-Bold.ttf")

	# Subtítulo formatado como alerta de terminal
	if vbox_container and not vbox_container.has_node("SubtitleLabel"):
		subtitle_label = Label.new()
		subtitle_label.name = "SubtitleLabel"
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_container.add_child(subtitle_label)
		if title_label:
			vbox_container.move_child(subtitle_label, title_label.get_index() + 1)
	else:
		subtitle_label = vbox_container.get_node_or_null("SubtitleLabel")

	# HUD decorativo de canto inferior direito (como no Main Menu, mas versão RED ALERT)
	var alert_hud := Label.new()
	alert_hud.name = "AlertHud"
	alert_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	alert_hud.offset_left = -400
	alert_hud.offset_top = -60
	alert_hud.offset_right = -30
	alert_hud.offset_bottom = -20
	alert_hud.text = "CRITICAL_ERROR // CODE: 0xDEAD00\nSIGNAL TERMINATED // PROTOCOL: PURGE"
	alert_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alert_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if custom_font:
		alert_hud.add_theme_font_override("font", custom_font)
		alert_hud.add_theme_font_size_override("font_size", 12)
	alert_hud.add_theme_color_override("font_color", Color(NEON_RED, 0.55))
	add_child(alert_hud)

	# Linha inferior vermelha decorativa
	var red_line := ColorRect.new()
	red_line.name = "RedDecLine"
	red_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	red_line.offset_left = 60
	red_line.offset_top = -14
	red_line.offset_right = -60
	red_line.offset_bottom = -12
	red_line.color = Color(NEON_RED, 0.4)
	add_child(red_line)


func _apply_visual_styles() -> void:
	if color_rect:
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if center_container:
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if vbox_container:
		vbox_container.add_theme_constant_override("separation", 24)

	# Título principal de impacto
	if title_label:
		title_label.text = "CONEXÃO ENCERRADA"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", NEON_RED)
		title_label.add_theme_color_override("font_outline_color", NEON_RED_DARK)
		title_label.add_theme_constant_override("outline_size", 12)
		title_label.add_theme_font_size_override("font_size", 42)
		if custom_font:
			title_label.add_theme_font_override("font", custom_font)

	# Subtítulo estilizado
	if subtitle_label:
		subtitle_label.text = "[ SISTEMA DESCONECTADO // FALHA DO OPERADOR ]\nDADOS CORROMPIDOS NA MEMÓRIA PRINCIPAL"
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_color_override("font_color", Color(NEON_RED_BRIGHT, 0.8))
		subtitle_label.add_theme_font_size_override("font_size", 16)
		subtitle_label.visible_ratio = 0.0
		if custom_font:
			subtitle_label.add_theme_font_override("font", custom_font)

	# Separador neon vermelho abaixo do título
	if vbox_container and not vbox_container.has_node("RedTitleSep"):
		var sep := HSeparator.new()
		sep.name = "RedTitleSep"
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = Color(NEON_RED, 0.45)
		sep_style.content_margin_top = 1
		sep_style.content_margin_bottom = 1
		sep.add_theme_stylebox_override("separator", sep_style)
		sep.add_theme_constant_override("separation", 8)
		vbox_container.add_child(sep)
		if subtitle_label:
			vbox_container.move_child(sep, subtitle_label.get_index() + 1)

	# Estilos dos Botões no padrão visual idêntico ao Main Menu (borda chanfrada, hover com expansão lateral)
	var style_normal = _create_cyberpunk_btn_style(NEON_RED_BG, NEON_RED, 4, 1, 1, 1)
	var style_hover = _create_cyberpunk_btn_style(NEON_RED_HOVER_BG, NEON_RED_BRIGHT, 8, 2, 2, 2)
	var style_pressed = _create_cyberpunk_btn_style(Color(0.35, 0.05, 0.1, 0.98), Color(1.0, 0.9, 0.9), 8, 2, 2, 2)

	# Carrega o glitch shader usado nos botões do Main Menu
	var glitch_shader = load("res://scenes/main_menu/button_glitch.gdshader")

	var btn_names = {
		button_restart: "REINICIAR CHECKPOINT",
		button_menu: "MENU PRINCIPAL"
	}

	for btn in [button_restart, button_menu]:
		if btn:
			if btn in btn_names:
				btn.text = btn_names[btn]
			btn.custom_minimum_size = Vector2(380, 56)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_pressed)
			
			btn.add_theme_color_override("font_color", NEON_RED)
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.88, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
			btn.add_theme_font_size_override("font_size", 24)
			
			if custom_font:
				btn.add_theme_font_override("font", custom_font)

			if glitch_shader:
				var mat := ShaderMaterial.new()
				mat.shader = glitch_shader
				mat.set_shader_parameter("glitch_intensity", 0.0)
				btn.material = mat
				
			btn.pivot_offset = Vector2(190, 28)
			_setup_button_hover_animations(btn)


func _create_cyberpunk_btn_style(bg_color: Color, border_color: Color, border_l: int, border_t: int, border_r: int, border_b: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_l
	style.border_width_top = border_t
	style.border_width_right = border_r
	style.border_width_bottom = border_b
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.expand_margin_left = 20.0
	style.expand_margin_top = 8.0
	style.expand_margin_right = 20.0
	style.expand_margin_bottom = 8.0
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _setup_button_hover_animations(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
		t.tween_property(btn, "modulate", Color(1.3, 1.1, 1.1, 1.0), 0.12)
		t.tween_property(btn, "position:x", btn.position.x + 8.0, 0.12)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
		t.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
		t.tween_property(btn, "position:x", btn.position.x - 8.0, 0.15)
	)


func _play_cinematic_intro() -> void:
	if color_rect:
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(color_rect, "color:a", 0.94, 0.3)

	if vbox_container:
		vbox_container.pivot_offset = vbox_container.size / 2.0
		vbox_container.scale = Vector2(0.92, 0.92)
		vbox_container.modulate.a = 0.0
		
		var t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(vbox_container, "modulate:a", 1.0, 0.4)
		t.tween_property(vbox_container, "scale", Vector2(1.0, 1.0), 0.4)

	if subtitle_label:
		var type_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		type_tween.tween_property(subtitle_label, "visible_ratio", 1.0, 0.9)

	# Pulso contínuo vermelho neon no título
	if title_label:
		var pulse = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(title_label, "theme_override_colors/font_color", NEON_RED_BRIGHT, 0.8)
		pulse.tween_property(title_label, "theme_override_colors/font_color", NEON_RED, 0.8)

	if eduardo_sprite:
		eduardo_sprite.modulate.a = 0.0
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(eduardo_sprite, "modulate:a", 0.7, 0.6)

	_animate_button_glitches()


# Glitch intermitente nos botões vermelhos
func _animate_button_glitches() -> void:
	for btn in [button_restart, button_menu]:
		if btn and btn.material is ShaderMaterial:
			_loop_single_btn_glitch(btn)


func _loop_single_btn_glitch(btn: Button) -> void:
	var mat = btn.material as ShaderMaterial
	if not mat: return

	await get_tree().create_timer(randf_range(0.3, 1.8)).timeout
	while is_instance_valid(btn):
		await get_tree().create_timer(randf_range(1.5, 4.0)).timeout
		if not is_instance_valid(btn): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.5, 0.9))
		await get_tree().create_timer(randf_range(0.04, 0.10)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)


func _connect_signals() -> void:
	if button_restart and not button_restart.pressed.is_connected(_on_restart_pressed):
		button_restart.pressed.connect(_on_restart_pressed)

	if button_menu and not button_menu.pressed.is_connected(_on_menu_pressed):
		button_menu.pressed.connect(_on_menu_pressed)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	queue_free()
	if ResourceLoader.exists("res://scenes/main_menu/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	else:
		get_tree().reload_current_scene()