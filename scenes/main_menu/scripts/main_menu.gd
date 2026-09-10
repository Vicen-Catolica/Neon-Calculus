extends Control

@export_file("*.tscn") var start_scene: String = "res://scenes/Stage1/stage1.tscn"
@export_file("*.tscn") var option_scene: String = "res://options/options.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer

func _ready() -> void:
	$MenuContainer/BtnStart.pressed.connect(func(): get_tree().change_scene_to_file(start_scene))
	$MenuContainer/BtnOptions.pressed.connect(func(): get_tree().change_scene_to_file(option_scene))
	$MenuContainer/BtnExit.pressed.connect(get_tree().quit)
	
	_setup_button_hover_effects()
	_animate_logo()
	_animate_buttons()

func _setup_button_hover_effects() -> void:
	for btn in menu_container.get_children():
		if btn is Button:
			btn.pivot_offset = btn.size / 2.0
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))

func _on_btn_hover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	tween.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)

func _on_btn_unhover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

# Glitch na Logo
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

# Glitch Independente em cada Botão
func _animate_buttons() -> void:
	for btn in menu_container.get_children():
		if btn is Button:
			# Torna o material único para este botão específico
			if btn.material:
				btn.material = btn.material.duplicate()
			_loop_button_glitch(btn)

func _loop_button_glitch(btn: Button) -> void:
	var mat = btn.material as ShaderMaterial
	if not mat: return
	
	# Atraso inicial aleatório para desincronizar os botões logo no início da cena
	await get_tree().create_timer(randf_range(0.2, 2.5)).timeout
	
	while is_instance_valid(btn):
		# Cada botão calcula seu próprio tempo de espera independente (entre 1.5s e 5.0s)
		await get_tree().create_timer(randf_range(1.5, 5.0)).timeout
		if not is_instance_valid(btn): break

		mat.set_shader_parameter("glitch_intensity", randf_range(0.5, 1.0))
		await get_tree().create_timer(randf_range(0.04, 0.12)).timeout
		mat.set_shader_parameter("glitch_intensity", 0.0)