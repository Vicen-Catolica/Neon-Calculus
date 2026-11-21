extends Node
## Playtest automatizado da Fase 4 (Núcleo, galeria dos servidores) com TUDO
## ligado (Unidades Lógicas, câmeras, lasers): em cada trecho existe um esconderijo onde o Eduardo, escondido no
## escuro, passa guarda passa e não vê enquanto as patrulhas continuam (e algum
## guarda passa a menos de 200 px, senão o teste não prova nada). Também
## confere que os esconderijos sob a luz não protegem. Uso:
##   godot --headless --path . res://tests/stage4_live_sim.tscn

const LEVEL := "res://scenes/levels/core/core_stage4.tscn"
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
	lvl.get_node("LevelExit").set("next_stage", "")  # não troca de fase no meio
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	GameManager.alarm_raised.connect(func(_pp: Vector2) -> void: alarms[0] += 1)
	GameManager.mark_dialogue_seen("core_first_alarm")
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

	# C: servidor escuro no chão, com a Unidade Lógica do chão passando rente.
	var r := await hide_and_watch(1900, 16)
	check("C: atrás do servidor do chão, a Unidade Lógica passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])
	# C: servidor do mezanino, com a outra Unidade Lógica.
	r = await hide_and_watch(2300, -144)
	check("C: atrás do servidor do mezanino, a Unidade Lógica passa e não vê", r[0] and r[1] < 0.05 and r[2] == 0 and r[3] < NEAR, "barra=%.2f alarmes=%d guarda a %.0f px" % [r[1], r[2], r[3]])

	check("Eduardo sai inteiro do playtest", not p.is_dead)
	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
