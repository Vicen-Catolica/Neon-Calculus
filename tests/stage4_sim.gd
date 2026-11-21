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

	# B: plataformas flutuantes ligadas pelas pontes (provisórias até a etapa 4).
	await walk_until("move_right", 1640.0)
	check("B: atravessa as pontes até a galeria", p.global_position.x > 1600.0 and absf(p.global_position.y - 16.0) < 6.0, pos())
	check("B: 3 pontes de luz marcadas", lvl.get_node("BridgeSlots").get_child_count() == 3)
	# Cair no abismo não prende: piso de segurança + escada de volta.
	tp(16 * 32 + 60, 200); await step(90)
	check("abismo: cai no piso de segurança", absf(p.global_position.y - 336.0) < 6.0, pos())
	await climb(16 * 32 + 16, 336.0, 420)
	check("abismo: escada leva de volta à ponte (y≈16)", absf(p.global_position.y - 16.0) < 6.0, pos())

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
	check("D: porta desligada até existir o Duelo", exit.next_stage == "")

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
