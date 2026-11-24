extends Node
## Simulação da Fase 3 (Setor de P&D, greybox): percorre A–E por input com os
## guardas e câmeras congelados e confere cada passagem, as luzes, o lockdown
## dos laboratórios e a lore. Uso:
##   godot --headless --path . res://tests/stage3_sim.tscn

const LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"

var lvl: Node
var p: Eduardo
var fails := 0


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tp(x: float, y: float) -> void:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func release_all() -> void:
	for a in ["move_left", "move_right", "run", "jump", "crouch", "climb_up", "climb_down", "interact_world"]:
		Input.action_release(a)


func walk(dir: String, frames: int, crouched: bool = false) -> void:
	if crouched:
		Input.action_press("crouch")
	Input.action_press(dir)
	await step(frames)
	release_all()
	await step(10)


func climb(x: float, y: float, frames: int = 260) -> void:
	tp(x, y)
	await step(8)
	Input.action_press("climb_up")
	await step(frames)
	release_all()
	await step(30)


func press_interact() -> void:
	Input.action_press("interact_world")
	await step(2)
	Input.action_release("interact_world")
	await step(5)


func pos() -> String:
	return "x=%.0f y=%.1f" % [p.global_position.x, p.global_position.y]


func _ready() -> void:
	lvl = load(LEVEL).instantiate()
	# A saída leva à Fase 4 de verdade: guardada e desligada para a simulação seguir aqui.
	var exit_target: String = lvl.get_node("LevelExit").get("next_stage")
	lvl.get_node("LevelExit").set("next_stage", "")
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(30)
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	for c in get_tree().get_nodes_in_group("security_camera"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var hv := p.get_node("HackVision") as HackVision

	check("andar 3 no GameManager", GameManager.current_floor == 3)
	check("spawn no chão da doca", absf(p.global_position.y - 16.0) < 3.0, pos())
	# O diálogo de elevador abre na chegada (fora de uma transição, sem espera).
	for i in 10:
		await get_tree().process_frame
	check("diálogo de elevador abre no spawn", Dialogue.is_open())
	Dialogue.skip()
	await step(5)

	# A: o balcão está sob a luz — não dá para se esconder até apagar.
	tp(700, 16); await step(10)
	check("A: balcão iluminado", p.is_in_light(), pos())
	await press_interact()
	check("A: luz acesa impede o esconderijo", not p.is_hidden())
	var light_a := lvl.get_node("CeilingLights/Light_700_-16") as NeonSign
	hv.debug_hack(light_a.get_node("Hackable"), true); await step(5)
	check("A: hack apaga a luz do teto", not light_a.powered and not p.is_in_light())
	await press_interact()
	check("A: no escuro, esconde atrás do balcão", p.is_hidden())
	await press_interact()
	check("A: luz não pisca sozinha", not light_a.flicker)

	# B: mezanino dos escritórios.
	await climb(41 * 32 + 16, 16.0)
	check("B: escada leva ao mezanino (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, pos())
	tp(1450, 16); await step(10)
	check("B: cubículo da esquerda fica no escuro", not p.is_in_light() and p.can_hide())

	# C: corredor de teto baixo; duto de 96 px por cima (só agachado).
	# C: barreiras a laser (fixa, depois duas temporizadas fora de sincronia).
	var alarms := [0]
	GameManager.alarm_raised.connect(func(_pp: Vector2) -> void: alarms[0] += 1)
	var fixed := lvl.get_node("Lasers/Laser2760") as LaserBarrier
	var t1 := lvl.get_node("Lasers/Laser3020") as LaserBarrier
	var t2 := lvl.get_node("Lasers/Laser3280") as LaserBarrier
	var fixed_h := fixed.get_node("Hackable") as Hackable
	check("C: laser fixo começa ligado", fixed.is_on() and fixed.mode == LaserBarrier.Mode.ALWAYS)
	check("C: laser é alvo de equação do andar (regra de três)", fixed_h.get_difficulty() == Vector2i(3, 0) and fixed_h.get_label() == "BARREIRA LASER")
	var trips := [0]
	fixed.tripped.connect(func(_b: Node2D) -> void: trips[0] += 1)
	var v0 := GameManager.variance
	tp(2700, 16); await step(10)
	await walk("move_right", 60)
	check("C: cruzar o feixe dispara o alarme", trips[0] == 1 and alarms[0] >= 1 and GameManager.variance > v0,
		"toques=%d alarmes=%d" % [trips[0], alarms[0]])
	check("C: o laser não segura o jogador", p.global_position.x > 2770.0, pos())
	hv.debug_hack(fixed_h, true); await step(3)
	check("C: hack desliga o laser fixo", not fixed.is_on() and fixed.is_hacked() and not fixed.can_be_hacked())
	tp(2700, 16); await step(5)
	await walk("move_right", 60)
	check("C: desligado, passa sem alarme", trips[0] == 1 and p.global_position.x > 2770.0, pos())
	await step(int((fixed.hack_off_time - fixed.warn_time) * 60.0) + 10)
	check("C: pisca antes de religar", fixed.is_warning() and not fixed.is_on())
	await step(int(fixed.warn_time * 60.0) + 10)
	check("C: laser fixo religa sozinho", fixed.is_on() and fixed.can_be_hacked())
	# Temporizados: ligam e desligam, fora de sincronia.
	var seen_on := false
	var seen_off := false
	var apart := false
	for i in 300:
		await step(1)
		seen_on = seen_on or t1.is_on()
		seen_off = seen_off or not t1.is_on()
		apart = apart or t1.is_on() != t2.is_on()
	check("C: laser temporizado liga e desliga", seen_on and seen_off)
	check("C: os dois temporizados ficam fora de sincronia", apart)
	var trips_t := [0]
	t1.tripped.connect(func(_b: Node2D) -> void: trips_t[0] += 1)
	while t1.is_on():
		await step(1)
	tp(2985, 16); await step(2)
	await walk("move_right", 35)
	check("C: passa no ritmo, com o feixe desligado", trips_t[0] == 0 and p.global_position.x > 3030.0, pos())
	hv.debug_hack(t1.get_node("Hackable"), true)
	await step(int(t1.on_time * 60.0) + int(t1.off_time * 60.0) + 30)
	check("C: hack segura o temporizado desligado", not t1.is_on() and t1.is_hacked())
	await climb(79 * 32 + 16, 16.0)
	check("C: escada leva à boca do duto (y≈-272)", absf(p.global_position.y + 272.0) < 6.0, pos())
	tp(2570, -272); await step(10)
	await walk("move_right", 120)
	check("C: em pé não entra no duto", p.global_position.x < 2600.0, pos())
	Input.action_press("crouch")
	Input.action_press("move_right")
	for i in 1500:
		await get_tree().physics_frame
		if p.global_position.x > 3560.0:
			break
	release_all()
	await step(60)
	check("C: agachado atravessa o duto e desce para D", p.global_position.x > 3540.0, pos())
	# Volta: a escada de D sobe até o duto (chaminé em cima dela, como na 79).
	await climb(111 * 32 + 16, 16.0, 420)
	check("D: escada de volta sobe até a boca do duto (y≈-272)", absf(p.global_position.y + 272.0) < 6.0, pos())
	tp(3600, 16); await step(20)
	var corridor_cam := lvl.get_node("Cameras/CorridorCamera") as Node2D
	check("C: a câmera do corredor fica abaixo do duto", corridor_cam.global_position.y > -272.0)

	# D: mezanino dos laboratórios (Lab 07).
	await climb(117 * 32 + 16, 16.0)
	check("D: escada leva ao mezanino do Lab 07 (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, pos())
	var cy := lvl.get_node("Guards/Guard4") as Enemy
	check("D: guarda do chão é Unidade Lógica", cy.enemy_type == Enemy.EnemyType.CYBORG)
	check("D: Unidade Lógica pede hack mais difícil", cy.get_node("Hackable").get_difficulty() == Vector2i(4, 1))
	check("D: laboratórios são segurança máxima (80% do tempo)", absf((cy.get_node("Hackable") as Hackable).get_time_mult() - 0.8) < 0.001)
	check("C: corredor fica fora da segurança máxima", (lvl.get_node("Lasers/Laser2760/Hackable") as Hackable).get_time_mult() == 1.0)

	# D -> E: porta biométrica.
	tp(4700, 16); await step(10)
	await walk("move_right", 120)
	check("D: porta trancada bloqueia", p.global_position.x < 4840.0, pos())
	hv.debug_hack(lvl.get_node("SecurityDoor/Hackable"), true)
	await step(40)
	await walk("move_right", 120)
	check("D: porta hackeada leva ao átrio", p.global_position.x > 4950.0, pos())

	# E: zigue-zague de 6 escadas até o elevador executivo.
	var ladders := [[167, 16.0], [158, -112.0], [167, -240.0], [158, -368.0], [167, -496.0], [158, -624.0]]
	var ok := true
	for l in ladders:
		await climb(l[0] * 32 + 16, l[1])
		if absf(p.global_position.y - (l[1] - 128.0)) > 6.0:
			ok = false
			print("   parou em ", pos(), " (escada x=", l[0], ")")
			break
	check("E: sobe o átrio até o topo (y≈-752)", ok and absf(p.global_position.y + 752.0) < 6.0, pos())
	tp(5300, -752); await step(10)
	var exit := lvl.get_node("LevelExit") as LevelExit
	check("E: elevador (saída) alcançável no topo", exit.overlaps_body(p))
	check("E: elevador executivo leva à Fase 4", exit_target == GameManager.LEVELS[4]["scene"], exit_target)

	# Lore: todo terminal aponta para uma entrada existente.
	var missing := []
	for t in lvl.get_node("DataTerminals").get_children():
		if LoreDatabase.get_entry(String(t.get("entry_id"))).is_empty():
			missing.append(t.get("entry_id"))
	check("terminais têm lore no JSON", missing.is_empty(), str(missing))

	# Lockdown dos laboratórios (D).
	var zone := lvl.get_node("LabLockdown") as LockdownZone
	var shutter := lvl.get_node("LockdownShutterWest") as SecurityDoor
	var exit_door := lvl.get_node("SecurityDoor") as SecurityDoor
	exit_door.close()
	await step(30)
	tp(3300, 16); await step(5)
	GameManager.raise_alarm(Vector2(3000, 16)); await step(5)
	check("alarme fora dos laboratórios não fecha nada", not zone.active)
	tp(4000, 16); await step(10)
	GameManager.raise_alarm(p.global_position); await step(30)
	check("alarme nos laboratórios inicia o lockdown", zone.active and not shutter.is_open)
	tp(3800, 16); await step(5)
	await walk("move_left", 200)
	check("lockdown: entrada bloqueada", p.global_position.x > 3590.0, pos())
	var exit_h := exit_door.get_node("Hackable") as Hackable
	check("lockdown: saída vira equação de nível 4", exit_h.get_difficulty().x == 4)
	check("lockdown: hack da saída não pode ser abortado", not exit_h.abortable)
	check("lockdown: tempo da saída = metade × segurança máxima", absf(exit_h.get_time_mult() - 0.4) < 0.001, "x%.2f" % exit_h.get_time_mult())
	hv.debug_hack(exit_h, true); await step(60)
	check("hackear a saída encerra o lockdown", not zone.active and shutter.is_open and exit_door.is_open)
	check("fim do lockdown: hack volta a ser abortável", exit_h.abortable)

	# Lab 07: resgate opcional do Dr. Vance.
	GameManager.story_flags.clear()
	var cell := lvl.get_node("Lab07Cell") as HoldingCell
	var cell_h := cell.get_node("Hackable") as Hackable
	check("Lab 07: cela fechada e hackeável", not cell.is_open and cell.can_be_hacked() and cell_h.get_label() == "CELA — LAB 07")
	check("Lab 07: campo de força pede equação de nível 4", cell_h.get_difficulty().x == 4)
	check("Lab 07: SINE avisa ao subir no mezanino", lvl.has_node("Dialogue_rnd_lab07") and Dialogue.lines_for("rnd_lab07").size() > 0)
	tp(4300, -144); await step(5)
	var hv_targets: Array = []
	Input.action_press("hack_vision"); await step(20)
	hv_targets = hv.candidates.map(func(t): return t.get_label())
	Input.action_release("hack_vision"); await step(5)
	check("Lab 07: cela aparece na visão hacker do mezanino", "CELA — LAB 07" in hv_targets, str(hv_targets))
	hv.debug_hack(cell_h, true)
	for i in 10:
		await get_tree().process_frame
	check("Lab 07: hack abre a cela e marca o resgate", cell.is_open and GameManager.has_flag("vance_rescued"))
	check("Lab 07: Vance conversa ao sair", Dialogue.is_open() and Dialogue.current_speaker() == "VANCE")
	Dialogue.skip()
	await step(120)
	check("Lab 07: Vance foge pelo duto (some)", not (cell.get_node("Prisoner") as CanvasItem).visible)
	check("Lab 07: cela aberta não aceita novo hack", not cell.can_be_hacked() and not cell_h.enabled)
	var reload := (load("res://scenes/objects/holding_cell.tscn") as PackedScene).instantiate() as HoldingCell
	add_child(reload)
	check("Lab 07: com o resgate no save, a cela já nasce aberta e vazia", reload.is_open and not (reload.get_node("Prisoner") as CanvasItem).visible)
	reload.queue_free()
	GameManager.story_flags.clear()
	var fresh := (load("res://scenes/objects/holding_cell.tscn") as PackedScene).instantiate() as HoldingCell
	add_child(fresh)
	check("Lab 07: sem o resgate, a cela nasce fechada", not fresh.is_open)
	fresh.queue_free()

	# Unidade Lógica (ciborgue) nos laboratórios (cy = Guard4, já pego acima).
	var agent := lvl.get_node("Guards/Guard5") as Enemy
	var cy_h := cy.get_node("Hackable") as Hackable
	check("ciborgue: cena própria, alvo 'UNIDADE LÓGICA'", cy.enemy_type == Enemy.EnemyType.CYBORG and cy_h.get_label() == "UNIDADE LÓGICA")
	check("ciborgue: detecta mais rápido que o agente", cy.detect_time_far < agent.detect_time_far and cy.detect_time_near < agent.detect_time_near)
	check("ciborgue: E também tem Unidade Lógica", (lvl.get_node("Guards/Guard6") as Enemy).enemy_type == Enemy.EnemyType.CYBORG)
	var no_wp: Array[Node2D] = []
	cy.waypoints = no_wp
	cy.global_position = Vector2(4100, 16)
	cy.update_facing(1.0)
	cy.process_mode = Node.PROCESS_MODE_INHERIT
	cy.state_machine.transition_to("Patrol")
	cy.awareness = 0.0
	await step(5)
	# Não cai em distração (quiosque) nem ouve passos.
	cy.investigate(Vector2(3900, 16)); await step(5)
	check("ciborgue: ignora distração", cy._current_state_name() == "patrol")
	tp(3960, 16); await step(3)  # atrás dele, a 140 px
	Input.action_press("run"); Input.action_press("move_left")
	await step(20)
	release_all()
	await step(5)
	check("ciborgue: não ouve corrida atrás dele", cy._current_state_name() == "patrol" and cy.awareness == 0.0,
		"%s %.2f" % [cy._current_state_name(), cy.awareness])
	# Na frente: vai direto ao alerta, sem a fase de suspeita.
	var states := {}
	tp(4330, 16); await step(1)
	for i in 70:
		await step(1)
		states[cy._current_state_name()] = true
		if cy._current_state_name() == "maxalert":
			break
	check("ciborgue: vê e dispara em menos de 1,2 s", cy._current_state_name() == "maxalert", str(states.keys()))
	check("ciborgue: não passa pela suspeita", not states.has("suspicious"))
	# Hack: ponto cego (sistema visual offline) e rotina reescrita.
	hv.debug_hack(cy_h, true); await step(3)
	check("ciborgue: hack apaga a visão (ponto cego)", cy.is_blind() and cy._current_state_name() == "patrol" and cy.awareness == 0.0)
	cy.update_facing(1.0)
	await step(int((cy.blind_time - 0.5) * 60.0))
	check("ciborgue: cego não vê o jogador na frente", cy._current_state_name() == "patrol" and cy.awareness == 0.0,
		"%s %.2f" % [cy._current_state_name(), cy.awareness])
	await step(90)
	check("ciborgue: visão volta sozinha", not cy.is_blind() and cy.awareness > 0.0)
	cy.process_mode = Node.PROCESS_MODE_DISABLED

	# Ping Sonar (V): revela inimigos e alvos num raio, através das paredes.
	var sonar := p.get_node("SonarPing") as SonarPing
	GameManager.set_state(GameManager.State.PLAYING)
	tp(3700, 16); await step(20)
	check("sonar: pronto no começo", sonar.ready_to_ping())
	GameManager.set_state(GameManager.State.HACKING)
	check("sonar: não funciona durante o hack", not sonar.ping())
	GameManager.set_state(GameManager.State.PLAYING)
	await step(2)
	Input.action_press("sonar_ping"); await step(2); Input.action_release("sonar_ping"); await step(2)
	var names_rev := sonar.revealed.map(func(n): return String(n.name))
	check("sonar: V revela a Unidade Lógica, o agente do mezanino e o domo", "Guard4" in names_rev and "Guard5" in names_rev and "LabDome" in names_rev, str(names_rev))
	check("sonar: não revela quem está fora do raio", not ("Guard1" in names_rev), str(names_rev))
	check("sonar: marca alvos hackeáveis por perto", sonar.nodes.size() > 0, "%d nós" % sonar.nodes.size())
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var off := sonar.offscreen_in(screen)
	var off_ok := true
	for n in off:
		if absf(n.global_position.x - p.global_position.x) < 200.0:
			off_ok = false
	check("sonar: só ameaças longe viram seta de fora da tela", off_ok and off.size() <= sonar.revealed.size(), "%d fora da tela" % off.size())
	check("sonar: recarregando, V não pinga de novo", not sonar.ping() and not sonar.ready_to_ping())
	await step(int(SonarPing.REVEAL_TIME * 60.0) + 10)
	check("sonar: revelação some depois de 5 s", sonar.revealed.is_empty())
	await step(int((SonarPing.COOLDOWN - SonarPing.REVEAL_TIME) * 60.0) + 10)
	check("sonar: recarrega em 12 s", sonar.ready_to_ping())

	# Variável Oculta (C): camuflagem de 5 s com bateria.
	var camo := p.get_node("OpticalCamo") as OpticalCamo
	# O mezanino do Lab 07 tem o gatilho do aviso da SINE (pausaria o jogo).
	GameManager.mark_dialogue_seen("rnd_lab07")
	if Dialogue.is_open():
		Dialogue.skip()
	check("camuflagem: começa com a bateria cheia", camo.battery == OpticalCamo.CAPACITY and not camo.active)
	GameManager.set_state(GameManager.State.HACKING)
	check("camuflagem: não liga durante o hack", not camo.start())
	GameManager.set_state(GameManager.State.PLAYING)
	# Unidade Lógica de frente, a 230 px.
	cy.waypoints = no_wp
	cy.global_position = Vector2(4100, 16)
	cy.update_facing(1.0)
	cy.blind_left = 0.0
	cy.awareness = 0.0
	cy.state_machine.transition_to("Patrol")
	cy.process_mode = Node.PROCESS_MODE_INHERIT
	tp(4330, 16)
	Input.action_press("camo"); await step(2); Input.action_release("camo"); await step(2)
	check("camuflagem: C liga e o Eduardo fica indetectável", camo.active and p.camouflaged and not p.is_detectable())
	await step(60)
	check("camuflagem: a Unidade Lógica de frente não vê", cy.awareness == 0.0 and cy._current_state_name() == "patrol",
		"%s %.2f" % [cy._current_state_name(), cy.awareness])
	var dome := lvl.get_node("Cameras/LabDome") as SecurityCamera
	tp(4200, 16); await step(2)
	check("camuflagem: câmera não vê embaixo dela", not dome._sees_player())
	cy.process_mode = Node.PROCESS_MODE_DISABLED
	# Audição: correr camuflado atrás de um agente humano ainda chama atenção.
	var ag := lvl.get_node("Guards/Guard5") as Enemy
	ag.waypoints = no_wp
	ag.global_position = Vector2(4300, -144)
	ag.update_facing(1.0)
	ag.awareness = 0.0
	ag.state_machine.transition_to("Patrol")
	ag.process_mode = Node.PROCESS_MODE_INHERIT
	tp(4200, -144); await step(3)
	Input.action_press("run"); Input.action_press("move_left")
	await step(20)
	release_all()
	await step(5)
	check("camuflagem: os passos ainda são ouvidos (agente reage à corrida)", ag._current_state_name() != "patrol", ag._current_state_name())
	ag.process_mode = Node.PROCESS_MODE_DISABLED
	# A bateria acaba sozinha em 5 s.
	await step(int(OpticalCamo.CAPACITY * 60.0) + 20)
	check("camuflagem: desliga sozinha quando a bateria acaba", not camo.active and not p.camouflaged and camo.battery < OpticalCamo.MIN_TO_START)
	check("camuflagem: sem carga não liga", not camo.start())
	await step(int((OpticalCamo.RECHARGE_DELAY + OpticalCamo.MIN_TO_START / OpticalCamo.RECHARGE_RATE) * 60.0) + 20)
	check("camuflagem: recarrega aos poucos e volta a ligar", camo.battery >= OpticalCamo.MIN_TO_START and camo.start())
	# Laser é físico: dispara mesmo com o Eduardo camuflado.
	var laser_c := lvl.get_node("Lasers/Laser2760") as LaserBarrier
	var laser_trips := [0]
	laser_c.tripped.connect(func(_b: Node2D) -> void: laser_trips[0] += 1)
	tp(2700, 16); await step(5)
	await walk("move_right", 60)
	check("camuflagem: laser ainda dispara", laser_trips[0] == 1)
	camo.stop()
	check("camuflagem: C de novo desliga antes", not camo.active and p.is_detectable())

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
