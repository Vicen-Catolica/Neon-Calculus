extends Node
## Uso: godot --path . --windowed --resolution 1920x1080 res://tests/stage_shots.tscn -- <cena> <x:y;x:y;...> <pasta>
## Teleporta o Eduardo para cada ponto e salva um PNG da viewport.

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var lvl: Node = load(a[0]).instantiate()
	add_child(lvl)
	var p: Node2D = get_tree().get_first_node_in_group("Player")
	# Guardas congelados para as fotos (senão o Eduardo teleportado leva taser).
	await get_tree().process_frame
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	var i := 0
	var vision := a.size() > 3 and a[3] == "vision"
	for pt in a[1].split(";"):
		var xy := pt.split(":")
		p.global_position = Vector2(float(xy[0]), float(xy[1]))
		p.velocity = Vector2.ZERO
		var cam := p.get_node("GameCamera") as Camera2D
		cam.reset_smoothing()
		if vision:
			Input.action_press("hack_vision")
		for f in 45:
			await get_tree().physics_frame
		if vision:
			var hv: Node = p.get_node("HackVision")
			print("alvos visíveis: ", hv.candidates.map(func(h): return h.get_label()), " alvo=", hv.target.get_label() if hv.target else "-")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [a[2], i])
		Input.action_release("hack_vision")
		i += 1
	get_tree().quit()
