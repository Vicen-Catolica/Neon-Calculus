extends Node
var lvl; var p
func step(n): 
	for i in n: await get_tree().physics_frame
func _ready():
	lvl = load("res://scenes/levels/test_movement.tscn").instantiate()
	add_child(lvl); p = lvl.get_node("Eduardo")
	await step(30)
	print("idle on floor: y=", p.global_position.y, " state=", p.State.keys()[p.state])
	Input.action_press("move_right"); await step(40)
	print("walk x=", p.global_position.x, " vx=", p.velocity.x, " state=", p.State.keys()[p.state])
	Input.action_press("run"); await step(40)
	print("run vx=", p.velocity.x, " state=", p.State.keys()[p.state])
	Input.action_release("run"); Input.action_release("move_right"); await step(30)
	Input.action_press("jump"); await step(5)
	print("jump state=", p.State.keys()[p.state], " vy=", p.velocity.y)
	Input.action_release("jump"); await step(60)
	print("landed state=", p.State.keys()[p.state], " y=", p.global_position.y)
	Input.action_press("crouch"); await step(10)
	print("crouch state=", p.State.keys()[p.state], " crouch_shape_disabled=", p.crouch_shape.disabled)
	Input.action_press("move_right"); await step(60)
	print("crouch_walk x=", p.global_position.x, " state=", p.State.keys()[p.state])
	# sob o teto baixo (x ~ 400-600): soltar crouch não deve levantar
	p.global_position.x = 500; p.velocity = Vector2.ZERO
	Input.action_release("move_right"); Input.action_release("crouch"); await step(20)
	print("under ceiling, crouch released -> stand? ", not p._crouching, " (esperado false)")
	p.global_position.x = 300; await step(10)
	Input.action_release("crouch")
	await step(20)
	print("free space -> stand? ", not p._crouching, " (esperado true)")
	# escada
	p.global_position = Vector2(1000, 0); await step(5)
	Input.action_press("climb_up"); await step(90)
	print("climb: state=", p.State.keys()[p.state], " y=", p.global_position.y)
	Input.action_release("climb_up")
	GameManager.set_state(GameManager.State.HACKING); await step(5)
	print("hack state=", p.State.keys()[p.state], " anim=", p.sprite.animation)
	GameManager.set_state(GameManager.State.PLAYING); Engine.time_scale = 1.0
	get_tree().quit()