extends Node
## Simulação do Duelo de Paradoxo (arena do Domo). Parte 1: as peças isoladas
## (núcleo, Nodos de Vigilância, cada ataque: aviso sem dano, dano fora da brecha,
## brecha que salva, invulnerabilidade curta), com o controlador desligado.
## Parte 2: o Duelo inteiro por código (camadas, falha que recupera a camada,
## Protocolo Vance, Paradoxo pela tela de hack, vitória). Uso:
##   godot --headless --path . res://tests/duel_sim.tscn

const LEVEL := "res://scenes/levels/core/core_duel.tscn"

var lvl: Node
var p: Eduardo
var fails := 0


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func reset_player(x: float, y: float = 16.0) -> void:
	p.current_defense = p.max_defense
	p.set_meta("duel_iframe_until", 0)
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	await step(8)


## Roda um ataque inteiro e devolve [dano no aviso, dano total].
func run(a: DuelAttack) -> Array:
	lvl.add_child(a)
	var d0 := p.current_defense
	a.start()
	await step(int(a.telegraph_time * 60.0) - 2)
	var during_tele := d0 - p.current_defense
	while a.phase != DuelAttack.Phase.DONE:
		await step(1)
	var total := d0 - p.current_defense
	a.queue_free()
	await step(2)
	return [during_tele, total]


func _ready() -> void:
	GameManager.mark_dialogue_seen("duel_confront")  # parte 1: sem o confronto
	lvl = load(LEVEL).instantiate()
	lvl.get_node("ParadoxDuel").process_mode = Node.PROCESS_MODE_DISABLED  # parte 1: peças isoladas
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(20)
	check("arena: andar 4 com câmera inteira (zoom 1)", GameManager.current_floor == 4 and (p.get_node("GameCamera") as Camera2D).zoom == Vector2.ONE)

	# Núcleo.
	var core := lvl.get_node("AxiomaCore") as AxiomaCore
	core.set_damage(7)
	check("núcleo: dano vai de 0 a 3", core.damage_level == 3)
	core.set_damage(0)

	# Nodos de Vigilância.
	var nodes := lvl.get_node("SurveillanceNodes").get_children()
	check("3 Nodos de Vigilância, todos apagados", nodes.size() == 3 and nodes.all(func(n): return n.state == SurveillanceNode.State.IDLE and not n.can_be_hacked()))
	var top := lvl.get_node("SurveillanceNodes/NodeTop") as SurveillanceNode
	var th := top.get_node("Hackable") as Hackable
	top.activate()
	check("nó ativo aceita hack", top.can_be_hacked() and th.get_label() == "NODO DE VIGILÂNCIA")
	check("nó pede nível 5 (o de cima, com parênteses)", th.get_difficulty() == Vector2i(5, 1), str(th.get_difficulty()))
	check("nó: sem Esc e com tempo curto do Duelo × segurança máxima", not th.abortable and absf(th.get_time_mult() - 0.6 * 0.8) < 0.001)
	var broke := [0]
	top.broken.connect(func() -> void: broke[0] += 1)
	(p.get_node("HackVision") as HackVision).debug_hack(th, true)
	await step(2)
	check("hack derruba o nó", top.state == SurveillanceNode.State.BROKEN and broke[0] == 1 and not top.can_be_hacked())

	# Varredura descendo com brecha em x.
	await reset_player(300)
	var sw := SweepAttack.new()
	sw.gap_center = 1300.0
	var r := await run(sw)
	check("varredura: o aviso não causa dano", r[0] == 0.0)
	check("varredura: fora da brecha, acerta uma vez (-25)", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(1300)
	sw = SweepAttack.new()
	sw.gap_center = 1300.0
	r = await run(sw)
	check("varredura: dentro da brecha, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Varredura lateral com brecha rente ao chão: em pé acerta, agachado passa.
	await reset_player(900)
	sw = SweepAttack.new()
	sw.dir = SweepAttack.Dir.RIGHT
	sw.gap_center = SweepAttack.CROUCH_GAP
	r = await run(sw)
	check("varredura lateral: em pé, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(900)
	Input.action_press("crouch")
	await step(10)
	sw = SweepAttack.new()
	sw.dir = SweepAttack.Dir.RIGHT
	sw.gap_center = SweepAttack.CROUCH_GAP
	r = await run(sw)
	Input.action_release("crouch")
	check("varredura lateral: agachado, passa por baixo", r[1] == 0.0, "dano %.0f" % r[1])

	# Pulso em anel com brecha angular.
	await reset_player(300)
	var pu := PulseAttack.new()
	pu.center = core.global_position
	pu.gap_angle_deg = 90.0
	r = await run(pu)
	check("pulso: fora da brecha, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(300)
	pu = PulseAttack.new()
	pu.center = core.global_position
	pu.gap_angle_deg = rad_to_deg((DuelHit.body_rect(p).get_center() - core.global_position).angle())
	r = await run(pu)
	check("pulso: no ângulo da brecha, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Grade de lasers.
	await reset_player(800)
	var gr := LaserGridAttack.new()
	r = await run(gr)
	check("grade: dentro de uma coluna, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(1000)
	gr = LaserGridAttack.new()
	r = await run(gr)
	check("grade: no vão entre as colunas, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Dois ataques juntos: invulnerabilidade curta, um golpe só.
	await reset_player(800)
	var a1 := LaserGridAttack.new()
	var a2 := SweepAttack.new()
	a2.dir = SweepAttack.Dir.RIGHT
	a2.gap_center = 0.0
	a2.active_time = 0.6
	a1.active_time = 0.6
	lvl.add_child(a1)
	lvl.add_child(a2)
	var d0 := p.current_defense
	a1.start()
	a2.start()
	await step(int((a1.telegraph_time + 0.6) * 60.0) + 10)
	check("dois ataques ao mesmo tempo tiram um golpe só", d0 - p.current_defense == 25.0, "dano %.0f" % (d0 - p.current_defense))

	await full_duel()
	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- Parte 2: o Duelo inteiro ------------------------------------------------------

func full_duel() -> void:
	lvl.queue_free()
	await step(5)
	GameManager.story_flags.clear()
	GameManager.dialogues_seen.clear()
	GameManager.set_flag("vance_rescued")  # Protocolo Vance ligado nesta rodada
	lvl = load(LEVEL).instantiate()
	lvl.get_node("ParadoxDuel").set("rng_seed", 7)
	lvl.get_node("ParadoxDuel").set("go_to_ending", false)  # não troca de cena no teste
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	var duel := lvl.get_node("ParadoxDuel") as ParadoxDuel
	var hv := p.get_node("HackVision") as HackVision
	var ui = get_tree().get_first_node_in_group("hacking_ui")
	await step(5)
	check("Duelo: começa esperando", duel.state == ParadoxDuel.State.WAITING)
	for i in 20:
		await get_tree().process_frame
	check("confronto: a Axioma fala ao entrar no Domo", Dialogue.is_open() and Dialogue.current_speaker() == "AXIOMA")
	check("confronto: interferência vermelha quando a Axioma fala", (Dialogue.find_child("AxiomaGlitch", true, false) as CanvasItem).visible)
	var lines: Array = Dialogue.lines_for("duel_confront")
	check("confronto: fala do Vance só com o resgate", lines.any(func(l): return "Vance" in String(l["text"])))
	GameManager.story_flags.clear()
	check("confronto: sem o resgate, a fala some", not Dialogue.lines_for("duel_confront").any(func(l): return "Vance" in String(l["text"])))
	GameManager.set_flag("vance_rescued")
	check("o Duelo espera o confronto acabar", duel.state == ParadoxDuel.State.WAITING)
	Dialogue.skip()
	await step(int(duel.start_delay * 60.0) + 10)
	check("Duelo: a trilha do Duelo toca na camada 1", duel._music.playing and duel._music.stream.resource_path.ends_with("The_Axioma_Resolve.mp3"))
	check("Duelo: camada 1 acende o nó da esquerda", duel.state == ParadoxDuel.State.LAYER and duel.layer == 1
		and duel.nodes[0].state == SurveillanceNode.State.ACTIVE and duel.nodes[1].state == SurveillanceNode.State.IDLE)
	var nh := duel.nodes[0].get_node("Hackable") as Hackable
	check("Duelo: nó com tempo curto (0,6 × 0,8 da segurança máxima)", absf(nh.get_time_mult() - 0.48) < 0.001, "x%.2f" % nh.get_time_mult())
	# Parado no meio do chão por 10 s: o núcleo ataca e acerta.
	p.global_position = Vector2(960, 16)
	await step(600)
	check("Duelo: o núcleo ataca sem parar", duel.attacks_spawned >= 3, "%d ataques" % duel.attacks_spawned)
	check("Duelo: quem fica parado leva dano", p.current_defense < p.max_defense and not p.is_dead, "defesa %.0f" % p.current_defense)
	# Daqui em diante, invulnerável: o teste é da lógica das camadas.
	p.current_defense = p.max_defense
	p.set_meta("duel_iframe_until", Time.get_ticks_msec() + 3600 * 1000)
	# Errar o hack: o núcleo recupera a camada por alguns segundos.
	hv.debug_hack(nh, false); await step(3)
	check("Duelo: errar apaga o nó (o núcleo recupera a camada)", duel.nodes[0].state == SurveillanceNode.State.IDLE and duel.layer == 1)
	await step(int(duel.recover_time * 60.0) + 10)
	check("Duelo: o nó volta depois de alguns segundos", duel.nodes[0].state == SurveillanceNode.State.ACTIVE)
	# Acertar: camada derrubada, núcleo danificado, ataques somem, próxima camada.
	hv.debug_hack(nh, true); await step(3)
	check("Duelo: camada 1 derrubada danifica o núcleo", duel.state == ParadoxDuel.State.BETWEEN and duel.core.damage_level == 1)
	await get_tree().process_frame
	check("a Axioma comenta a camada derrubada", Dialogue.is_open() and Dialogue.current_speaker() == "AXIOMA")
	Dialogue.skip()
	check("Duelo: ataques somem entre as camadas", get_tree().get_nodes_in_group("duel_attack").is_empty())
	await step(160)
	check("Duelo: camada 2 acende o nó da direita", duel.layer == 2 and duel.nodes[1].state == SurveillanceNode.State.ACTIVE)
	check("Duelo: camada 2 ataca mais rápido", duel.intervals[1] < duel.intervals[0])
	hv.debug_hack(duel.nodes[1].get_node("Hackable"), true)
	await step(3)
	Dialogue.skip()
	await step(160)
	var top_h := duel.nodes[2].get_node("Hackable") as Hackable
	check("Duelo: camada 3 é o nó de cima, com parênteses", duel.layer == 3 and top_h.get_difficulty() == Vector2i(5, 1))
	check("Vance: SINE abre o passo a passo na última camada", top_h.sine_at_start)
	check("Vance: brecha maior nos pulsos", duel._pulse().gap_width_deg == ParadoxDuel.VANCE_PULSE_GAP)
	await step(300)
	hv.debug_hack(top_h, true)
	await step(3)
	Dialogue.skip()
	await step(160)
	check("Duelo: 3 nós no chão abrem o núcleo", duel.state == ParadoxDuel.State.PARADOX and duel.core.paradox_open and duel.core.can_be_hacked())
	# Paradoxo pela tela de hack, como o jogador.
	var core_h := duel.core.get_node("Hackable") as Hackable
	hv._start_hack(core_h)
	await get_tree().process_frame
	check("Paradoxo: a tela mostra x = x + 1 e o botão Ø", ui.paradox_mode and ui.equation_label.text == "x = x + 1" and ui._paradox_btn.visible)
	check("Paradoxo: não dá para abortar", not ui.can_abort)
	ui.current_input_text = "5"
	ui._on_submit_pressed()
	await get_tree().process_frame
	check("Paradoxo: número é erro, e o aviso explica", "nenhum número" in (ui.find_child("FeedbackLabel", true, false) as Label).text)
	ui.current_input_text = "7"
	ui._on_submit_pressed()
	await get_tree().process_frame
	check("Paradoxo: SINE mostra que vira 0 = 1", ui.ai_assistant_panel.visible and "0 = 1" in ui.ai_hint_label.text)
	ui._on_paradox_answer()
	await get_tree().create_timer(2.4, true, false, true).timeout
	await step(5)
	check("Paradoxo aceito: a Axioma colapsa", duel.state == ParadoxDuel.State.WON and duel.core.collapsed)
	check("vitória em silêncio (a trilha para)", not duel._music.playing)
	check("vitória marcada no save do jogo", GameManager.has_flag("axioma_defeated"))
	var ended := [false]
	duel.ending_ready.connect(func() -> void: ended[0] = true)
	await get_tree().create_timer(1.8).timeout
	check("vitória: falas finais com a Axioma travando", Dialogue.is_open() and Dialogue.current_speaker() == "AXIOMA")
	check("vitória: o Vance manda recado (resgatado)", Dialogue.lines_for("duel_victory").any(func(l): return "Vance" in String(l["text"])))
	Dialogue.skip()
	await step(3)
	check("depois das falas, a tela de encerramento pode entrar", ended[0])
	check("depois da vitória o jogo volta a andar", not get_tree().paused and GameManager.state == GameManager.State.PLAYING)
	GameManager.story_flags.clear()

