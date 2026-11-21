extends Node
## Simulação da Fase 4 (Núcleo Quântico, greybox A–D): percorre o caminho por
## input com guardas e câmeras congelados e confere cada passagem. Uso:
##   godot --headless --path . res://tests/stage4_sim.tscn

const LEVEL := "res://scenes/levels/core/core_stage4.tscn"

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


func walk_until(dir: String, x_goal: float, max_frames: int = 1500) -> void:
	Input.action_press(dir)
	for i in max_frames:
		await get_tree().physics_frame
		if (dir == "move_right" and p.global_position.x > x_goal) or (dir == "move_left" and p.global_position.x < x_goal):
			break
	release_all()
	await step(10)


func _ready() -> void:
	lvl = load(LEVEL).instantiate()
	# A porta leva à arena do Duelo de verdade: guardada e desligada para seguir aqui.
	var exit_target: String = lvl.get_node("LevelExit").get("next_stage")
	lvl.get_node("LevelExit").set("next_stage", "")
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(30)
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	for c in get_tree().get_nodes_in_group("security_camera"):
		c.process_mode = Node.PROCESS_MODE_DISABLED

	check("andar 4 no GameManager", GameManager.current_floor == 4)
	check("spawn no chão do elevador", absf(p.global_position.y - 16.0) < 3.0, pos())
	for i in 10:
		await get_tree().process_frame
	check("diálogo de elevador do Núcleo abre", Dialogue.is_open() and Dialogue.lines_for("core_elevator").size() >= 4)
	check("a Axioma fala no diálogo de chegada", Dialogue.lines_for("core_elevator").any(func(l): return l["who"] == "AXIOMA"))
	Dialogue.skip()
	await step(5)

	# B: pontes de luz sobre o abismo.
	var hv := p.get_node("HackVision") as HackVision
	var br1 := lvl.get_node("LightBridges/Bridge13") as LightBridge
	var br2 := lvl.get_node("LightBridges/Bridge28") as LightBridge
	var br3 := lvl.get_node("LightBridges/Bridge43") as LightBridge
	var h1 := br1.get_node("Hackable") as Hackable
	check("B: ponte 1 começa apagada e hackeável", not br1.is_solid() and br1.can_be_hacked() and h1.get_label() == "PONTE DE LUZ")
	check("B: emissor da ponte pede equação de câmera do andar (nível 4)", h1.get_difficulty() == Vector2i(4, 0))
	# Ponte apagada: cai no abismo, volta à plataforma A e perde defesa.
	var d0 := p.current_defense
	var falls := [0]
	(lvl.get_node("Abyss") as AbyssZone).player_fell.connect(func(_r: Vector2) -> void: falls[0] += 1)
	tp(470, 0); await step(90)  # em cima da ponte apagada
	check("abismo: queda volta à plataforma A", falls[0] == 1 and absf(p.global_position.x - 360.0) < 30.0 and absf(p.global_position.y - 16.0) < 8.0, pos())
	check("abismo: queda tira Defesa Neural (sem game over)", p.current_defense == d0 - 20.0 and not p.is_dead, "%.0f -> %.0f" % [d0, p.current_defense])
	# Hack materializa a ponte: dá para atravessar.
	hv.debug_hack(h1, true); await step(3)
	check("B: hack materializa a ponte 1", br1.is_solid() and not br1.can_be_hacked())
	tp(330, 16); await step(5)
	await walk_until("move_right", 760.0)
	check("B: atravessa a ponte 1 até a plataforma flutuante", p.global_position.x > 740.0 and absf(p.global_position.y - 16.0) < 6.0, pos())
	while br1._hold_left > br1.warn_time - 0.3:
		await step(1)
	check("B: ponte pisca antes de sumir", br1.is_warning() and br1.is_solid())
	await step(int(br1.warn_time * 60.0) + 10)
	check("B: ponte some sozinha", not br1.is_solid() and br1.can_be_hacked())
	# Ponte 2: liga e desliga sozinha; atravessa quando está ligada.
	var seen_on := false
	var seen_off := false
	for i in 320:
		await step(1)
		seen_on = seen_on or br2.is_solid()
		seen_off = seen_off or not br2.is_solid()
	check("B: ponte 2 liga e desliga sozinha", seen_on and seen_off and br2.mode == LightBridge.Mode.TIMED)
	while br2.is_solid():
		await step(1)
	while not br2.is_solid():
		await step(1)
	tp(860, 16); await step(2)
	Input.action_press("run")
	await walk_until("move_right", 1180.0, 200)
	check("B: atravessa a ponte 2 no tempo dela", p.global_position.x > 1160.0 and absf(p.global_position.y - 16.0) < 6.0, pos())
	# Ponte 3 (sob a câmera): hack e atravessa até a galeria.
	hv.debug_hack(br3.get_node("Hackable"), true); await step(3)
	tp(1300, 16); await step(5)
	await walk_until("move_right", 1640.0)
	check("B: ponte 3 leva à galeria", p.global_position.x > 1600.0 and absf(p.global_position.y - 16.0) < 6.0, pos())

	# C: galeria dos servidores.
	await climb(58 * 32 + 16, 16.0)
	check("C: escada leva ao mezanino (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, pos())
	tp(1900, 16); await step(10)
	check("C: servidor escuro serve de esconderijo", p.can_hide(), pos())
	var cyborgs := lvl.get_node("Guards").get_children().filter(func(g): return g.enemy_type == Enemy.EnemyType.CYBORG)
	check("C: duas Unidades Lógicas protegem a galeria", cyborgs.size() == 2)
	var cy_h := (cyborgs[0] as Node).get_node("Hackable") as Hackable
	check("C: hackear a Unidade Lógica pede o nível 5", cy_h.get_difficulty() == Vector2i(5, 1), str(cy_h.get_difficulty()))
	check("Núcleo inteiro é segurança máxima", absf(cy_h.get_time_mult() - 0.8) < 0.001
		and absf((lvl.get_node("Cameras/BridgeCamera/Hackable") as Hackable).get_time_mult() - 0.8) < 0.001)
	var lasers := lvl.get_node("Lasers").get_children()
	check("C: lasers temporizados no chão da galeria", lasers.size() == 2 and lasers.all(func(l): return l.mode == LaserBarrier.Mode.TIMED))
	tp(2050, -144); await step(5)
	await walk_until("move_right", 3100.0)
	check("C: o mezanino passa por cima dos lasers", p.global_position.x > 3080.0 and absf(p.global_position.y + 144.0) < 6.0, pos())

	# D: antecâmara e porta do Domo.
	tp(3600, 16); await step(5)
	await walk_until("move_right", 4000.0, 600)
	var exit := lvl.get_node("LevelExit") as LevelExit
	check("D: porta do Domo (saída) alcançável", exit.overlaps_body(p), pos())
	check("D: porta leva à arena do Duelo", exit_target == GameManager.LEVELS[5]["scene"], exit_target)

	# Primeiro alarme do Núcleo: a Axioma fala pelos alto-falantes (uma vez).
	GameManager.raise_alarm(p.global_position)
	for i in 10:
		await get_tree().process_frame
	check("primeiro alarme: a Axioma fala pelos alto-falantes", Dialogue.is_open() and Dialogue.current_speaker() == "AXIOMA")
	Dialogue.skip()
	GameManager.raise_alarm(p.global_position)
	for i in 10:
		await get_tree().process_frame
	check("segundo alarme: não repete a fala", not Dialogue.is_open())

	# Por último (abre o game over): cair com pouca defesa desconecta.
	p.current_defense = 15.0
	tp(1500, 300); await step(10)
	check("abismo: com pouca defesa a queda desconecta", p.is_dead)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
