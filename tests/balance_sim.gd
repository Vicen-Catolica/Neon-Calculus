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
