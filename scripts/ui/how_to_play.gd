class_name HowToPlay
extends CanvasLayer
## Tela "Como jogar": objetivo do jogo, controles, hacking e furtividade.
## Aberta pelo menu principal e pelo menu de pausa. Fecha com Esc ou VOLTAR.
## Funciona com o jogo pausado (PROCESS_MODE_ALWAYS).

signal closed

const CYAN := Color("00f0ff")
const GREEN := Color("39ff14")
const BG := Color(0.012, 0.025, 0.05, 0.96)

const TEXT := """[color=#00f0ff][font_size=26]OBJETIVO[/font_size][/color]
Nova Gödel, 2142. A IA [color=#ff6a1a]Axioma[/color], da OmniCorp, está prestes a ativar o [b]Projeto Determinismo[/b]: controle neural de toda a população.
Você é [color=#00f0ff]Eduardo[/color], ex-analista da OmniCorp. Suba a mega-torre andar por andar sem ser capturado e chegue ao [b]Núcleo Quântico[/b] para inserir o "Paradoxo" e derrubar a Axioma.
[color=#39ff14]Não há combate:[/color] você vence com furtividade e matemática.

[color=#00f0ff][font_size=26]CADA ANDAR[/font_size][/color]
• Chegue à saída do andar (uma escada, um elevador...).
• Opcional: há prisioneiros da OmniCorp atrás de campos de força. Libertar quem está preso pode render um aliado — e uma ajuda e tanto mais para cima.
• No topo da torre, o [color=#ff6a1a]Duelo de Paradoxo[/color]: hackeie os 3 Nodos de Vigilância enquanto desvia dos ataques do núcleo (cada um avisa antes e tem uma brecha). Errar a conta só faz o núcleo recuperar a camada; o que derruba é a Defesa Neural zerar. No fim, a última "equação" é diferente de todas: pense antes de digitar.
• Os guardas atiram com taser: se a sua [b]Defesa Neural[/b] zerar, a infiltração falha e você volta ao início do andar (o jogo salva sozinho em cada andar).

[color=#00f0ff][font_size=26]CONTROLES[/font_size][/color]
[table=2]
[cell][color=#39ff14]{move_left} / {move_right}[/color]   [/cell][cell]andar[/cell]
[cell][color=#39ff14]{run}[/color]   [/cell][cell]correr (faz barulho)[/cell]
[cell][color=#39ff14]{crouch}[/color]   [/cell][cell]agachar (silencioso; passa por dutos baixos)[/cell]
[cell][color=#39ff14]{jump}[/color]   [/cell][cell]pular[/cell]
[cell][color=#39ff14]{climb_up} / {climb_down}[/color]   [/cell][cell]subir e descer escadas[/cell]
[cell][color=#39ff14]{interact_world}[/color]   [/cell][cell]esconder-se / ler terminal[/cell]
[cell][color=#39ff14]{hack_vision} ou botão direito[/color]   [/cell][cell]segurar para a visão hacker[/cell]
[cell][color=#39ff14]Mouse ou {hack_next_target}[/color]   [/cell][cell]escolher o alvo (na visão hacker)[/cell]
[cell][color=#39ff14]{hack_confirm} ou clique[/color]   [/cell][cell]hackear o alvo escolhido[/cell]
[cell][color=#39ff14]{sonar_ping}[/color]   [/cell][cell]Ping Sonar: revela inimigos, cones de visão e alvos através das paredes (recarrega em 12 s)[/cell]
[cell][color=#39ff14]{camo}[/color]   [/cell][cell]Variável Oculta: camuflagem de até 5 s; câmeras, drones e guardas não te veem (os passos ainda fazem barulho e os lasers ainda disparam)[/cell]
[cell][color=#39ff14]{hack_confirm}, {interact_world} ou clique[/color]   [/cell][cell]avançar diálogo (Esc pula)[/cell]
[cell][color=#39ff14]Esc[/color]   [/cell][cell]pausa[/cell]
[/table]

[color=#00f0ff][font_size=26]HACKING MATEMÁTICO[/font_size][/color]
Na visão hacker o tempo desacelera e tudo que pode ser hackeado fica em [color=#00f0ff]ciano[/color]. Ao hackear, resolva a equação: digite o valor de [b]x[/b] e confirme com [color=#39ff14]Enter[/color]. O relógio no canto mostra quanto tempo resta.
• Resposta certa: o hack funciona.
• Resposta errada: aparece o aviso em vermelho e você perde 3 segundos. Depois de 2 erros, a [color=#00f0ff]SINE[/color] mostra o passo a passo ao lado.
• [color=#39ff14]Esc[/color] aborta o hack, mas a Axioma pode rastrear a conexão e soar o alarme (mais chance quanto mais cedo você desiste). No lockdown não dá para abortar.
• Câmera: desliga  •  Porta: abre  •  Agente: distração no implante  •  Unidade Lógica: fica cega por 6 s  •  Luz neon: apaga  •  Quiosque: alarme falso que atrai guardas  •  Válvula: vapor que tapa a visão  •  Esteira: para  •  Drone: reinicia  •  Laser: desliga por alguns segundos  •  Ponte de luz: aparece por 10 s

[color=#00f0ff][font_size=26]FURTIVIDADE[/font_size][/color]
• A barra sobre um guarda mostra o quanto ele já te viu; cheia, ele te persegue.
• Esconda-se atrás de caixotes, armários e racks ([color=#39ff14]{interact_world}[/color]). Sob luz neon não dá: apague a luz antes.
• [color=#ff6a1a]Variância[/color] (barra no canto superior direito): cada hack e cada alarme aumentam. Se encher, a Axioma manda a [b]Varredura de Rotina[/b], um laser que percorre a área.
• [color=#ff2d55]Unidades Lógicas[/color] (ciborgues): não ouvem passos, não caem em distração e disparam o alerta quase na hora em que te veem. Só o hack as engana: o sistema visual apaga por alguns segundos.
• [color=#ff2d55]Barreiras a laser[/color]: cruzar o feixe aceso dispara o alarme. Hackeie o emissor ou passe quando ele apagar (alguns ligam e desligam no ritmo; o feixe pisca antes de religar).
• [color=#00f0ff]Pontes de luz[/color] (Núcleo): só existem ligadas. Hackeie o emissor ou espere a que pisca no ritmo. Cair no vazio te devolve à última plataforma, mas custa Defesa Neural.
• [color=#ff2d55]Segurança máxima[/color]: nos laboratórios e áreas restritas os hacks têm menos tempo (o rodapé da tela de hack avisa).
• [color=#ff2d55]Lockdown[/color]: um alarme em certas salas fecha as portas. Hackeie a porta de saída antes de o tempo acabar.
• Terminais de dados ([color=#39ff14]{interact_world}[/color]) contam a história de Nova Gödel."""

var _panel: PanelContainer


## Troca cada {ação} pelas teclas configuradas agora (acompanha o remapeamento).
static func with_keys(text: String) -> String:
	var re := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m in re.search_all(text):
		text = text.replace(m.get_string(0), Tutorial.keys_of(m.get_string(1)))
	return text


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _build() -> void:
	var font: Font = load("res://assets/fonts/ui_font.tres")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(260, 70)
	_panel.size = Vector2(1400, 940)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = "COMO JOGAR"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", CYAN)
	vb.add_child(title)

	var body := RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.text = with_keys(TEXT)
	body.fit_content = false
	body.scroll_active = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font", font)
	body.add_theme_font_override("bold_font", font)
	body.add_theme_font_size_override("normal_font_size", 21)
	body.add_theme_font_size_override("bold_font_size", 21)
	body.add_theme_color_override("default_color", Color(0.86, 0.92, 0.95))
	body.add_theme_constant_override("line_separation", 6)
	vb.add_child(body)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "VOLTAR  (Esc)"
	back.custom_minimum_size = Vector2(260, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", font)
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", GREEN)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.02, 0.08, 0.05, 0.9)
	bs.border_color = GREEN
	bs.set_border_width_all(2)
	back.add_theme_stylebox_override("normal", bs)
	var bh := bs.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.05, 0.18, 0.1, 0.95)
	back.add_theme_stylebox_override("hover", bh)
	back.add_theme_stylebox_override("pressed", bh)
	back.add_theme_stylebox_override("focus", bh)
	back.pressed.connect(close)
	vb.add_child(back)
	back.grab_focus.call_deferred()
