extends Control

signal menu_closed

# ── Cores do tema cyberpunk (iguais ao Main Menu) ──
const NEON_CYAN := Color("00FBFC")
const NEON_GREEN := Color("5AE300")
const DARK_BG := Color(0.02, 0.04, 0.08, 0.92)
const DARK_BG_LIGHT := Color(0.037, 0.076, 0.11, 0.7)
const DARK_GREEN_BG := Color(0.058, 0.149, 0.094, 0.78)

# ── Referências de nós ──
@onready var master_slider: HSlider = %MasterSlider
@onready var bgm_slider: HSlider = %BgmSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var voice_slider: HSlider = %VoiceSlider
@onready var display_option: OptionButton = %DisplayOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var colorblind_option: OptionButton = %ColorblindOption
@onready var equation_size_option: OptionButton = %EquationSizeOption
@onready var controls_list: VBoxContainer = %ControlsList

# ── Estado do rebinding de controles ──
var pending_controls: Dictionary = {}
var rebinding_action: String = ""
var rebinding_button: Button = null
var action_buttons: Dictionary = {}
var _font: Font


func _ready() -> void:
	_apply_cyberpunk_theme()
	_setup_ui_options()
	_load_current_values()
	_setup_controls_tab()
	_connect_audio_signals()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  TEMA CYBERPUNK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _apply_cyberpunk_theme() -> void:
	_font = load("res://assets/fonts/Orbitron-Bold.ttf")

	# ── Imagem de fundo (por trás do overlay) ──
	var bg_tex = load("res://assets/images/Background.jpg")
	if bg_tex and not has_node("BackgroundImage"):
		var bg := TextureRect.new()
		bg.name = "BackgroundImage"
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.35, 0.35, 0.45, 1.0)
		add_child(bg)
		move_child(bg, 0)

	# ── Overlay escuro ──
	var overlay := get_node_or_null("ColorRect")
	if overlay:
		overlay.color = Color(0.01, 0.02, 0.04, 0.78)

	# ── Painel central ──
	var panel := get_node_or_null("ColorRect/PanelContainer")
	if panel:
		var s := StyleBoxFlat.new()
		s.bg_color = DARK_BG
		s.set_border_width_all(2)
		s.border_color = Color(NEON_CYAN, 0.45)
		s.set_corner_radius_all(16)
		s.content_margin_left = 40
		s.content_margin_right = 40
		s.content_margin_top = 30
		s.content_margin_bottom = 30
		s.shadow_color = Color(NEON_CYAN, 0.06)
		s.shadow_size = 16
		panel.add_theme_stylebox_override("panel", s)

	# ── Espaçamento do VBox principal ──
	var vbox := get_node_or_null("ColorRect/PanelContainer/MarginContainer/VBoxContainer")
	if vbox:
		vbox.add_theme_constant_override("separation", 16)

	# ── Título ──
	var title := get_node_or_null("ColorRect/PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	if title:
		title.add_theme_font_override("font", _font)
		title.add_theme_font_size_override("font_size", 38)
		title.add_theme_color_override("font_color", NEON_CYAN)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── Separador abaixo do título ──
	if vbox and not vbox.has_node("TitleSeparator"):
		var sep := HSeparator.new()
		sep.name = "TitleSeparator"
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = Color(NEON_CYAN, 0.3)
		sep_style.content_margin_top = 1
		sep_style.content_margin_bottom = 1
		sep.add_theme_stylebox_override("separator", sep_style)
		sep.add_theme_constant_override("separation", 4)
		vbox.add_child(sep)
		vbox.move_child(sep, 1)

	# ── TabContainer ──
	_style_tab_container()

	# ── Espaçamento dentro de cada aba e estilo dos labels ──
	var tc = get_node_or_null("ColorRect/PanelContainer/MarginContainer/VBoxContainer/TabContainer")
	if tc:
		for child in tc.get_children():
			if child is VBoxContainer:
				child.add_theme_constant_override("separation", 20)
		_style_labels_recursive(tc)

	# ── OptionButtons ──
	for ob in [display_option, resolution_option, colorblind_option, equation_size_option]:
		if ob:
			_style_option_button(ob)

	# ── CheckBox ──
	if vsync_check:
		_style_check_box(vsync_check)

	# ── Sliders ──
	for sl in [master_slider, bgm_slider, sfx_slider, voice_slider]:
		if sl:
			_style_slider(sl)

	# ── Botões do rodapé ──
	var footer := get_node_or_null("ColorRect/PanelContainer/MarginContainer/VBoxContainer/FooterButtons")
	if footer:
		footer.add_theme_constant_override("separation", 24)
		for child in footer.get_children():
			if child is Button:
				child.pivot_offset = Vector2(100, 25)
				_style_footer_button(child)


func _style_tab_container() -> void:
	var tc := get_node_or_null("ColorRect/PanelContainer/MarginContainer/VBoxContainer/TabContainer")
	if not tc:
		return

	tc.add_theme_font_override("font", _font)
	tc.add_theme_font_size_override("font_size", 18)
	tc.add_theme_color_override("font_selected_color", NEON_CYAN)
	tc.add_theme_color_override("font_unselected_color", Color(NEON_CYAN, 0.35))
	tc.add_theme_color_override("font_hovered_color", NEON_GREEN)

	# Aba selecionada
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.02, 0.06, 0.12, 0.9)
	sel.border_width_top = 3
	sel.border_width_left = 1
	sel.border_width_right = 1
	sel.border_color = NEON_CYAN
	sel.corner_radius_top_left = 8
	sel.corner_radius_top_right = 8
	sel.content_margin_left = 20
	sel.content_margin_right = 20
	sel.content_margin_top = 10
	sel.content_margin_bottom = 10
	tc.add_theme_stylebox_override("tab_selected", sel)

	# Aba não selecionada
	var unsel := StyleBoxFlat.new()
	unsel.bg_color = Color(0.015, 0.03, 0.06, 0.4)
	unsel.border_width_top = 1
	unsel.border_color = Color(NEON_CYAN, 0.15)
	unsel.corner_radius_top_left = 8
	unsel.corner_radius_top_right = 8
	unsel.content_margin_left = 20
	unsel.content_margin_right = 20
	unsel.content_margin_top = 10
	unsel.content_margin_bottom = 10
	tc.add_theme_stylebox_override("tab_unselected", unsel)

	# Aba com hover
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.03, 0.06, 0.1, 0.6)
	hov.border_width_top = 2
	hov.border_width_left = 1
	hov.border_width_right = 1
	hov.border_color = NEON_GREEN
	hov.corner_radius_top_left = 8
	hov.corner_radius_top_right = 8
	hov.content_margin_left = 20
	hov.content_margin_right = 20
	hov.content_margin_top = 10
	hov.content_margin_bottom = 10
	tc.add_theme_stylebox_override("tab_hovered", hov)

	# Painel de conteúdo das abas
	var p := StyleBoxFlat.new()
	p.bg_color = Color(0.015, 0.03, 0.06, 0.5)
	p.border_width_left = 1
	p.border_width_right = 1
	p.border_width_bottom = 1
	p.border_color = Color(NEON_CYAN, 0.15)
	p.content_margin_left = 24
	p.content_margin_right = 24
	p.content_margin_top = 20
	p.content_margin_bottom = 20
	tc.add_theme_stylebox_override("panel", p)


func _style_labels_recursive(node: Node) -> void:
	if not node:
		return
	if node is Label:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", 20)
		node.add_theme_color_override("font_color", NEON_CYAN)
		node.custom_minimum_size.x = 260
	for child in node.get_children():
		_style_labels_recursive(child)


func _style_option_button(btn: OptionButton) -> void:
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", NEON_CYAN)
	btn.add_theme_color_override("font_hover_color", NEON_GREEN)
	btn.add_theme_color_override("font_pressed_color", NEON_GREEN)
	btn.custom_minimum_size = Vector2(300, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = DARK_BG_LIGHT
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.border_color = Color(NEON_CYAN, 0.5)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.border_color = NEON_GREEN
	hover.border_width_left = 5
	btn.add_theme_stylebox_override("hover", hover)

	var popup: PopupMenu = btn.get_popup()
	if popup:
		popup.add_theme_font_override("font", _font)
		popup.add_theme_font_size_override("font_size", 16)
		popup.add_theme_color_override("font_color", NEON_CYAN)
		popup.add_theme_color_override("font_hover_color", NEON_GREEN)
		var pop_panel := StyleBoxFlat.new()
		pop_panel.bg_color = DARK_BG
		pop_panel.set_border_width_all(2)
		pop_panel.border_color = NEON_CYAN
		pop_panel.set_corner_radius_all(6)
		pop_panel.content_margin_left = 12
		pop_panel.content_margin_right = 12
		pop_panel.content_margin_top = 8
		pop_panel.content_margin_bottom = 8
		popup.add_theme_stylebox_override("panel", pop_panel)
		var pop_hover := StyleBoxFlat.new()
		pop_hover.bg_color = DARK_GREEN_BG
		pop_hover.set_border_width_all(1)
		pop_hover.border_color = NEON_GREEN
		pop_hover.set_corner_radius_all(4)
		popup.add_theme_stylebox_override("hover", pop_hover)


func _style_check_box(cb: CheckBox) -> void:
	cb.add_theme_font_override("font", _font)
	cb.add_theme_font_size_override("font_size", 16)
	cb.add_theme_color_override("font_color", NEON_CYAN)
	cb.add_theme_color_override("font_hover_color", NEON_GREEN)
	cb.add_theme_color_override("font_pressed_color", NEON_GREEN)
	cb.custom_minimum_size = Vector2(160, 40)

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = DARK_BG_LIGHT
	normal_box.set_border_width_all(1)
	normal_box.border_width_left = 3
	normal_box.border_color = Color(NEON_CYAN, 0.5)
	normal_box.set_corner_radius_all(4)
	normal_box.content_margin_left = 14
	normal_box.content_margin_right = 14
	normal_box.content_margin_top = 6
	normal_box.content_margin_bottom = 6
	cb.add_theme_stylebox_override("normal", normal_box)

	var hover_box := normal_box.duplicate()
	hover_box.border_color = NEON_GREEN
	hover_box.border_width_left = 5
	cb.add_theme_stylebox_override("hover", hover_box)

	var pressed_box := normal_box.duplicate()
	pressed_box.bg_color = Color(DARK_GREEN_BG, 0.6)
	pressed_box.border_color = NEON_GREEN
	cb.add_theme_stylebox_override("pressed", pressed_box)

	var hover_pressed_box := pressed_box.duplicate()
	hover_pressed_box.border_width_left = 5
	cb.add_theme_stylebox_override("hover_pressed", hover_pressed_box)

	var uncheck_img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	uncheck_img.fill(Color(0, 0, 0, 0))
	for x in range(18):
		for y in range(18):
			if x == 0 or x == 17 or y == 0 or y == 17:
				uncheck_img.set_pixel(x, y, Color(NEON_CYAN, 0.7))
	var uncheck_tex := ImageTexture.create_from_image(uncheck_img)

	var check_img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	check_img.fill(Color(0, 0, 0, 0))
	for x in range(18):
		for y in range(18):
			if x == 0 or x == 17 or y == 0 or y == 17:
				check_img.set_pixel(x, y, NEON_GREEN)
			elif x >= 4 and x <= 13 and y >= 4 and y <= 13:
				check_img.set_pixel(x, y, NEON_GREEN)
	var check_tex := ImageTexture.create_from_image(check_img)

	cb.add_theme_icon_override("unchecked", uncheck_tex)
	cb.add_theme_icon_override("checked", check_tex)
	cb.add_theme_icon_override("unchecked_disabled", uncheck_tex)
	cb.add_theme_icon_override("checked_disabled", check_tex)

	var update_text = func(is_on: bool):
		cb.text = " ATIVADO" if is_on else " DESATIVADO"
	update_text.call(cb.button_pressed)
	cb.toggled.connect(update_text)


func _style_slider(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(300, 30)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(NEON_CYAN, 0.3)
	grabber.set_corner_radius_all(4)
	grabber.content_margin_top = 4
	grabber.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", grabber)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.1, 0.15, 0.8)
	track.set_border_width_all(1)
	track.border_color = Color(NEON_CYAN, 0.25)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var grabber_hl := grabber.duplicate()
	grabber_hl.bg_color = Color(NEON_GREEN, 0.35)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_hl)


func _style_footer_button(btn: Button) -> void:
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", NEON_CYAN)
	btn.add_theme_color_override("font_hover_color", NEON_GREEN)
	btn.add_theme_color_override("font_pressed_color", NEON_GREEN)
	btn.custom_minimum_size = Vector2(200, 50)

	var glitch_shader = load("res://scenes/main_menu/button_glitch.gdshader")
	if glitch_shader:
		var mat := ShaderMaterial.new()
		mat.shader = glitch_shader
		mat.set_shader_parameter("glitch_intensity", 0.0)
		btn.material = mat

	var normal := StyleBoxFlat.new()
	normal.bg_color = DARK_BG_LIGHT
	normal.set_border_width_all(1)
	normal.border_width_left = 4
	normal.border_color = NEON_CYAN
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = DARK_GREEN_BG
	hover.set_border_width_all(2)
	hover.border_width_left = 8
	hover.border_color = NEON_GREEN
	hover.set_corner_radius_all(6)
	hover.content_margin_left = 24
	hover.content_margin_right = 24
	hover.content_margin_top = 10
	hover.content_margin_bottom = 10
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.058, 0.149, 0.094, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.mouse_entered.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		tween.tween_property(btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	)


func _style_control_button(btn: Button) -> void:
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", NEON_CYAN)
	btn.add_theme_color_override("font_hover_color", NEON_GREEN)
	btn.add_theme_color_override("font_pressed_color", NEON_GREEN)

	var normal := StyleBoxFlat.new()
	normal.bg_color = DARK_BG_LIGHT
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.border_color = Color(NEON_CYAN, 0.5)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.border_color = NEON_GREEN
	hover.border_width_left = 5
	btn.add_theme_stylebox_override("hover", hover)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  SETUP DAS OPÇÕES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _setup_ui_options() -> void:
	display_option.clear()
	display_option.add_item("Janela", 0)
	display_option.add_item("Tela Cheia", 1)
	display_option.add_item("Janela sem Bordas", 2)

	resolution_option.clear()
	for res in SettingsManager.RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [res.x, res.y])

	colorblind_option.clear()
	colorblind_option.add_item("Desativado", 0)
	colorblind_option.add_item("Protanopia (Vermelho)", 1)
	colorblind_option.add_item("Deuteranopia (Verde)", 2)
	colorblind_option.add_item("Tritanopia (Azul)", 3)
	colorblind_option.add_item("Acromatopsia (P&B)", 4)

	equation_size_option.clear()
	equation_size_option.add_item("Normal (100%)", 0)
	equation_size_option.add_item("Grande (125%)", 1)
	equation_size_option.add_item("Extra Grande (150%)", 2)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ABA DE CONTROLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _setup_controls_tab() -> void:
	if not controls_list:
		return
	for child in controls_list.get_children():
		child.queue_free()
	action_buttons.clear()

	for action in SettingsManager.DEFAULT_CONTROLS.keys():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = SettingsManager.ACTION_DISPLAY_NAMES.get(action, action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _font:
			label.add_theme_font_override("font", _font)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", NEON_CYAN)
			label.custom_minimum_size.x = 260
		row.add_child(label)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 38)
		var current_key: int = pending_controls.get(action, SettingsManager.get_action_keycode(action))
		btn.text = "[ " + SettingsManager.get_key_name(current_key) + " ]"
		btn.pressed.connect(func(): _start_rebinding(action, btn))
		_style_control_button(btn)
		row.add_child(btn)

		action_buttons[action] = btn
		controls_list.add_child(row)


func _start_rebinding(action: String, btn: Button) -> void:
	if rebinding_button and is_instance_valid(rebinding_button) and not rebinding_action.is_empty():
		var old_key: int = pending_controls.get(rebinding_action, SettingsManager.DEFAULT_CONTROLS[rebinding_action])
		rebinding_button.text = "[ " + SettingsManager.get_key_name(old_key) + " ]"

	rebinding_action = action
	rebinding_button = btn
	btn.text = "[ Pressione uma tecla... ]"


func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty() or not is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			var old_key: int = pending_controls.get(rebinding_action, SettingsManager.DEFAULT_CONTROLS[rebinding_action])
			rebinding_button.text = "[ " + SettingsManager.get_key_name(old_key) + " ]"
			rebinding_action = ""
			rebinding_button = null
			return

		var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		pending_controls[rebinding_action] = keycode
		rebinding_button.text = "[ " + SettingsManager.get_key_name(keycode) + " ]"
		rebinding_action = ""
		rebinding_button = null


func _update_control_buttons() -> void:
	for action in action_buttons.keys():
		var btn: Button = action_buttons[action]
		var keycode: int = pending_controls.get(action, SettingsManager.DEFAULT_CONTROLS[action])
		btn.text = "[ " + SettingsManager.get_key_name(keycode) + " ]"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  CARREGAR / SALVAR
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _load_current_values() -> void:
	master_slider.value = SettingsManager.config.get_value("Audio", "master_volume", 1.0)
	bgm_slider.value = SettingsManager.config.get_value("Audio", "bgm_volume", 0.8)
	sfx_slider.value = SettingsManager.config.get_value("Audio", "sfx_volume", 0.8)
	if voice_slider:
		voice_slider.value = SettingsManager.config.get_value("Audio", "sfx_volume", 0.8)

	var current_mode: int = SettingsManager.config.get_value("Video", "display_mode", 1)
	display_option.select(current_mode)
	resolution_option.select(SettingsManager.config.get_value("Video", "resolution_idx", 0))
	vsync_check.button_pressed = SettingsManager.config.get_value("Video", "vsync", true)

	colorblind_option.select(SettingsManager.config.get_value("Accessibility", "colorblind_mode", 0))
	equation_size_option.select(SettingsManager.config.get_value("Accessibility", "equation_size_idx", 0))

	pending_controls.clear()
	for action in SettingsManager.DEFAULT_CONTROLS.keys():
		pending_controls[action] = SettingsManager.get_action_keycode(action)
	_update_control_buttons()


func _connect_audio_signals() -> void:
	master_slider.value_changed.connect(func(val): SettingsManager._set_bus_volume("Master", val))
	bgm_slider.value_changed.connect(func(val): SettingsManager._set_bus_volume("BGM", val))
	sfx_slider.value_changed.connect(func(val): SettingsManager._set_bus_volume("SFX", val))


# ── Botões do rodapé (sinais conectados no Editor) ──

func _on_save_button_pressed() -> void:
	if display_option.get_popup().visible:
		display_option.get_popup().hide()
	if resolution_option.get_popup().visible:
		resolution_option.get_popup().hide()
	if colorblind_option.get_popup().visible:
		colorblind_option.get_popup().hide()
	if equation_size_option.get_popup().visible:
		equation_size_option.get_popup().hide()

	SettingsManager.save_audio_settings(master_slider.value, bgm_slider.value, sfx_slider.value)
	SettingsManager.save_video_settings(display_option.selected, resolution_option.selected, vsync_check.button_pressed)
	SettingsManager.save_accessibility_settings(colorblind_option.selected, equation_size_option.selected)
	SettingsManager.save_controls_settings(pending_controls)
	print("Configurações salvas e aplicadas!")


func _on_reset_button_pressed() -> void:
	master_slider.value = 1.0
	bgm_slider.value = 0.8
	sfx_slider.value = 0.8
	if voice_slider:
		voice_slider.value = 0.8
	display_option.select(1)
	resolution_option.select(0)
	vsync_check.button_pressed = true
	colorblind_option.select(0)
	equation_size_option.select(0)
	pending_controls = SettingsManager.DEFAULT_CONTROLS.duplicate()
	_update_control_buttons()
	_on_save_button_pressed()


func _on_back_button_pressed() -> void:
	if rebinding_button and is_instance_valid(rebinding_button) and not rebinding_action.is_empty():
		var old_key: int = pending_controls.get(rebinding_action, SettingsManager.DEFAULT_CONTROLS[rebinding_action])
		rebinding_button.text = "[ " + SettingsManager.get_key_name(old_key) + " ]"
		rebinding_action = ""
		rebinding_button = null
	hide()
	menu_closed.emit()