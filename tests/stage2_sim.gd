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
	# A saída leva à Fase 3 de verdade: desligada para a simulação seguir nesta cena.
	lvl.get_node("LevelExit").set("next_stage", "")
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(30)
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	for c in get_tree().get_nodes_in_group("security_camera"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	for d in get_tree().get_nodes_in_group("drones"):
		d.process_mode = Node.PROCESS_MODE_DISABLED

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
	# cai no fundo (112) ou em cima da esteira (102)
	check("C: cai no fosso pelo patamar", p.global_position.y > 98.0 and p.global_position.y < 116.0, pos())
	# Esteira do fosso: corre para a esquerda, contra o jogador.
	var belt := lvl.get_node("Conveyors/PitConveyor") as Conveyor
	var hv0 := p.get_node("HackVision") as HackVision
	tp(3050, 100); await step(15)
	var x0 := p.global_position.x
	check("C: pisa na esteira (y≈102)", absf(p.global_position.y - 102.0) < 4.0, pos())
	await step(60)
	check("C: esteira arrasta o jogador parado", p.global_position.x < x0 - 100.0, "%.0f -> %.0f" % [x0, p.global_position.x])
	tp(3050, 100); await step(10)
	await walk_right(120)
	check("C: andando não vence a esteira", p.global_position.x < 3050.0, pos())
	hv0.debug_hack(belt.get_node("Hackable"), true); await step(5)
	check("C: hack para a esteira", not belt.running and not belt.can_be_hacked())
	check("barra do hack na esteira", (belt.get_node("Hackable") as Hackable).time_left_ratio() > 0.9)
	tp(3050, 100); await step(10)
	await walk_right(120)
	check("C: com a esteira parada dá para atravessar", p.global_position.x > 3200.0, pos())
	await step(int(belt.stop_time * 60.0) + 20)
	check("C: esteira volta a rodar sozinha", belt.running)
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
	check("barra do hack na válvula", (valve.get_node("Hackable") as Hackable).time_left_ratio() > 0.9)
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

	# Drone do chão (playtest à mão: só via quem estava na esteira): vê o chão à frente.
	var fdrone := lvl.get_node("Drones/FloorDrone") as PatrolDrone
	fdrone.global_position = Vector2(2300, -60)
	fdrone.facing = 1.0
	tp(2440, 16); await step(5)
	check("drone do chão vê o jogador no chão à frente", fdrone.sees_player())
	tp(2300 + 400, 16); await step(5)
	check("drone do chão não vê além do alcance", not fdrone.sees_player())
	tp(2150, 16); await step(5)
	check("drone do chão não vê atrás dele", not fdrone.sees_player())
	var pdrone := lvl.get_node("Drones/PitDrone") as PatrolDrone
	pdrone.global_position = Vector2(2780, -30)
	pdrone.facing = 1.0
	tp(2900, 16); await step(5)
	check("drone do fosso vê o jogador fora da esteira (na beira)", pdrone.sees_player() or absf(2900.0 - 2780.0) > pdrone.vision_range)

	# Drone do fosso: vê, dispara alarme, e o hack o reinicia.
	var drone := lvl.get_node("Drones/PitDrone") as PatrolDrone
	var alarms := [0]
	GameManager.alarm_raised.connect(func(_p: Vector2) -> void: alarms[0] += 1)
	belt.stop()
	drone.point_a = Vector2(2900, -30)
	drone.point_b = Vector2(3300, -30)
	drone.global_position = Vector2(2900, -30)
	drone.facing = 1.0
	tp(2945, 100); await step(10)
	drone.process_mode = Node.PROCESS_MODE_INHERIT
	await step(5)
	check("drone vê o jogador no fosso", drone.mode == PatrolDrone.Mode.ALERT, PatrolDrone.Mode.keys()[drone.mode])
	await step(90)
	check("drone dispara o alarme", alarms[0] > 0, "alarmes=%d" % alarms[0])
	# Em alerta, segue o jogador (antes parava no ar).
	var x_before := drone.global_position.x
	for i in 100:  # anda para a direita a ~120 px/s
		tp(2945 + i * 2, 100)
		await step(1)
	await step(30)
	check("drone em alerta segue o jogador", drone.global_position.x > x_before + 100.0 and drone.mode == PatrolDrone.Mode.ALERT,
		"%.0f -> %.0f" % [x_before, drone.global_position.x])
	hv.debug_hack(drone.get_node("Hackable"), true); await step(5)
	check("hack reinicia o drone", drone.mode == PatrolDrone.Mode.REBOOT and not drone.sees_player())
	check("drone reiniciando não aceita novo hack", not drone.can_be_hacked())
	var dh := drone.get_node("Hackable") as Hackable
	var r0 := dh.time_left_ratio()
	await step(60)
	check("barra do hack no drone aparece e esvazia", r0 > 0.9 and dh.time_left_ratio() < r0 - 0.05, "%.2f -> %.2f" % [r0, dh.time_left_ratio()])
	var x_reboot := drone.global_position.x
	await step(60)
	check("drone parado durante o reboot", absf(drone.global_position.x - x_reboot) < 0.5)
	tp(2000, 16)  # sai do alcance antes de o drone religar
	await step(int(drone.reboot_time * 60.0))
	check("drone volta a patrulhar", drone.mode == PatrolDrone.Mode.PATROL, PatrolDrone.Mode.keys()[drone.mode])
	var x_patrol := drone.global_position.x
	await step(60)
	check("drone voa entre os pontos", absf(drone.global_position.x - x_patrol) > 30.0, "%.0f -> %.0f" % [x_patrol, drone.global_position.x])
	drone.process_mode = Node.PROCESS_MODE_DISABLED

	# Lore: todo terminal aponta para uma entrada existente.
	var missing := []
	for t in lvl.get_node("DataTerminals").get_children():
		if LoreDatabase.get_entry(String(t.get("entry_id"))).is_empty():
			missing.append(t.get("entry_id"))
	check("terminais têm lore no JSON", missing.is_empty(), str(missing))

	# Lockdown da sala dos servidores (D).
	var zone := lvl.get_node("ServerLockdown") as LockdownZone
	var shutter := lvl.get_node("LockdownShutterWest") as SecurityDoor
	var exit_door := lvl.get_node("SecurityDoor") as SecurityDoor
	var exit_h := exit_door.get_node("Hackable") as Hackable
	check("porta blindada começa aberta e fora da visão hacker", shutter.is_open and not shutter.get_node("Hackable").enabled)
	tp(3400, 16); await step(5)
	GameManager.raise_alarm(Vector2(3000, 16)); await step(5)
	check("alarme com o jogador fora da sala não fecha nada", not zone.active)
	tp(4000, 16); await step(10)
	check("zona sabe que o jogador está dentro", zone.is_player_inside())
	GameManager.raise_alarm(p.global_position); await step(30)
	check("alarme dentro da sala inicia o lockdown", zone.active)
	check("portas fecham", not shutter.is_open and not exit_door.is_open)
	tp(4500, 16); await step(5)
	await walk_right(200)
	check("lockdown: saída bloqueada", p.global_position.x < 4700.0, pos())
	tp(3800, 16); await step(5)
	Input.action_press("move_left"); await step(200); release_all(); await step(10)
	check("lockdown: entrada bloqueada", p.global_position.x > 3590.0, pos())
	check("saída vira equação +1 e mais curta", exit_h.get_difficulty().x == 3 and exit_h.time_limit_mult < 1.0,
		"nível=%d tempo x%.2f" % [exit_h.get_difficulty().x, exit_h.time_limit_mult])
	var t_before := zone.time_left
	await step(60)
	check("contagem regressiva anda", zone.time_left < t_before - 0.8, "%.1f -> %.1f" % [t_before, zone.time_left])
	hv.debug_hack(exit_h, true); await step(60)
	check("hackear a saída encerra o lockdown", not zone.active and zone.done)
	check("portas reabrem", shutter.is_open and exit_door.is_open)
	check("saída volta à dificuldade normal", exit_h.get_difficulty().x == 2 and exit_h.time_limit_mult == 1.0)
	GameManager.raise_alarm(p.global_position); await step(5)
	check("lockdown não dispara de novo na mesma fase", not zone.active)

	# Alarme vindo de um guarda em alerta máximo também tranca a sala.
	zone.done = false
	(lvl.get_node("Guards/Guard4") as Enemy).alarm_triggered.emit(p.global_position); await step(5)
	check("alerta máximo de guarda inicia o lockdown", zone.active)
	# Tempo esgotado: unidades pesadas = capturado.
	zone.time_left = 0.05
	await step(5)
	check("tempo esgotado captura o Eduardo", p.is_dead and not zone.active)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
