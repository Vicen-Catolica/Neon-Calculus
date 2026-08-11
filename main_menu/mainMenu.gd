extends Control

# Caminhos para as cenas atualizados conforme a sua árvore de arquivos
const START_SCENE = "res://fase_1/fase_1.tscn"
const OPTION_SCENE = "res://options/options.tscn"

@onready var btn_start = $MenuContainer/BtnStart
@onready var btn_continue = $MenuContainer/BtnContinue
@onready var btn_options = $MenuContainer/BtnOptions
@onready var btn_exit = $MenuContainer/BtnExit

func _ready():
	# Conecta os botões aos seus respectivos métodos usando a sintaxe de Sinais do Godot 4
	btn_start.pressed.connect(_on_btn_start_pressed)
	btn_continue.pressed.connect(_on_btn_continue_pressed)
	btn_options.pressed.connect(_on_btn_options_pressed)
	btn_exit.pressed.connect(_on_btn_exit_pressed)
	
	# Foca no primeiro botão automaticamente para facilitar o uso do teclado
	btn_start.grab_focus()

func _on_btn_start_pressed():
	# Carrega a primeira fase do jogo
	get_tree().change_scene_to_file(START_SCENE)

func _on_btn_continue_pressed():
	# Aqui entrará a lógica da Godot FileAccess / ConfigFile API 
	# para carregar o progresso salvo localmente
	print("Carregando o save state...")
	pass

func _on_btn_options_pressed():
	# Transição para a interface estruturada de opções
	get_tree().change_scene_to_file(OPTION_SCENE)

func _on_btn_exit_pressed():
	# Encerra o executável final nativo do jogo
	get_tree().quit()
