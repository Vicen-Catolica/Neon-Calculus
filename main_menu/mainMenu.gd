extends Control

# Caminhos para as cenas - Atualize com os caminhos corretos do seu projeto
const CENA_NIVEL_INICIAL = "res://cenas/niveis/submundo_neon.tscn"
const CENA_OPCOES = "res://cenas/ui/menu_opcoes.tscn"

@onready var btn_iniciar = $MenuContainer/BtnIniciar
@onready var btn_continuar = $MenuContainer/BtnContinuar
@onready var btn_opcoes = $MenuContainer/BtnOpcoes
@onready var btn_sair = $MenuContainer/BtnSair

func _ready():
	# Conecta os botões aos seus respectivos métodos usando a sintaxe de Sinais do Godot 4
	btn_iniciar.pressed.connect(_on_btn_iniciar_pressed)
	btn_continuar.pressed.connect(_on_btn_continuar_pressed)
	btn_opcoes.pressed.connect(_on_btn_opcoes_pressed)
	btn_sair.pressed.connect(_on_btn_sair_pressed)
	
	# Foca no primeiro botão automaticamente para facilitar o uso do teclado
	btn_iniciar.grab_focus()

func _on_btn_iniciar_pressed():
	# Carrega a primeira fase do jogo (Submundo de Neon)
	get_tree().change_scene_to_file(CENA_NIVEL_INICIAL)

func _on_btn_continuar_pressed():
	# Aqui entrará a lógica da Godot FileAccess / ConfigFile API 
	# para carregar o progresso salvo localmente
	print("Carregando o save state...")
	pass

func _on_btn_opcoes_pressed():
	# Transição para a interface estruturada de opções
	get_tree().change_scene_to_file(CENA_OPCOES)

func _on_btn_sair_pressed():
	# Encerra o executável final nativo do jogo
	get_tree().quit()
