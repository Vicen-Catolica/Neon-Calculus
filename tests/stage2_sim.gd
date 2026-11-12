extends Node
## Simulação da Fase 2 (Setor Industrial, greybox): percorre A–E por input com
## os guardas congelados e confere cada passagem. Uso:
##   godot --headless --path . res://tests/stage2_sim.tscn

const LEVEL := "res://scenes/levels/industrial/industrial_stage2.tscn"

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
	for a in ["move_left", "move_right", "run", "jump", "crouch", "climb_up", "climb_down"]:
		Input.action_release(a)


func walk_right(frames: int, crouched: bool = false) -> void:
	if crouched:
		Input.action_press("crouch")
	Input.action_press("move_right")
	await step(frames)
	release_all()
	await step(10)


## Sobe uma escada a partir da base (x, y), segurando "cima".
func climb(x: float, y: float, frames: int = 260) -> void:
	tp(x, y)
	await step(8)
	Input.action_press("climb_up")
	await step(frames)
	release_all()
	await step(30)


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

	check("andar 2 no GameManager", GameManager.current_floor == 2)
	check("spawn no chão da sala de chegada", absf(p.global_position.y - 16.0) < 3.0, pos())

	# A: duto de 96 px — em pé não entra, agachado passa.
	await walk_right(150)
	check("em pé não entra no duto", p.global_position.x < 240.0, pos())
	Input.action_press("crouch")
	Input.action_press("move_right")
	for i in 1200:
		await get_tree().physics_frame
		if p.global_position.x > 830.0:
			break
	release_all()
	await step(20)
	check("agachado atravessa o duto", p.global_position.x > 800.0, pos())
	check("levanta na saída do duto", p.state != Eduardo.State.CROUCH and p.state != Eduardo.State.CROUCH_WALK, Eduardo.State.keys()[p.state])

	# B: escada para a passarela das caldeiras.
	await climb(31 * 32 + 16, 16.0)
	check("B: escada leva à passarela (y≈-144)", absf(p.global_position.y + 144.0) < 6.0, pos())

	# C: passarela alta e fosso.
	await climb(77 * 32 + 16, 16.0)
	check("C: escada leva à passarela alta (y≈-112)", absf(p.global_position.y + 112.0) < 6.0, pos())
	tp(2600, 16); await step(10)
	await walk_right(150)
	check("C: cai no fosso pelo patamar", absf(p.global_position.y - 112.0) < 6.0, pos())
	await climb(103 * 32 + 16, 112.0, 220)
	check("C: escada tira do fosso (y≈16)", absf(p.global_position.y - 16.0) < 6.0, pos())
	var dome := lvl.get_node("Cameras/AssemblyDome") as Node2D
	check("C: domo da montagem não alcança o fundo do fosso",
		dome.global_position.y + float(dome.get("vision_range")) < 112.0 - 100.0)

	# D: porta biométrica na saída dos servidores.
	tp(4580, 16); await step(10)
	await walk_right(120)
	check("D: porta trancada bloqueia", p.global_position.x < 4700.0, pos())
	var hv := p.get_node("HackVision") as HackVision
	hv.debug_hack(lvl.get_node("SecurityDoor/Hackable"), true)
	await step(40)
	await walk_right(120)
	check("D: porta hackeada deixa passar para o poço", p.global_position.x > 4860.0, pos())

	# E: zigue-zague de 8 escadas até o elevador.
	var ladders := [[163, 16.0], [154, -112.0], [163, -240.0], [154, -368.0],
		[163, -496.0], [154, -624.0], [163, -752.0], [154, -880.0]]
	var ok := true
	for l in ladders:
		await climb(l[0] * 32 + 16, l[1])
		if absf(p.global_position.y - (l[1] - 128.0)) > 6.0:
			ok = false
			print("   parou em ", pos(), " (escada x=", l[0], ")")
			break
	check("E: sobe o poço até o topo (y≈-1008)", ok and absf(p.global_position.y + 1008.0) < 6.0, pos())
	tp(5230, -1008); await step(10)
	var exit := lvl.get_node("LevelExit") as Area2D
	check("E: elevador (saída) alcançável no topo", exit.overlaps_body(p))

	# Vapor: guarda e câmera não enxergam através nem dentro da nuvem.
	var valve := lvl.get_node("SteamValves/BoilerValveFloor") as SteamValve
	var guard := lvl.get_node("Guards/Guard1") as Enemy
	guard.global_position = Vector2(1350, 16)
	tp(1760, 16); await step(5)
	check("sem vapor o guarda vê o jogador", guard.has_line_of_sight_to(p, p.get_aim_point()))
	check("válvula fechada pode ser hackeada", valve.can_be_hacked())
	hv.debug_hack(valve.get_node("Hackable"), true); await step(5)
	check("hack abre o vapor", valve.active and valve.is_blocking())
	check("vapor tapa a visão do guarda", not guard.has_line_of_sight_to(p, p.get_aim_point()))
	tp(1560, 16); await step(5)
	check("dentro do vapor o jogador some", not guard.has_line_of_sight_to(p, p.get_aim_point()))
	check("válvula aberta não aceita novo hack", not valve.can_be_hacked())
	var server := lvl.get_node("SteamValves/ServerValve") as SteamValve
	var dome2 := lvl.get_node("Cameras/ServerDome2") as Node2D
	var lens: Vector2 = dome2.global_position + dome2.lens_local()
	server.open()
	check("vapor dos servidores tapa o domo", VisionBlocker.line_blocked(get_tree(), lens, Vector2(4250, -40)))
	server.close()
	check("sem vapor o domo vê de novo", not VisionBlocker.line_blocked(get_tree(), lens, Vector2(4250, -40)))
	await step(int(valve.steam_time * 60.0) + 20)
	check("vapor acaba sozinho", not valve.active)
	check("guarda volta a ver depois do vapor", guard.has_line_of_sight_to(p, p.get_aim_point()))
	check("cooldown antes do próximo hack", not valve.can_be_hacked())
	await step(int(valve.cooldown * 60.0) + 20)
	check("válvula rearma depois do cooldown", valve.can_be_hacked())

	# Lore: todo terminal aponta para uma entrada existente.
	var missing := []
	for t in lvl.get_node("DataTerminals").get_children():
		if LoreDatabase.get_entry(String(t.get("entry_id"))).is_empty():
			missing.append(t.get("entry_id"))
	check("terminais têm lore no JSON", missing.is_empty(), str(missing))

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
