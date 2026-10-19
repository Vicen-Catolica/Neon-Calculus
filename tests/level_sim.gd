extends Node
## Percorre o nível das favelas por simulação de input.

var lvl: Node
var p: Eduardo

func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func tp(x: float, y: float = 16.0) -> void:
	p.global_position = Vector2(x, y)
	p.velocity = Vector2.ZERO

func _ready() -> void:
	lvl = load("res://scenes/levels/slums_test.tscn").instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	await step(30)
	print("spawn: y=", p.global_position.y, " (esperado 16)")

	# Teto baixo sem agachar: deve bloquear em x < 1664 + largura.
	tp(1550); Input.action_press("move_right"); await step(200)
	print("teto baixo em pé: x=", snappedf(p.global_position.x, 1), " (esperado bloqueado ~1650)")
	Input.action_press("crouch"); await step(330)
	print("teto baixo agachado: x=", snappedf(p.global_position.x, 1), " (esperado > 1960)")
	Input.action_release("crouch"); Input.action_release("move_right"); await step(30)

	# Escada até a passarela.
	tp(1008); await step(10)
	Input.action_press("climb_up"); await step(260)
	Input.action_release("climb_up"); await step(40)
	print("escada: state=", p.State.keys()[p.state], " y=", snappedf(p.global_position.y, 1), " (esperado -144, em pé)")

	# Degrau de 64 px.
	tp(2795); Input.action_press("move_right"); await step(2)
	Input.action_press("jump"); await step(30); Input.action_release("jump"); await step(120)
	print("degrau: x=", snappedf(p.global_position.x, 1), " y=", snappedf(p.global_position.y, 1), " (esperado y -48)")
	Input.action_release("move_right")
	get_tree().quit()