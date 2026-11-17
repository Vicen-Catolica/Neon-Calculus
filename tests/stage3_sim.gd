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
	tp(2700, 16); await step(10)
	await walk("move_right", 200)
	check("C: corredor atravessável pelo chão", p.global_position.x > 3000.0, pos())
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
	var corridor_cam := lvl.get_node("Cameras/CorridorCamera") as Node2D
	check("C: a câmera do corredor fica abaixo do duto", corridor_cam.global_position.y > -272.0)

	# D: mezanino dos laboratórios (Lab 07).
	await climb(117 * 32 + 16, 16.0)
	check("D: escada leva ao mezanino do Lab 07 (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, pos())
	var cy := lvl.get_node("Guards/Guard4") as Enemy
	check("D: guarda do chão é Unidade Lógica", cy.enemy_type == Enemy.EnemyType.CYBORG)
	check("D: Unidade Lógica pede hack mais difícil", cy.get_node("Hackable").get_difficulty() == Vector2i(4, 1))

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
	check("E: saída desligada até existir a Fase 4", exit.next_stage == "")

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
	hv.debug_hack(exit_h, true); await step(60)
	check("hackear a saída encerra o lockdown", not zone.active and shutter.is_open and exit_door.is_open)
	check("fim do lockdown: hack volta a ser abortável", exit_h.abortable)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
