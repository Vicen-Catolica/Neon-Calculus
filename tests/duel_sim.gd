extends Node
## Simulação das peças do Duelo de Paradoxo (arena do Domo): núcleo, Nodos de
## Vigilância e cada ataque isolado (aviso sem dano, dano com brecha, brecha que
## salva, invulnerabilidade curta). O Duelo inteiro entra na etapa 6. Uso:
##   godot --headless --path . res://tests/duel_sim.tscn

const LEVEL := "res://scenes/levels/core/core_duel.tscn"

var lvl: Node
var p: Eduardo
var fails := 0


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func reset_player(x: float, y: float = 16.0) -> void:
	p.current_defense = p.max_defense
	p.set_meta("duel_iframe_until", 0)
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO
	await step(8)


## Roda um ataque inteiro e devolve [dano no aviso, dano total].
func run(a: DuelAttack) -> Array:
	lvl.add_child(a)
	var d0 := p.current_defense
	a.start()
	await step(int(a.telegraph_time * 60.0) - 2)
	var during_tele := d0 - p.current_defense
	while a.phase != DuelAttack.Phase.DONE:
		await step(1)
	var total := d0 - p.current_defense
	a.queue_free()
	await step(2)
	return [during_tele, total]


func _ready() -> void:
	lvl = load(LEVEL).instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(20)
	check("arena: andar 4 com câmera inteira (zoom 1)", GameManager.current_floor == 4 and (p.get_node("GameCamera") as Camera2D).zoom == Vector2.ONE)

	# Núcleo.
	var core := lvl.get_node("AxiomaCore") as AxiomaCore
	core.set_damage(7)
	check("núcleo: dano vai de 0 a 3", core.damage_level == 3)
	core.set_damage(0)

	# Nodos de Vigilância.
	var nodes := lvl.get_node("SurveillanceNodes").get_children()
	check("3 Nodos de Vigilância, todos apagados", nodes.size() == 3 and nodes.all(func(n): return n.state == SurveillanceNode.State.IDLE and not n.can_be_hacked()))
	var top := lvl.get_node("SurveillanceNodes/NodeTop") as SurveillanceNode
	var th := top.get_node("Hackable") as Hackable
	top.activate()
	check("nó ativo aceita hack", top.can_be_hacked() and th.get_label() == "NODO DE VIGILÂNCIA")
	check("nó pede nível 5 (o de cima, com parênteses)", th.get_difficulty() == Vector2i(5, 1), str(th.get_difficulty()))
	check("nó: sem Esc e com tempo de segurança máxima", not th.abortable and absf(th.get_time_mult() - 0.8) < 0.001)
	var broke := [0]
	top.broken.connect(func() -> void: broke[0] += 1)
	(p.get_node("HackVision") as HackVision).debug_hack(th, true)
	await step(2)
	check("hack derruba o nó", top.state == SurveillanceNode.State.BROKEN and broke[0] == 1 and not top.can_be_hacked())

	# Varredura descendo com brecha em x.
	await reset_player(300)
	var sw := SweepAttack.new()
	sw.gap_center = 1300.0
	var r := await run(sw)
	check("varredura: o aviso não causa dano", r[0] == 0.0)
	check("varredura: fora da brecha, acerta uma vez (-25)", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(1300)
	sw = SweepAttack.new()
	sw.gap_center = 1300.0
	r = await run(sw)
	check("varredura: dentro da brecha, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Varredura lateral com brecha rente ao chão: em pé acerta, agachado passa.
	await reset_player(900)
	sw = SweepAttack.new()
	sw.dir = SweepAttack.Dir.RIGHT
	sw.gap_center = SweepAttack.CROUCH_GAP
	r = await run(sw)
	check("varredura lateral: em pé, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(900)
	Input.action_press("crouch")
	await step(10)
	sw = SweepAttack.new()
	sw.dir = SweepAttack.Dir.RIGHT
	sw.gap_center = SweepAttack.CROUCH_GAP
	r = await run(sw)
	Input.action_release("crouch")
	check("varredura lateral: agachado, passa por baixo", r[1] == 0.0, "dano %.0f" % r[1])

	# Pulso em anel com brecha angular.
	await reset_player(300)
	var pu := PulseAttack.new()
	pu.center = core.global_position
	pu.gap_angle_deg = 90.0
	r = await run(pu)
	check("pulso: fora da brecha, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(300)
	pu = PulseAttack.new()
	pu.center = core.global_position
	pu.gap_angle_deg = rad_to_deg((DuelHit.body_rect(p).get_center() - core.global_position).angle())
	r = await run(pu)
	check("pulso: no ângulo da brecha, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Grade de lasers.
	await reset_player(800)
	var gr := LaserGridAttack.new()
	r = await run(gr)
	check("grade: dentro de uma coluna, acerta", r[1] == 25.0, "dano %.0f" % r[1])
	await reset_player(1000)
	gr = LaserGridAttack.new()
	r = await run(gr)
	check("grade: no vão entre as colunas, nada", r[1] == 0.0, "dano %.0f" % r[1])

	# Dois ataques juntos: invulnerabilidade curta, um golpe só.
	await reset_player(800)
	var a1 := LaserGridAttack.new()
	var a2 := SweepAttack.new()
	a2.dir = SweepAttack.Dir.RIGHT
	a2.gap_center = 0.0
	a2.active_time = 0.6
	a1.active_time = 0.6
	lvl.add_child(a1)
	lvl.add_child(a2)
	var d0 := p.current_defense
	a1.start()
	a2.start()
	await step(int((a1.telegraph_time + 0.6) * 60.0) + 10)
	check("dois ataques ao mesmo tempo tiram um golpe só", d0 - p.current_defense == 25.0, "dano %.0f" % (d0 - p.current_defense))

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
