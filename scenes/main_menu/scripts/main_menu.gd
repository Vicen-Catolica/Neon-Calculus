extends Control

@export_file("*.tscn") var start_scene: String = "res://scenes/Stage1/stage1.tscn"
@export_file("*.tscn") var option_scene: String = "res://options/options.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var bgm: AudioStreamPlayer = get_node_or_null("BGM")
@onready var hover_sfx: AudioStreamPlayer = get_node_or_null("HoverSFX")
@onready var click_sfx: AudioStreamPlayer = get_node_or_null("ClickSFX")

func _ready() -> void:
	_setup_buttons()
	_animate_logo()
	_animate_buttons()
	_play_music_with_fade_in()

# --- CONFIGURAÇÃO E CONEXÃO DOS BOTÕES ---
func _setup_buttons() -> void:
	for btn in menu_container.get_children():
		if btn is Button:
			btn.pivot_offset = btn.size / 2.0
			# Conecta o som e animação de passar o mouse
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			# Conecta o som e ação ao pressionar
			btn.pressed.connect(_on_btn_pressed.bind(btn))

# --- EVENTO: MOUSE SOBRE O BOTÃO (HOVER) ---
func _on_btn_hover(btn: Button) -> void:
	_play_hover_sfx()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	tween.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)

func _on_btn_unhover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

# --- EVENTO: BOTÃO PRESSIONADO (CLICK) ---
func _on_btn_pressed(btn: Button) -> void:
	_play_click_sfx()
	
	match btn.name:
		"BtnStart":
			_change_scene_with_fade(start_scene)
		"BtnContinue":
			# Espaço reservado para carregar o jogo salvo
			pass
		"BtnOptions":
			_change_scene_with_fade(option_scene)
		"BtnExit":
			get_tree().quit()

# --- REPRODUÇÃO DE SFX ---
func _play_hover_sfx() -> void:
	if hover_sfx:
		if hover_sfx.stream:
			# Garante que o som reinicie imediatamente ao passar de um botão para outro
			hover_sfx.stop()
			hover_sfx.pitch_scale = randf_range(0.95, 1.05)
			hover_sfx.play()
		else:
			print("AVISO: O nó HoverSFX está sem arquivo de áudio no campo 'Stream'!")
	else:
		print("ERRO: Nó 'HoverSFX' não foi encontrado na árvore da cena!")

func _play_click_sfx() -> void:
	if click_sfx:
		if click_sfx.stream:
			click_sfx.stop()
			click_sfx.play()
		else:
			print("AVISO: O nó ClickSFX está sem arquivo de áudio no campo 'Stream'!")
	else:
		print("ERRO: Nó 'ClickSFX' não foi encontrado na árvore da cena!")	

# --- TRANSIÇÃO DE CENA E MÚSICA ---
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

# --- GLITCH DA LOGO ---
func _animate_logo() -> void:
	if not has_node("Logo"): return
	var logo = $Logo
	var mat = logo.material as ShaderMaterial

	if not mat: return

	while is_instance_valid(logo):
		await get_tree().create_timer(randf_range(1.5, 4.0)).timeout
		if not is_instance_valid(logo): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.6, 1.0))
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)

# --- GLITCH INDEPENDENTE DOS BOTÕES ---
func _animate_buttons() -> void:
	for btn in menu_container.get_children():
		if btn is Button:
			if btn.material:
				btn.material = btn.material.duplicate()
			_loop_button_glitch(btn)

func _loop_button_glitch(btn: Button) -> void:
	var mat = btn.material as ShaderMaterial
	if not mat: return
	
	await get_tree().create_timer(randf_range(0.2, 2.5)).timeout
	
	while is_instance_valid(btn):
		await get_tree().create_timer(randf_range(1.5, 5.0)).timeout
		if not is_instance_valid(btn): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.5, 1.0))
		await get_tree().create_timer(randf_range(0.04, 0.12)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)