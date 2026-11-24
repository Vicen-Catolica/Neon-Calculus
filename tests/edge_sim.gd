extends Node
## Casos-limite pontuais encontrados no playtest de caos/revisão. Cada caso
## monta a situação direto e confere o resultado. Uso:
##   godot --headless --path . res://tests/edge_sim.tscn
## Preserva o save do jogador.

var fails := 0


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func act(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	await tree.process_frame
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	var backup := SaveGame.load_checkpoint()
	await _run()
	SaveGame.clear()
	if not backup.is_empty():
		SaveGame._write(backup)
	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func load_level(n: int) -> Level:
	GameManager.reset_progress()
	LevelTransition.change_level(GameManager.LEVELS[n]["scene"])
	await frames(2)
	while LevelTransition.is_busy():
		await frames(1)
	await frames(3)
	if Dialogue.is_open():
		Dialogue.skip()
	var lvl := get_tree().current_scene as Level
	for e in lvl.find_children("*", "LevelExit", true, false):
		(e as LevelExit).next_stage = ""
	return lvl


func player() -> Eduardo:
	return get_tree().get_first_node_in_group("Player") as Eduardo


func hacking_ui() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hacking_ui") as CanvasLayer


func _run() -> void:
	var lvl := await load_level(1)
	var p := player()
	var hv := p.get_node("HackVision") as HackVision
	var ui := hacking_ui()

	# 1. Hackear pendurado numa escada: depois do hack ele continua na escada?
	var ladders := get_tree().get_nodes_in_group("ladder")
	var target: Hackable = null
	for h in get_tree().get_nodes_in_group("hackable"):
		if (h as Hackable).can_be_hacked():
			target = h
			break
	if not ladders.is_empty() and target:
		var l := ladders[0] as Area2D
		p.global_position = l.global_position + Vector2(0, 40)
		p.velocity = Vector2.ZERO
		await physics(3)
		act("climb_up", true)
		await physics(20)
		act("climb_up", false)
		await physics(2)
		var climbing := p.state == Eduardo.State.CLIMB
		var y0 := p.global_position.y
		hv._start_hack(target)
		await frames(3)
		ui.call("_complete_hack", true)
		await physics(40)
		check("hack na escada: Eduardo estava subindo", climbing, "state=%d" % p.state)
		check("hack na escada: continua agarrado depois do hack",
				p.state == Eduardo.State.CLIMB, "state=%d, caiu %.0f px" % [p.state, p.global_position.y - y0])
		act("climb_down", false)

	# 2. Esc no mesmo quadro em que o hack abre: o cronômetro não fica rodando escondido.
	await frames(5)
	p.global_position = lvl.get_node("Eduardo").global_position
	hv._start_hack(target)
	ui.call("abort_hack", 1.0)  # antes do await do start_hacking
	await wait_real(1.2)
	var timer := ui.get_node_or_null("%HackTimer") if ui.has_node("%HackTimer") else ui.get("hack_timer") as Timer
	check("Esc no quadro de abertura fecha o hack", not ui.visible)
	check("Esc no quadro de abertura: cronômetro parado", timer == null or timer.is_stopped(),
			"time_left=%.1f" % (timer.time_left if timer else -1.0))
	check("Esc no quadro de abertura: estado volta a PLAYING", GameManager.state == GameManager.State.PLAYING,
			"state=%d" % GameManager.state)
	check("Esc no quadro de abertura: mundo despausado", not get_tree().paused)
	if timer and not timer.is_stopped():
		# Se o cronômetro ficou rodando, o timeout dispara um resultado fantasma.
		var fired := [false]
		ui.hacking_failed.connect(func() -> void: fired[0] = true, CONNECT_ONE_SHOT)
		await wait_real(timer.time_left + 2.0)
		check("Esc no quadro de abertura: sem 'tempo esgotado' fantasma depois", not fired[0])

	# 3. Pausar durante a visão hacker e voltar com Q ainda segurado.
	act("hack_vision", true)
	await frames(5)
	check("visão hacker liga", GameManager.state == GameManager.State.HACK_VISION)
	PauseMenu.open()
	await frames(3)
	check("pausa na visão hacker: tempo normal", is_equal_approx(Engine.time_scale, 1.0) and get_tree().paused)
	PauseMenu.resume()
	await frames(5)
	check("depois da pausa, com Q segurado, a visão hacker volta", GameManager.state == GameManager.State.HACK_VISION)
	act("hack_vision", false)
	await frames(5)
	check("soltar Q volta ao normal", GameManager.state == GameManager.State.PLAYING and is_equal_approx(Engine.time_scale, 1.0))

	# 4. Esc repetido no menu de pausa (abre/fecha várias vezes por quadro).
	for i in 7:
		act("ui_cancel", true)
		await frames(1)
		act("ui_cancel", false)
		await frames(1)
	await frames(3)
	check("Esc 7x: pausa aberta e jogo pausado coerentes", PauseMenu.is_open() == get_tree().paused,
			"aberta=%s pausado=%s" % [PauseMenu.is_open(), get_tree().paused])
	if PauseMenu.is_open():
		PauseMenu.resume()

	# 5. Escondido + visão hacker + hack: continua escondido e indetectável.
	var spots := get_tree().get_nodes_in_group("hide_spot")
	var dark: Node2D = null
	for s in spots:
		p.global_position = (s as Node2D).global_position + Vector2(0, -4)
		p.velocity = Vector2.ZERO
		await physics(4)
		if p.can_hide():
			dark = s
			break
	if dark:
		act("interact_world", true)
		await physics(2)
		act("interact_world", false)
		await physics(3)
		check("esconde", p.is_hidden())
		hv._start_hack(target)
		await frames(3)
		ui.call("_complete_hack", true)
		await physics(20)
		check("hack escondido: continua escondido e indetectável", p.is_hidden() and not p.is_detectable())
		act("interact_world", true)
		await physics(2)
		act("interact_world", false)
		await physics(3)

	# 6. Camuflagem durante a visão hacker gasta bateria em tempo de mundo (4x mais lenta em tempo real).
	var camo := p.get_node("OpticalCamo") as OpticalCamo
	camo.battery = OpticalCamo.CAPACITY
	act("hack_vision", true)
	await frames(3)
	camo.start()
	var t0 := Time.get_ticks_msec()
	while camo.active and Time.get_ticks_msec() - t0 < 30000:
		await frames(5)
	act("hack_vision", false)
	var real_s := (Time.get_ticks_msec() - t0) / 1000.0
	print("INFO    camuflagem na visão hacker durou %.1f s reais (5 s de mundo)" % real_s)

	# 7. Fase 4: cair no vazio com pouca defesa mata (game over), sem loop de respawn.
	lvl = await load_level(4)
	p = player()
	var abyss := get_tree().get_first_node_in_group("abyss") as AbyssZone
	if abyss:
		p.current_defense = 15.0
		abyss._on_body_entered(p)
		await wait_real(1.5)
		var go := false
		for c in get_tree().root.get_children():
			if c is GameOver:
				go = true
				c.queue_free()
		check("abismo com 15 de defesa: game over", p.is_dead and go)
		get_tree().paused = false
		await frames(3)

	# 8. Reiniciar o andar pela pausa depois de resgatar o Vance (Fase 3): o resgate fica.
	lvl = await load_level(3)
	GameManager.set_flag("vance_rescued")
	PauseMenu.open()
	PauseMenu.call("_restart_floor")
	await frames(2)
	while LevelTransition.is_busy():
		await frames(1)
	await frames(3)
	if Dialogue.is_open():
		Dialogue.skip()
	check("reiniciar andar: Fase 3 recarregada e despausada", get_tree().current_scene is Level and not get_tree().paused)
	check("reiniciar andar: resgate do Vance mantido", GameManager.has_flag("vance_rescued"))
	var cell := get_tree().get_first_node_in_group("holding_cell")
	if cell:
		check("reiniciar andar: cela já aparece aberta", not cell.call("can_be_hacked"))

	# 9. Duelo vencido: Esc não abre a pausa durante o colapso / tela branca.
	lvl = await load_level(5)
	GameManager.mark_dialogue_seen("duel_confront")
	var duel := get_tree().get_first_node_in_group("paradox_duel") as ParadoxDuel
	duel.go_to_ending = false
	duel.state = ParadoxDuel.State.PARADOX
	duel._on_paradox_inserted()
	await frames(5)
	act("ui_cancel", true)
	await frames(2)
	act("ui_cancel", false)
	await frames(2)
	check("Duelo vencido: Esc não abre a pausa", not PauseMenu.is_open())
	if PauseMenu.is_open():
		PauseMenu.resume()
	await wait_real(2.0)
	if Dialogue.is_open():
		Dialogue.skip()
