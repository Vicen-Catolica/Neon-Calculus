extends Control

const NEON_FONT = preload("res://assets/fonts/Orbitron-Bold.ttf")
const GRADIENT_SHADER = preload("res://assets/colors/menu_text_gradient.gdshader")

@export_file("*.tscn") var start_scene: String = "res://fase_1/fase_1.tscn"
@export_file("*.tscn") var option_scene: String = "res://options/options.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var btn_start: Button = $MenuContainer/BtnStart
@onready var btn_continue: Button = $MenuContainer/BtnContinue
@onready var btn_options: Button = $MenuContainer/BtnOptions
@onready var btn_exit: Button = $MenuContainer/BtnExit

var gradient_material: ShaderMaterial

func _ready() -> void:
	_setup_gradient_material()
	_setup_buttons()

func _setup_gradient_material() -> void:
	gradient_material = ShaderMaterial.new()
	gradient_material.shader = GRADIENT_SHADER
	gradient_material.set_shader_parameter("color_top", Color.hex(0x01f8fdff))
	gradient_material.set_shader_parameter("color_bottom", Color.hex(0x1fcef9ff))
	gradient_material.set_shader_parameter("split_point", 0.6)

func _setup_buttons() -> void:
	# Define os textos individuais de cada botão
	btn_start.text = "NOVO JOGO"
	btn_continue.text = "CONTINUAR"
	btn_options.text = "OPÇÕES"
	btn_exit.text = "SAIR"

	# Conexões de clique específicas
	btn_start.pressed.connect(_on_start_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_exit.pressed.connect(get_tree().quit)

	# Configura fonte, foco e transição de gradiente no hover/focus
	for child in menu_container.get_children():
		if child is Button:
			# Aplica fonte e tamanho
			child.add_theme_font_override("font", NEON_FONT)
			child.add_theme_font_size_override("font_size", 24)
			
			# Comportamento de foco
			child.mouse_entered.connect(child.grab_focus)
			child.mouse_exited.connect(child.release_focus)
			
			# Aplica e remove o material gradiente dinamicamente
			child.focus_entered.connect(_apply_gradient.bind(child))
			child.focus_exited.connect(_remove_gradient.bind(child))

func _apply_gradient(btn: Button) -> void:
	btn.material = gradient_material

func _remove_gradient(btn: Button) -> void:
	btn.material = null

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(start_scene)

func _on_continue_pressed() -> void:
	print("Carregando o save state...")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(option_scene)
