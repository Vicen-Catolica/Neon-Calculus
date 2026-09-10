class_name GameOver
extends CanvasLayer

# Nome da variável alterado para minúsculo (color_rect) e busca pelo nó "CRTOverlay"
@onready var color_rect: ColorRect = find_child("CRTOverlay", true, false)
@onready var center_container: CenterContainer = find_child("CenterContainer", true, false)
@onready var vbox_container: VBoxContainer = find_child("VBoxContainer", true, false)
@onready var title_label: Label = find_child("TitleLabel", true, false)
@onready var button_restart: Button = find_child("ButtonRestart", true, false)
@onready var button_menu: Button = find_child("ButtonMenu", true, false)
@onready var eduardo_sprite: Control = find_child("EduardoSprite", true, false)

var subtitle_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true	
	get_tree().call_group("hud", "hide_hud")

	_create_extra_cyberpunk_elements()
	_apply_visual_styles()
	_connect_signals()
	
	await get_tree().process_frame
	_play_cinematic_intro()

func _create_extra_cyberpunk_elements() -> void:
	if vbox_container and not vbox_container.has_node("SubtitleLabel"):
		subtitle_label = Label.new()
		subtitle_label.name = "SubtitleLabel"
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_container.add_child(subtitle_label)
		if title_label:
			vbox_container.move_child(subtitle_label, title_label.get_index() + 1)
	else:
		subtitle_label = vbox_container.get_node_or_null("SubtitleLabel")

func _apply_visual_styles() -> void:
	# 1. Fundo Avermelhado Escuro
	if color_rect:
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = Color("#070103", 0.0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if center_container:
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if vbox_container:
		vbox_container.add_theme_constant_override("separation", 18)

	# 2. Título "CONEXÃO ENCERRADA"
	if title_label:
		title_label.text = "CONEXÃO ENCERRADA - EXCLUSÃO DE DADOS"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", Color("#ff1e43"))
		title_label.add_theme_color_override("font_outline_color", Color("#5c0011"))
		title_label.add_theme_constant_override("outline_size", 8)
		title_label.add_theme_font_size_override("font_size", 19)

	# 3. Subtítulo (Sera animado como terminal)
	if subtitle_label:
		subtitle_label.text = "ERR_NEURAL_LINK_CRASH // MEMORY_DUMP: COMPLETE\nSISTEMA DESCONECTADO..."
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_color_override("font_color", Color("#a84454"))
		subtitle_label.add_theme_font_size_override("font_size", 10)
		subtitle_label.visible_ratio = 0.0 # Esconde para digitar depois

	# Fontes
	var custom_font: Font = null
	if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf"):
		custom_font = load("res://assets/fonts/Orbitron-Bold.ttf")
		if title_label: title_label.add_theme_font_override("font", custom_font)
		if subtitle_label: subtitle_label.add_theme_font_override("font", custom_font)

	# 4. Botões Cyberpunk
	var style_normal = _create_btn_style(Color("#050e14", 0.9), Color("#00f0ff", 0.7), 1)
	var style_hover = _create_btn_style(Color("#0d2836", 0.95), Color("#5effff"), 2)
	var style_pressed = _create_btn_style(Color("#00f0ff"), Color("#ffffff"), 2)

	for btn in [button_restart, button_menu]:
		if btn:
			btn.custom_minimum_size = Vector2(280, 44)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_pressed)
			
			btn.add_theme_color_override("font_color", Color("#cbebf0"))
			btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
			btn.add_theme_color_override("font_pressed_color", Color("#000000"))
			btn.add_theme_font_size_override("font_size", 13)
			
			if custom_font:
				btn.add_theme_font_override("font", custom_font)
				
			btn.pivot_offset = Vector2(140, 22)
			_setup_button_hover_animations(btn)

func _create_btn_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _setup_button_hover_animations(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

func _play_cinematic_intro() -> void:
	# A. Fade in do fundo
	if color_rect:
		create_tween().tween_property(color_rect, "color:a", 0.94, 0.3)

	# B. Entrada do Menu com Zoom suave
	if vbox_container:
		vbox_container.pivot_offset = vbox_container.size / 2.0
		vbox_container.scale = Vector2(0.9, 0.9)
		vbox_container.modulate.a = 0.0
		
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(vbox_container, "modulate:a", 1.0, 0.35)
		t.tween_property(vbox_container, "scale", Vector2(1.0, 1.0), 0.35)

	# C. Digitação do Subtexto (Typewriter Effect)
	if subtitle_label:
		var type_tween = create_tween()
		type_tween.tween_property(subtitle_label, "visible_ratio", 1.0, 1.1)

	# D. Pulso continuo no Titulo
	if title_label:
		var pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(title_label, "theme_override_colors/font_color", Color("#ff5c75"), 0.7)
		pulse.tween_property(title_label, "theme_override_colors/font_color", Color("#ff1e43"), 0.7)

	# E. Animação de opacidade no sprite do Eduardo no rodapé
	if eduardo_sprite:
		eduardo_sprite.modulate.a = 0.0
		create_tween().tween_property(eduardo_sprite, "modulate:a", 0.7, 0.6)

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
