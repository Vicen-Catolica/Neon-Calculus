extends Node
## Simulação da Fase 1 (favelas): exercita as mecânicas por código/input e
## imprime OK/FALHOU por item. Uso:
##   godot --headless --path . res://tests/stage_sim.tscn

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


func freeze_guards(on: bool) -> void:
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	lvl = load("res://scenes/levels/slums/slums_stage1.tscn").instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	p.defense_changed.connect(func(c, m): print("   [dano] defesa=", c, "/", m, " em x=", snappedf(p.global_position.x, 1), " y=", snappedf(p.global_position.y, 1)))
	await step(30)
	check("spawn no chão da rua (y≈16)", absf(p.global_position.y - 16.0) < 3.0, "y=%.1f" % p.global_position.y)
	check("variância zerada ao entrar", GameManager.variance == 0.0)
	freeze_guards(true)

	# Esconderijo tutorial (sacos de lixo em x=430).
	tp(430, 16); await step(10)
	Input.action_press("interact_world"); await step(2); Input.action_release("interact_world"); await step(10)
	check("esconder nos sacos de lixo", p.is_hidden() and not p.is_detectable())
	Input.action_press("interact_world"); await step(2); Input.action_release("interact_world"); await step(10)
	check("sair do esconderijo", not p.is_hidden())

	# Caixotes sob a luz do RAMEN: não dá para esconder até apagar o neon.
	tp(1000, 16); await step(10)
	check("luz do RAMEN expõe o jogador", p.is_in_light())
	Input.action_press("interact_world"); await step(2); Input.action_release("interact_world"); await step(5)
	check("não esconde sob a luz", not p.is_hidden())
	var ramen := lvl.get_node("NeonSigns/NeonRamenFlicker2f") as NeonSign
	var hv := p.get_node("HackVision") as HackVision
	hv.debug_hack(ramen.get_node("Hackable"), true); await step(5)
	check("hack apaga o RAMEN", not ramen.powered)
	check("variância subiu com o hack", GameManager.variance > 0.0, "%.0f" % GameManager.variance)
	await step(5)
	Input.action_press("interact_world"); await step(2); Input.action_release("interact_world"); await step(10)
	check("esconde nos caixotes depois de apagar a luz", p.is_hidden())
	Input.action_press("interact_world"); await step(2); Input.action_release("interact_world"); await step(5)

	# Escada até a passarela.
	tp(1488, 16); await step(10)
	Input.action_press("climb_up"); await step(260); Input.action_release("climb_up"); await step(40)
	check("escada leva à passarela (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, "y=%.1f state=%s" % [p.global_position.y, p.State.keys()[p.state]])

	# Degraus para o quarteirão elevado (2 x 32 px).
	tp(1960, 16); await step(5)
	Input.action_press("move_right"); await step(2)
	for k in 2:
		Input.action_press("jump"); await step(20); Input.action_release("jump"); await step(30)
	await step(30)
	Input.action_release("move_right"); await step(10)
	check("sobe os degraus até o quarteirão (y≈-48)", absf(p.global_position.y + 48.0) < 3.0, "x=%.0f y=%.1f" % [p.global_position.x, p.global_position.y])

	# Quiosque atrai o guarda 2.
	freeze_guards(false)
	var g2 := lvl.get_node("Guards/Guard2")
	var kiosk := lvl.get_node("AxiomaKiosk")
	tp(1700, 16); await step(5)
	hv.debug_hack(kiosk.get_node("Hackable"), true); await step(5)
	check("quiosque manda o guarda investigar", g2._current_state_name() == "investigate", g2._current_state_name())
	freeze_guards(true)

	# Câmera de parede desliga com hack.
	var wall := lvl.get_node("Cameras/WallCamera") as SecurityCamera
	hv.debug_hack(wall.get_node("Hackable"), true); await step(60)
	check("câmera hackeada desliga", wall.mode == SecurityCamera.Mode.DISABLED, str(wall.mode))

	# Câmera vê o jogador e dispara alarme (dome no beco coberto).
	var dome := lvl.get_node("Cameras/DomeCamera") as SecurityCamera
	var alarms := [0]
	var cb := func(_pos): alarms[0] += 1
	GameManager.alarm_raised.connect(cb)
	tp(4300, -48); await step(5)
	dome.aim_deg = 90.0
	await step(120)
	check("dome detecta e dispara alarme", alarms[0] > 0, "alarmes=%d modo=%s" % [alarms[0], dome.mode])
	GameManager.alarm_raised.disconnect(cb)

	# Túnel baixo: em pé bloqueia, agachado passa.
	tp(3300, -48); await step(10)
	Input.action_press("move_right"); await step(150)
	var x_stand := p.global_position.x
	check("túnel bloqueia em pé", x_stand < 3400.0, "x=%.0f" % x_stand)
	Input.action_press("crouch"); await step(20)
	await step(480)
	check("túnel passa agachado", p.global_position.x > 3800.0, "x=%.0f" % p.global_position.x)
	Input.action_release("crouch"); Input.action_release("move_right"); await step(30)

	# Hackear agachado embaixo do túnel não levanta o Eduardo.
	tp(3550, -48); Input.action_press("crouch"); await step(20)
	GameManager.set_state(GameManager.State.HACKING); await step(10)
	var crouched_in_hack: bool = p._crouching
	GameManager.set_state(GameManager.State.PLAYING); Input.action_release("crouch"); await step(10)
	check("hackear no túnel mantém agachado", crouched_in_hack and p._crouching and absf(p.global_position.y + 48.0) < 3.0,
		"y=%.1f" % p.global_position.y)
	Input.action_press("move_right"); await step(60); Input.action_release("move_right"); await step(5)
	check("depois do hack segue andando agachado no túnel", p.global_position.x > 3570.0, "x=%.0f" % p.global_position.x)

	# Terminal de lore.
	var term := lvl.get_node("DataTerminals/Terminal_slums_03_variance")
	tp(3880, -48); await step(10)
	check("terminal detecta o jogador perto", term.is_player_near())
	term.open(); await step(2)
	var reader := get_tree().get_first_node_in_group("lore_reader")
	check("leitor de lore abre e pausa", reader.is_open() and get_tree().paused)
	reader._close(); await step(2)
	check("lore marcada como lida", "slums_03_variance" in GameManager.lore_read)

	# Porta: bloqueia até o hack, depois libera.
	var door := lvl.get_node("SecurityDoor") as SecurityDoor
	tp(4600, -48); await step(5)
	Input.action_press("move_right"); await step(120)
	check("porta trancada bloqueia", p.global_position.x < door.global_position.x, "x=%.0f" % p.global_position.x)
	hv.debug_hack(door.get_node("Hackable"), true); await step(60)
	await step(120)
	Input.action_release("move_right")
	check("porta hackeada abre e deixa passar", door.is_open and p.global_position.x > door.global_position.x + 20.0, "x=%.0f" % p.global_position.x)

	# Leitor de lore centralizado na tela.
	term.open(); await step(2)
	var panel_rect: Rect2 = reader._panel.get_global_rect()
	var vp := get_viewport().get_visible_rect()
	check("painel de lore centralizado", vp.encloses(panel_rect) and absf(panel_rect.get_center().x - vp.get_center().x) < 4.0, str(panel_rect))
	reader._close(); await step(2)

	# Guarda: jogador atravessa e a detecção não é instantânea.
	var g3 := lvl.get_node("Guards/Guard3") as Enemy
	freeze_guards(false)
	g3.global_position = Vector2(4300, -48)
	g3.state_machine.transition_to("Distracted")  # parado e cego enquanto o Eduardo passa
	tp(4200, -48); await step(5)
	Input.action_press("move_right"); await step(150); Input.action_release("move_right"); await step(5)
	check("jogador atravessa o guarda", p.global_position.x > g3.global_position.x + 20.0, "p=%.0f g=%.0f" % [p.global_position.x, g3.global_position.x])
	# câmeras desligadas: um alarme jogaria o guarda direto em alerta máximo
	for c in get_tree().get_nodes_in_group("security_camera"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	g3.waypoints = []
	g3.state_machine.transition_to("Patrol")
	g3.update_facing(1.0)
	g3.awareness = 0.0
	tp(g3.global_position.x + 250.0, -48); await step(12)
	check("barra de detecção enche aos poucos", g3.awareness > 0.0 and g3._current_state_name() != "maxalert", "%.2f %s" % [g3.awareness, g3._current_state_name()])
	await step(120)
	check("barra cheia vira alerta máximo", g3._current_state_name() == "maxalert", g3._current_state_name())
	freeze_guards(true)

	# Variância cai sozinha depois de um tempo sem hack.
	tp(200, 16); await step(240)  # longe de câmeras/guardas, varredura terminada
	GameManager.reset_variance()
	GameManager.add_variance(30.0)
	var v0 := GameManager.variance
	await step(int(GameManager.VARIANCE_DECAY_DELAY * 60.0) - 60)
	check("variância segura antes do atraso", GameManager.variance == v0, "%.1f" % GameManager.variance)
	await step(240)
	check("variância cai depois do atraso", GameManager.variance < v0, "%.1f -> %.1f" % [v0, GameManager.variance])

	print("\n%s — %d falha(s)" % ["TUDO OK" if fails == 0 else "HÁ FALHAS", fails])
	get_tree().quit()
