extends Node

const SAVE_PATH: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720)
]

signal accessibility_settings_changed

const EQUATION_FONT_SIZES: Array[int] = [24, 30, 36]

const DEFAULT_CONTROLS: Dictionary = {
	"ui_left": KEY_A,
	"ui_right": KEY_D,
	"ui_accept": KEY_SPACE,
	"ui_down": KEY_S,
	"Interact": KEY_E
}

const ACTION_DISPLAY_NAMES: Dictionary = {
	"ui_left": "Mover para a Esquerda",
	"ui_right": "Mover para a Direita",
	"ui_accept": "Pular",
	"ui_down": "Mover para Baixo",
	"Interact": "Interagir"
}

var colorblind_layer: CanvasLayer
var colorblind_rect: ColorRect
var colorblind_material: ShaderMaterial

func _ready() -> void:
	# Mantém popups embutidos na janela para evitar que janelas popup do SO façam a tela cheia piscar
	get_tree().root.gui_embed_subwindows = true
	_setup_colorblind_filter()
	load_settings()

func _setup_colorblind_filter() -> void:
	colorblind_layer = CanvasLayer.new()
	colorblind_layer.layer = 125
	add_child(colorblind_layer)

	colorblind_rect = ColorRect.new()
	colorblind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	colorblind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colorblind_layer.add_child(colorblind_rect)

	var shader = load("res://scenes/options/colorblind.gdshader")
	if shader:
		colorblind_material = ShaderMaterial.new()
		colorblind_material.shader = shader
		colorblind_rect.material = colorblind_material
	colorblind_rect.hide()

func load_settings() -> void:
	if config.load(SAVE_PATH) != OK:
		save_audio_settings(1.0, 0.8, 0.8)
		save_video_settings(1, 0, true)
		save_accessibility_settings(0, 0)
		save_controls_settings(DEFAULT_CONTROLS)
	else:
		apply_settings()

func save_audio_settings(master_vol: float, bgm_vol: float, sfx_vol: float) -> void:
	config.set_value("Audio", "master_volume", master_vol)
	config.set_value("Audio", "bgm_volume", bgm_vol)
	config.set_value("Audio", "sfx_volume", sfx_vol)
	config.save(SAVE_PATH)
	apply_audio_settings()

func save_video_settings(display_mode: int, resolution_idx: int, vsync: bool) -> void:
	config.set_value("Video", "display_mode", display_mode)
	config.set_value("Video", "resolution_idx", resolution_idx)
	config.set_value("Video", "vsync", vsync)
	config.save(SAVE_PATH)
	apply_video_settings()

func save_accessibility_settings(colorblind_mode: int, equation_size_idx: int) -> void:
	config.set_value("Accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("Accessibility", "equation_size_idx", equation_size_idx)
	config.save(SAVE_PATH)
	apply_accessibility_settings()

func save_controls_settings(controls: Dictionary) -> void:
	for action in controls.keys():
		config.set_value("Controls", action, controls[action])
	config.save(SAVE_PATH)
	apply_controls_settings()

func apply_settings() -> void:
	apply_audio_settings()
	apply_video_settings()
	apply_accessibility_settings()
	apply_controls_settings()

func apply_controls_settings() -> void:
	if config.has_section_key("Controls", "ui_up"):
		config.erase_section_key("Controls", "ui_up")
		config.save(SAVE_PATH)

	if InputMap.has_action("ui_up"):
		for event in InputMap.action_get_events("ui_up"):
			if event is InputEventKey:
				InputMap.action_erase_event("ui_up", event)

	for action in DEFAULT_CONTROLS.keys():
		var keycode: int = config.get_value("Controls", action, DEFAULT_CONTROLS[action])
		_bind_action_key(action, keycode)

func _bind_action_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)

	var new_event := InputEventKey.new()
	new_event.physical_keycode = keycode as Key
	InputMap.action_add_event(action, new_event)

func get_action_keycode(action: String) -> int:
	return config.get_value("Controls", action, DEFAULT_CONTROLS.get(action, KEY_NONE))

func get_key_name(keycode: int) -> String:
	match keycode:
		KEY_SPACE:
			return "Espaço"
		KEY_ENTER:
			return "Enter"
		KEY_ESCAPE:
			return "Esc"
		KEY_UP:
			return "Seta Cima"
		KEY_DOWN:
			return "Seta Baixo"
		KEY_LEFT:
			return "Seta Esquerda"
		KEY_RIGHT:
			return "Seta Direita"
		KEY_TAB:
			return "Tab"
		KEY_SHIFT:
			return "Shift"
		KEY_CTRL:
			return "Ctrl"
		KEY_ALT:
			return "Alt"
		_:
			var s: String = OS.get_keycode_string(keycode as Key)
			return s.to_upper() if not s.is_empty() else "Nenhuma"

func apply_accessibility_settings() -> void:
	var cb_mode: int = config.get_value("Accessibility", "colorblind_mode", 0)
	if colorblind_rect and colorblind_material:
		if cb_mode == 0:
			colorblind_rect.hide()
		else:
			colorblind_material.set_shader_parameter("mode", cb_mode)
			colorblind_rect.show()

	accessibility_settings_changed.emit()

func get_equation_font_size() -> int:
	var idx: int = config.get_value("Accessibility", "equation_size_idx", 0)
	if idx >= 0 and idx < EQUATION_FONT_SIZES.size():
		return EQUATION_FONT_SIZES[idx]
	return 24

func apply_audio_settings() -> void:
	_set_bus_volume("Master", config.get_value("Audio", "master_volume", 1.0))
	_set_bus_volume("BGM", config.get_value("Audio", "bgm_volume", 0.8))
	_set_bus_volume("SFX", config.get_value("Audio", "sfx_volume", 0.8))

func apply_video_settings() -> void:
	# Se a janela ainda estiver embutida pelo editor, interrompe antes de disparar o aviso.
	# Isso acontece quando o "Embed Game" do editor (padrão desde o Godot 4.3) está ativo.
	# Desative em: ícone de monitor ao lado do botão Play, ou
	# Editor Settings > Run > Window Placement > Separate Window.
	if get_window().is_embedded():
		push_warning("Janela está rodando embutida no editor. Desative 'Embed Game' ou rode com janela flutuante/build exportada para ver as mudanças de vídeo.")
		return

	var mode: int = config.get_value("Video", "display_mode", 1)
	var res_idx: int = config.get_value("Video", "resolution_idx", 0)
	var vsync: bool = config.get_value("Video", "vsync", true)

	var vsync_mode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	if res_idx < 0 or res_idx >= RESOLUTIONS.size():
		res_idx = 0
	var target_res: Vector2i = RESOLUTIONS[res_idx]

	match mode:
		0: # Janela com bordas
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

			# Dá tempo para o SO/gerenciador de janelas terminar a transição de modo
			await get_tree().process_frame
			await get_tree().process_frame

			DisplayServer.window_set_size(target_res)

			var screen_idx: int = DisplayServer.window_get_current_screen()
			var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
			var diff: Vector2i = screen_rect.size - target_res
			var pos: Vector2i = screen_rect.position + Vector2i(diff.x >> 1, diff.y >> 1)
			pos.x = max(pos.x, screen_rect.position.x)
			pos.y = max(pos.y, screen_rect.position.y)
			DisplayServer.window_set_position(pos)

		1: # Tela Cheia Exclusiva
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_size(target_res)

		2: # Janela sem Bordas (tela cheia sem bordas)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var index = AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(value))