extends Node
## Uso: godot --path . --windowed --resolution 1920x1080 res://tests/screenshot.tscn -- <cena> <xs separados por vírgula> <pasta>
## Move o Eduardo para cada x (em px) e salva um PNG da viewport.

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var lvl: Node = load(a[0]).instantiate()
	add_child(lvl)
	var p: Node2D = get_tree().get_first_node_in_group("Player")
	var i := 0
	for xs in a[1].split(","):
		p.global_position.x = float(xs)
		p.velocity = Vector2.ZERO
		for f in 40:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [a[2], i])
		i += 1
	get_tree().quit()