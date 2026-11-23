extends Node
## Navegação dos guardas (playtest à mão: guardas não pulavam nem subiam escadas,
## espelhavam o jogador por baixo e travavam colados nele sem atacar). Usa o
## Setor de P&D (escritórios com mezanino e escadas). Uso:
##   godot --headless --path . res://tests/guard_nav_sim.tscn

const LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"

var lvl: Node
var p: Eduardo
var g: Enemy
var fails := 0


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pos() -> String:
	return "guarda x=%.0f y=%.1f" % [g.global_position.x, g.global_position.y]


## Dirige só a navegação (máquina de estados desligada; a gravidade vem do
## próprio guarda) até `target` por até `sec` s.
func drive(target: Vector2, sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame
		var arrived := g.chase_move(target, g.chase_speed)
		g.move_and_slide()
		if arrived:
			break


func _ready() -> void:
	GameManager.mark_dialogue_seen("rnd_elevator")
	lvl = load(LEVEL).instantiate()
	lvl.get_node("LevelExit").set("next_stage", "")
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(20)
	for e in get_tree().get_nodes_in_group("guards"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for c in get_tree().get_nodes_in_group("security_camera"):
		c.process_mode = Node.PROCESS_MODE_DISABLED
	g = lvl.get_node("Guards/Guard2") as Enemy  # agente do chão dos escritórios

	# 1. Colado no jogador e em alerta: ataca (antes travava sem linha de visão).
	var en := g.get_node_or_null("VisibleOnScreenEnabler2D")
	if en:
		en.queue_free()
	g.global_position = Vector2(1700, 16)
	p.global_position = Vector2(1712, 16)
	p.current_defense = p.max_defense
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.state_machine.transition_to("MaxAlert")
	await step(150)
	check("guarda colado no jogador ataca com o taser", p.current_defense < p.max_defense, "defesa %.0f" % p.current_defense)
	check("guarda colado conta como vendo", g.is_player_in_los())
	# Daqui em diante: guarda ligado, mas sem a máquina de estados (só navegação).
	g.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	g.vision_range = 0.0
	p.global_position = Vector2(300, 16)
	await step(5)

	# 2. Jogador no mezanino: o guarda acha a escada e sobe (não espelha por baixo).
	g.global_position = Vector2(1700, 16)
	g.velocity = Vector2.ZERO
	await step(5)
	await drive(Vector2(2000, -144), 14.0)
	check("guarda sobe a escada até o mezanino", absf(g.global_position.y + 144.0) < 8.0, pos())
	check("e chega perto do jogador lá em cima", absf(g.global_position.x - 2000.0) < 40.0, pos())

	# 3. Jogador de volta no chão: desce pela escada.
	await drive(Vector2(1500, 16), 14.0)
	check("guarda desce do mezanino para o chão", absf(g.global_position.y - 16.0) < 8.0 and not g.is_climbing(), pos())
	check("colisão normal depois de descer", g.collision_mask != 0)

	# 4. Caixa no caminho: pula.
	var box := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(40, 56)
	cs.shape = r
	box.add_child(cs)
	box.position = Vector2(1300, 16 - 28)
	lvl.add_child(box)
	g.global_position = Vector2(1180, 16)
	g.velocity = Vector2.ZERO
	await step(5)
	await drive(Vector2(1420, 16), 6.0)
	check("guarda pula um obstáculo baixo", g.global_position.x > 1380.0 and absf(g.global_position.y - 16.0) < 8.0, pos())
	box.queue_free()

	# 5. Alvo num andar sem escada até lá: sobe o que der e segura distância.
	g.global_position = Vector2(1500, 16)
	g.velocity = Vector2.ZERO
	await step(5)
	await drive(Vector2(1800, -400), 5.0)
	var dx := absf(g.global_position.x - 1800.0)
	# (sobe até o andar mais alto que alcança e segura ali)
	check("sem caminho até o alvo, espera a uns 150 px mirando (não fica embaixo)", dx > 100.0 and dx < 200.0,
		"a %.0f px do alvo, " % dx + pos())
	check("e olha para o alvo", g.get_facing_direction().x > 0.0)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
