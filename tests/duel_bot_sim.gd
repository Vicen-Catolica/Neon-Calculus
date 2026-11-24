extends Node
## Playtest automatizado do Duelo de Paradoxo (etapa 12 da Fase 4): um "jogador
## robô" que só desvia usando o que a tela mostra (a brecha da varredura, o setor
## livre do pulso, os vãos da grade; agacha na varredura lateral) e hackeia o nó
## ativo depois de alguns segundos. Se o robô vence sem morrer em várias
## sementes, os padrões são justos (sempre há saída a tempo). Uso:
##   godot --headless --path . res://tests/duel_bot_sim.tscn

const LEVEL := "res://scenes/levels/core/core_duel.tscn"
const SEEDS := [3, 11, 29]
## Segundos lutando em cada camada antes de "acertar" a equação do nó.
const FIGHT_PER_LAYER := 9.0

var fails := 0


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func release_all() -> void:
	for a in ["move_left", "move_right", "run", "crouch"]:
		Input.action_release(a)


## Onde ficar (x no piso `span` = (x0, x1, y)) e se agachar, olhando os ataques vivos.
func plan(p: Node2D, core: Node2D, span: Vector3 = Vector3(60, 1860, 16)) -> Array:
	var x := p.global_position.x
	var target := x
	var crouch := false
	var attacks := get_tree().get_nodes_in_group("duel_attack")
	var grid: LaserGridAttack = null
	for a in attacks:
		if a is LaserGridAttack and a.phase != DuelAttack.Phase.DONE:
			grid = a
	var has_down := false
	for a in attacks:
		if a.phase == DuelAttack.Phase.DONE or a.phase == DuelAttack.Phase.IDLE:
			continue
		if a is SweepAttack:
			var s := a as SweepAttack
			if s.dir == SweepAttack.Dir.DOWN:
				target = s.gap_center
				has_down = true
			else:
				crouch = true
		elif a is PulseAttack and not has_down:
			# borda mais próxima da brecha, um pouco para dentro
			var pu := a as PulseAttack
			var my := rad_to_deg((p.global_position + Vector2(0, -50) - pu.center).angle())
			var diff := wrapf(pu.gap_angle_deg - my, -180.0, 180.0)
			var inside := absf(diff) - pu.gap_width_deg / 2.0 + 8.0
			if inside > 0.0:
				var ang := deg_to_rad(my + signf(diff) * inside)
				var dy := (span.z - 50.0) - pu.center.y
				if absf(sin(ang)) > 0.08 and signf(sin(ang)) == signf(dy):
					target = pu.center.x + dy * cos(ang) / sin(ang)
	if grid and not has_down:
		# vão mais perto entre as colunas
		var best := target
		var best_d := INF
		var xs: Array = []
		for c in grid.columns:
			xs.append(c)
		xs.sort()
		var cand: Array = [span.x + 16.0, span.y - 16.0]
		for i in xs.size() - 1:
			cand.append((xs[i] + xs[i + 1]) / 2.0)
		for c in cand:
			if c < span.x or c > span.y:
				continue
			var clear := true
			for col in xs:
				if absf(c - col) < 50.0:
					clear = false
			if not clear:
				continue
			if absf(c - target) < best_d:
				best_d = absf(c - target)
				best = c
		target = best
	return [clampf(target, span.x + 16.0, span.y - 16.0), crouch]


func run_duel(seed: int) -> Array:
	GameManager.reset_progress()
	GameManager.mark_dialogue_seen("duel_confront")
	var lvl: Node = load(LEVEL).instantiate()
	var duel := lvl.get_node("ParadoxDuel") as ParadoxDuel
	duel.rng_seed = seed
	duel.go_to_ending = false
	add_child(lvl)
	var p := lvl.get_node("Eduardo") as Eduardo
	var hv := p.get_node("HackVision") as HackVision
	var hits := [0]
	var layer_time := 0.0
	var paradox_time := 0.0
	var frames := 0
	var last_def := p.current_defense
	while frames < 60 * 90 and duel.state != ParadoxDuel.State.WON and not p.is_dead:
		await get_tree().physics_frame
		frames += 1
		if Dialogue.is_open():
			Dialogue.skip()
		var pl := plan(p, duel.core)
		if OS.has_environment("BOT_DEBUG") and p.current_defense < last_def:
			var desc := []
			for a in get_tree().get_nodes_in_group("duel_attack"):
				var info := "%s ph%d" % [a.get_class() if a.get_script() == null else a.get_script().get_global_name(), a.phase]
				if a is SweepAttack:
					info += " dir%d gap%.0f pos%.0f" % [a.dir, a.gap_center, a.pos]
				elif a is PulseAttack:
					info += " gapang%.0f r%.0f" % [a.gap_angle_deg, a.radius]
				elif a is LaserGridAttack:
					info += " cols%s" % str(a.columns)
				desc.append(info)
			print("   HIT layer%d x=%.0f y=%.0f alvo=%.0f crouch=%s :: %s" % [duel.layer, p.global_position.x, p.global_position.y, pl[0], pl[1], desc])
		last_def = p.current_defense
		var dx: float = pl[0] - p.global_position.x
		release_all()
		if pl[1]:
			Input.action_press("crouch")
		if absf(dx) > 14.0:
			Input.action_press("run")
			Input.action_press("move_right" if dx > 0 else "move_left")
		var dt := 1.0 / 60.0
		if duel.state == ParadoxDuel.State.LAYER and duel.nodes[duel.layer - 1].can_be_hacked():
			layer_time += dt
			if layer_time >= FIGHT_PER_LAYER:
				layer_time = 0.0
				hv.debug_hack(duel.nodes[duel.layer - 1].get_node("Hackable"), true)
		elif duel.state == ParadoxDuel.State.PARADOX:
			paradox_time += dt
			if paradox_time >= 5.0:
				hv.debug_hack(duel.core.get_node("Hackable"), true)
	release_all()
	var res := [duel.state == ParadoxDuel.State.WON, p.is_dead, p.current_defense, duel.attacks_spawned]
	lvl.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return res


## Passarelas: o robô fica no piso dele (nunca desce) e cada padrão é disparado
## várias vezes. Todo padrão tem que ter saída ali mesmo.
const PERCHES := [
	["passarela esquerda", Vector2(290, -272)],
	["passarela direita", Vector2(1630, -272)],
	["passarela do meio", Vector2(600, -464)],
	["passarela de cima", Vector2(900, -624)],
]
const KINDS := ["sweep_down", "pulse", "sweep_side", "grid", "combo"]


func run_perch(label: String, at: Vector2, seed: int) -> void:
	GameManager.reset_progress()
	GameManager.mark_dialogue_seen("duel_confront")
	var lvl: Node = load(LEVEL).instantiate()
	var duel := lvl.get_node("ParadoxDuel") as ParadoxDuel
	duel.rng_seed = seed
	duel.go_to_ending = false
	add_child(lvl)
	duel.set_process(false)
	duel.layer = 3
	var p := lvl.get_node("Eduardo") as Eduardo
	p.global_position = at + Vector2(0, -4)
	p.velocity = Vector2.ZERO
	for i in 20:
		await get_tree().physics_frame
	var span := duel.player_span()
	var hits := {}
	var fell := false
	for rep in 2:
		for kind in KINDS:
			duel.spawn_pattern(kind)
			var got := [0]
			for a in get_tree().get_nodes_in_group("duel_attack"):
				(a as DuelAttack).hit_player.connect(func() -> void: got[0] += 1)
			var frames := 0
			while duel.attack_running() and frames < 60 * 6:
				await get_tree().physics_frame
				frames += 1
				if Dialogue.is_open():
					Dialogue.skip()
				var pl := plan(p, duel.core, span)
				var dx: float = pl[0] - p.global_position.x
				release_all()
				if pl[1]:
					Input.action_press("crouch")
				if absf(dx) > 10.0:
					Input.action_press("run")
					Input.action_press("move_right" if dx > 0 else "move_left")
			release_all()
			for i in 30:
				await get_tree().physics_frame
			hits[kind] = int(hits.get(kind, 0)) + got[0]
			if absf(p.global_position.y - span.z) > 6.0:
				fell = true
	check("%s: robô desvia de tudo sem sair da passarela" % label,
		not fell and hits.values().reduce(func(a, b): return a + b, 0) == 0,
		"piso %.0f..%.0f y%.0f, acertos %s%s" % [span.x, span.y, span.z, str(hits), ", caiu" if fell else ""])
	lvl.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _ready() -> void:
	await get_tree().process_frame
	for i in PERCHES.size():
		await run_perch(PERCHES[i][0], PERCHES[i][1], 7 + i * 13)
	for s in SEEDS:
		var r: Array = await run_duel(s)
		check("robô que desvia vence o Duelo (semente %d)" % s, r[0] and not r[1],
			"defesa final %.0f, %d ataques" % [r[2], r[3]])
	GameManager.reset_progress()
	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
