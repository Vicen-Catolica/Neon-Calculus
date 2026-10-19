extends Node
## Percorre o 2º andar da Fase 1 por input: escadas do poço, saltos entre lajes
## (com o pulo antigo -380 e o atual), passagem agachada sob o puxadinho e a
## escada final no escuro. Uso:
##   godot --headless --path . res://tests/route_sim.tscn

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


## Corre para a esquerda e pula na beirada; espera aterrissar.
func run_jump_left(start_x: float, y: float, edge_x: float) -> void:
	tp(start_x, y)
	await step(10)
	Input.action_press("run")
	Input.action_press("move_left")
	var jumped_at := -1
	for i in 300:
		await get_tree().physics_frame
		if jumped_at < 0 and p.global_position.x <= edge_x + 14.0:
			Input.action_press("jump")
			jumped_at = i
		elif jumped_at >= 0 and i - jumped_at > 10 and p.is_on_floor():
			break
	await step(4)
	release_all()
	await step(15)


## Sobe a escada (anda até ela no chão e segura "cima").
func climb(x: float, y: float, frames: int) -> void:
	tp(x, y)
	await step(8)
	Input.action_press("climb_up")
	await step(frames)
	release_all()
	await step(30)


func _ready() -> void:
	lvl = load("res://scenes/levels/slums/slums_stage1.tscn").instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(20)
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	var exit := lvl.get_node("ExitToStage2")
	exit.set("next_stage", "")  # não troca de cena no teste

	# Poço: zigue-zague de escadas até o telhado da torre.
	var ladders := [[163, -48.0, -176.0], [157, -176.0, -304.0], [163, -304.0, -432.0],
		[157, -432.0, -560.0], [163, -560.0, -688.0], [157, -688.0, -816.0]]
	for l in ladders:
		await climb(l[0] * 32 + 16, l[1], 220)
		check("poço: escada x=%d leva a y=%.0f" % [l[0], l[2]], absf(p.global_position.y - l[2]) < 6.0,
			"y=%.1f" % p.global_position.y)

	var gaps := [
		# [rótulo, x inicial, y, beirada, y esperado, x mínimo, x máximo]
		["torre -> laje H1", 4800.0, -816.0, 4688.0, -752.0, 4272.0, 4592.0],
		["H1 -> ponte (pulo alto pode passar direto para H2)", 4400.0, -752.0, 4272.0, -752.0, 4032.0, 4224.0, -688.0],
		["ponte -> H2", 4180.0, -752.0, 4040.0, -688.0, 3600.0, 4000.0],
		["H2 -> H3", 3760.0, -688.0, 3600.0, -688.0, 3216.0, 3504.0],
		["H3 -> H4", 3380.0, -688.0, 3216.0, -624.0, 2960.0, 3120.0],
		["H4 -> H5 (sobe 32)", 2830.0, -624.0, 2768.0, -656.0, 2384.0, 2704.0],
		["H5 -> H6 (sobe 32)", 2550.0, -656.0, 2384.0, -688.0, 1968.0, 2288.0],
		["H6 -> H7", 2130.0, -688.0, 1968.0, -624.0, 1424.0, 1872.0],
		["ponte -> H8 (sobe 32)", 1400.0, -624.0, 1250.0, -656.0, 976.0, 1232.0],
		["H8 -> H9", 1140.0, -656.0, 976.0, -592.0, 528.0, 880.0],
		["H9 -> H10 (sobe 32)", 700.0, -592.0, 528.0, -624.0, 80.0, 432.0],
	]
	for jv in [-380.0, -600.0]:
		p.jump_velocity = jv
		for g in gaps:
			await run_jump_left(g[1], g[2], g[3])
			var pos := p.global_position
			var alt_y: float = g[7] if g.size() > 7 else g[4]
			var landed := absf(pos.y - g[4]) < 6.0 or absf(pos.y - alt_y) < 6.0 or (not p.is_on_floor() and pos.y < alt_y)
			check("[pulo %.0f] %s" % [jv, g[0]], landed and pos.x <= g[6] + 4.0,
				"x=%.0f y=%.1f" % [pos.x, pos.y])

	# Puxadinho: em pé bloqueia, agachado passa.
	tp(3080, -624); await step(10)
	Input.action_press("move_left"); await step(150)
	check("puxadinho bloqueia em pé", p.global_position.x > 2950.0, "x=%.0f" % p.global_position.x)
	Input.action_press("crouch"); await step(20)
	for i in 400:
		await get_tree().physics_frame
		if p.global_position.x < 2815.0:
			break
	Input.action_release("move_left"); await step(10)
	check("puxadinho passa agachado", p.global_position.x < 2832.0 and absf(p.global_position.y + 624.0) < 4.0,
		"x=%.0f y=%.1f" % [p.global_position.x, p.global_position.y])
	release_all(); await step(30)

	# Escada final até o patamar no escuro (y = -1136), dentro da saída.
	await climb(4 * 32 + 16, -624.0, 520)
	check("escada final leva ao patamar escuro", absf(p.global_position.y + 1136.0) < 6.0, "y=%.1f" % p.global_position.y)
	check("patamar está dentro da saída", (exit as Area2D).overlaps_body(p))

	print("\n%s — %d falha(s)" % ["TUDO OK" if fails == 0 else "HÁ FALHAS", fails])
	get_tree().quit()
