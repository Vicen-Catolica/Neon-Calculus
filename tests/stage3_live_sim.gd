extends Node
## Playtest automatizado da Fase 3 com TUDO ligado (guardas, ciborgues, câmeras,
## lasers): em cada trecho existe um esconderijo onde o Eduardo, escondido no
## escuro, passa guarda passa e não vê enquanto as patrulhas continuam (e algum
## guarda passa a menos de 200 px, senão o teste não prova nada). Também
## confere que os esconderijos sob a luz não protegem. Uso:
##   godot --headless --path . res://tests/stage3_live_sim.tscn

const LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"
## Observa até um guarda passar a menos de NEAR px (e mais 3 s), no máximo WATCH s.
const WATCH := 40.0
const NEAR := 150.0

var lvl: Node
var p: Eduardo
var fails := 0
var alarms := [0]


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func press_interact() -> void:
	Input.action_press("interact_world")
	await step(2)
	Input.action_release("interact_world")
	await step(3)


## Teleporta, esconde e observa: devolve [escondido?, maior subida de uma barra,
## alarmes, menor distância de um guarda no mesmo piso].
func hide_and_watch(x: float, y: float) -> Array:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	await step(2)
	await press_interact()
	var hidden := p.is_hidden()
	var a0: int = alarms[0]
	# Quanto alguma barra de detecção SUBIU com ele já escondido (os quadros entre o
	# teleporte e o esconder não contam).
	var worst := 0.0
	var prev := {}
	var closest := 99999.0
	var passed_at := -1
	for i in int(WATCH * 60.0):
		await get_tree().physics_frame
		if passed_at < 0 and closest < NEAR:
			passed_at = i
		if passed_at >= 0 and i - passed_at > 180:
			break
		for g in get_tree().get_nodes_in_group("guards"):
			var aw := float(g.get("awareness"))
			if prev.has(g):
				worst = maxf(worst, aw - float(prev[g]))
			prev[g] = aw
			if absf(g.global_position.y - p.global_position.y) < 40.0:
				closest = minf(closest, absf(g.global_position.x - p.global_position.x))
	var res := [hidden, worst, alarms[0] - a0, closest]
	await press_interact()  # sai do esconderijo
	return res


func _ready() -> void:
	lvl = load(LEVEL).instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	GameManager.alarm_raised.connect(func(_pp: Vector2) -> void: alarms[0] += 1)
	for i in 10:
		await get_tree().process_frame
	if Dialogue.is_open():
		Dialogue.skip()
	# Sem janela nada é desenhado, então o VisibleOnScreenEnabler2D nunca liga os
	# guardas; aqui eles ficam sempre ligados (no jogo, ligam ao entrar na tela).
	for g in get_tree().get_nodes_in_group("guards"):
		var en := g.get_node_or_null("VisibleOnScreenEnabler2D")
		if en:
			en.queue_free()
		g.process_mode = Node.PROCESS_MODE_INHERIT
	await step(10)
	var hv := p.get_node("HackVision") as HackVision

	# A: o balcão fica sob a luz; apagada, vira esconderijo.
	hv.debug_hack(lvl.get_node("CeilingLights/Light_700_-16/Hackable"), true)
	var r := await hide_and_watch(700, 16)
	check("A: atrás do balcão (luz apagada), guarda passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])

	# B: cubículo da esquerda, no escuro, com agente no chão, agente no mezanino e domo.
	r = await hide_and_watch(1450, 16)
	check("B: no cubículo escuro, guarda passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])

	# B: cubículo do meio está sob a luz: não dá para se esconder.
	p.global_position = Vector2(1800, 16)
	await step(3)
	await press_interact()
	check("B: cubículo iluminado não esconde", not p.is_hidden())
	if p.is_hidden():
		await press_interact()

	# D: bancada escura, com a Unidade Lógica patrulhando o chão.
	r = await hide_and_watch(3800, 16)
	check("D: atrás da bancada escura, a Unidade Lógica passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])

	# E: arquivo no meio do átrio, com a Unidade Lógica na mesma passarela.
	r = await hide_and_watch(5100, -240)
	check("E: atrás do arquivo do átrio, guarda passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])

	check("Eduardo sai inteiro do playtest", not p.is_dead)
	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
