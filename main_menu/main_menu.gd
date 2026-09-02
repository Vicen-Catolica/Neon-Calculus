extends Control

# Carrega o arquivo compilado diretamente
const NEON_FONT = preload("res://assets/fonts/Orbitron-Bold.ttf")

# Caminhos para as cenas atualizados conforme a sua árvore de arquivos
@export_file("*.tscn") var start_scene: String = "res://fase_1/fase_1.tscn"
@export_file("*.tscn") var option_scene: String = "res://options/options.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var btn_start: Button = $MenuContainer/BtnStart
@onready var btn_continue: Button = $MenuContainer/BtnContinue
@onready var btn_options: Button = $MenuContainer/BtnOptions
@onready var btn_exit: Button = $MenuContainer/BtnExit

func _ready() -> void:
	_setup_buttons()

func _setup_buttons() -> void:
	# Conexões de clique específicas
	btn_start.pressed.connect(_on_start_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_exit.pressed.connect(get_tree().quit)
	
	# Automação de foco e cor de texto ao passar o mouse
	for child in menu_container.get_children():
		if child is Button:
			child.mouse_entered.connect(child.grab_focus)
			child.mouse_exited.connect(child.release_focus)
	
	_setup_buttons_font()

func _setup_buttons_font() -> void:
	for child in menu_container.get_children():
		if child is Button:
			child.add_theme_font_override("font", NEON_FONT)
			child.add_theme_font_size_override("font_size", 24)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(start_scene)

func _on_continue_pressed() -> void:
	print("Carregando o save state...")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(option_scene)
