extends Node
## Balanceamento (etapa 10 da Fase 3): mede os números que decidem se o andar é
## justo e imprime uma tabela para o playtest. Falha só quando um número sai do
## limite do que o jogador consegue fazer. Uso:
##   godot --headless --path . res://tests/balance_sim.tscn

const LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"
const SAMPLES := 30

var fails := 0
var ui


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


## Tempo limite (s) de SAMPLES equações do tipo pedido: [mín, média, máx].
func limits(level: int, sub: int, mult: float = 1.0) -> Array:
	var lo := 9999.0
	var hi := 0.0
	var sum := 0.0
	for i in SAMPLES:
		ui.time_limit_mult = mult
		ui.start_hacking(level, sub)
		await get_tree().process_frame
		await get_tree().process_frame
		var t: float = ui.hack_timer.wait_time
		lo = minf(lo, t)
		hi = maxf(hi, t)
		sum += t
		ui._complete_hack(false)
		await get_tree().process_frame
	return [lo, sum / SAMPLES, hi]


func _ready() -> void:
	var lvl: Node = load(LEVEL).instantiate()
	lvl.get_node("LevelExit").set("next_stage", "")  # não troca de fase no meio
	add_child(lvl)
	for i in 10:
		await get_tree().process_frame
	if Dialogue.is_open():
		Dialogue.skip()
	ui = get_tree().get_first_node_in_group("hacking_ui")
	GameManager.story_flags.clear()

	print("--- Tempo limite das equações (s): mín / média / máx ---")
	var names := {
		Vector2i(1, 0): "andar 1, adição", Vector2i(1, 1): "andar 1, multiplicação",
		Vector2i(2, 0): "andar 2, 1º grau (câmera)", Vector2i(2, 1): "andar 2, 1º grau (porta)",
		Vector2i(3, 0): "andar 3, regra de três", Vector2i(3, 1): "andar 3, área",
		Vector2i(4, 0): "nível 4, distributiva", Vector2i(4, 1): "nível 4, triângulo (ciborgue/cela)",
	}
	var all_ok := true
	for k in names:
		var r: Array = await limits(k.x, k.y)
		print("   %-38s %5.1f / %5.1f / %5.1f" % [names[k], r[0], r[1], r[2]])
		all_ok = all_ok and r[0] >= 30.0 and r[2] <= 240.0
	check("todo hack normal dá entre 30 s e 4 min", all_ok)

	var avg2: float = ((await limits(2, 0))[1] + (await limits(2, 1))[1]) / 2.0
	var hi_sec := 0.0
	for k in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1)]:
		var r: Array = await limits(k.x, k.y, 0.8)
		print("   %-38s %5.1f / %5.1f / %5.1f" % ["segurança máxima, %s" % names[k].trim_prefix("andar 3, ").trim_prefix("nível 4, "), r[0], r[1], r[2]])
		hi_sec = maxf(hi_sec, r[1])
	check("na segurança máxima o tempo médio fica abaixo do andar 2 (GDD)", hi_sec < avg2, "%.1f < %.1f" % [hi_sec, avg2])

	var lock: Array = await limits(4, 1, 0.4)
	print("   %-38s %5.1f / %5.1f / %5.1f" % ["lockdown (triângulo, x0,5 x0,8)", lock[0], lock[1], lock[2]])
	check("hack do lockdown tem pelo menos 15 s", lock[0] >= 15.0)
	# Durante o hack o mundo anda a 5%: a contagem do lockdown quase para.
	var zone := lvl.get_node("LabLockdown") as LockdownZone
	var world_cost: float = lock[2] * GameManager.WORLD_SPEED_HACKING
	print("   lockdown: %.0f s de contagem; o hack mais longo gasta %.1f s dela" % [zone.countdown, world_cost])
	check("dá para correr até a saída e hackear antes do fim do lockdown",
		world_cost + 1250.0 / 200.0 < zone.countdown, "%.1f s de hack + 6,3 s correndo" % world_cost)

	GameManager.set_flag("vance_rescued")
	var vance: Array = await limits(4, 1)
	GameManager.story_flags.clear()
	var base: Array = await limits(4, 1)
	print("   %-38s %5.1f / %5.1f / %5.1f" % ["triângulo com Protocolo Vance", vance[0], vance[1], vance[2]])
	check("Protocolo Vance dá mais tempo na média", vance[1] > base[1])

	print("--- Núcleo e Duelo (Fase 4) ---")
	var n50: Array = await limits(5, 0, 0.6 * 0.8)
	var n51: Array = await limits(5, 1, 0.6 * 0.8)
	print("   %-38s %5.1f / %5.1f / %5.1f" % ["nó do Duelo, x dos dois lados", n50[0], n50[1], n50[2]])
	print("   %-38s %5.1f / %5.1f / %5.1f" % ["nó do Duelo, com parênteses", n51[0], n51[1], n51[2]])
	check("nós do Duelo: pressão alta mas com pelo menos 30 s", n50[0] >= 30.0 and n51[0] >= 30.0)
	print("   Paradoxo final: %.0f s" % ui.PARADOX_TIME)
	var hits_to_die := int(ceil(100.0 / DuelAttack.new().damage))
	print("   golpes do núcleo até cair: %d (invulnerável %.1f s depois de cada um)" % [hits_to_die, DuelHit.IFRAMES_MS / 1000.0])
	check("Duelo perdoa erros de desvio (6+ golpes)", hits_to_die >= 6)
	var sw := SweepAttack.new()
	var reach := sw.telegraph_time + sw.active_time * (990.0 / 1106.0)
	var need := (ParadoxDuel.GAP_NEAR_MAX - sw.gap_size / 2.0) / 200.0
	print("   varredura: chega à cabeça em %.2f s; correr até a brecha mais longe leva %.2f s" % [reach, need])
	check("brecha da varredura sempre alcançável correndo", need < reach * 0.8)

	print("--- Furtividade ---")
	var p := lvl.get_node("Eduardo") as Eduardo
	var laser := lvl.get_node("Lasers/Laser3020") as LaserBarrier
	var cross := (8.0 + 28.0) / p.walk_speed
	print("   laser temporizado: %.1f s desligado; atravessar andando leva %.2f s" % [laser.off_time, cross])
	check("janela do laser temporizado dá para atravessar andando", cross * 2.0 < laser.off_time)
	var cy := lvl.get_node("Guards/Guard4") as Enemy
	var pass_time := cy.vision_range / p.walk_speed
	print("   ciborgue: ponto cego de %.0f s; sair do alcance da visão andando leva %.1f s" % [cy.blind_time, pass_time])
	check("ponto cego do ciborgue dá tempo de sair da visão andando", cy.blind_time > pass_time)
	var light := lvl.get_node("CeilingLights/Light_700_-16") as NeonSign
	print("   luz do teto apagada por %.0f s" % light.off_time)
	check("luz apagada dura mais que uma passada da patrulha da recepção", light.off_time > (1050.0 - 400.0) / 70.0)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
