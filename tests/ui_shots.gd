extends Node
## Fotos das telas sobrepostas para revisão visual (precisa de janela):
##   LIBGL_ALWAYS_SOFTWARE=1 godot --path . --windowed --resolution 1920x1080 res://tests/ui_shots.tscn -- <pasta>
## Preserva o save do jogador.

var out := ""
var n := 0


func frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, n, label])
	print("foto ", n, " ", label)
	n += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_cmdline_user_args()[0]
	var tree := get_tree()
	await tree.process_frame
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	var backup := SaveGame.load_checkpoint()
	await _run()
	SaveGame.clear()
	if not backup.is_empty():
		SaveGame._write(backup)
	get_tree().quit()


func load_level(k: int) -> void:
	LevelTransition.change_level(GameManager.LEVELS[k]["scene"])
	await frames(2)
	while LevelTransition.is_busy():
		await frames(1)
	await frames(5)
	if Dialogue.is_open():
		Dialogue.skip()
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED


func _run() -> void:
	GameManager.reset_progress()
	await load_level(4)
	var ui := get_tree().get_first_node_in_group("hacking_ui")
	# Hack nível 5, com e sem parênteses, depois de dois erros (SINE aberta).
	for sub in [0, 1]:
		GameManager.set_state(GameManager.State.HACKING)
		ui.call("start_hacking", 5, sub)
		await wait_real(0.6)
		await shot("hack_n5_sub%d" % sub)
		ui.call("_trigger_error", 1)
		ui.call("_trigger_error", 2)
		await wait_real(1.2)
		await shot("hack_n5_sub%d_sine" % sub)
		ui.call("_complete_hack", false)
		GameManager.set_state(GameManager.State.PLAYING)
		await frames(5)
	# Paradoxo com um erro.
	GameManager.set_state(GameManager.State.HACKING)
	ui.call("start_paradox")
	await wait_real(0.5)
	ui.call("_trigger_error", 7)
	await wait_real(0.6)
	await shot("paradoxo_erro")
	ui.call("_complete_hack", false)
	GameManager.set_state(GameManager.State.PLAYING)
	await frames(5)

	# Pausa e Como jogar.
	PauseMenu.open()
	await wait_real(0.3)
	await shot("pausa")
	PauseMenu.call("_show_how_to")
	await wait_real(0.5)
	await shot("como_jogar")
	var how = PauseMenu.get("_how_to")
	if how:
		how.call("close")
	PauseMenu.resume()
	await frames(5)

	# Diálogos com cada personagem.
	for id in ["rnd_vance", "core_first_alarm", "duel_victory"]:
		GameManager.set_flag("vance_rescued")
		if Dialogue.play_id(id):
			await wait_real(2.5)
			await shot("dialogo_" + id)
			Dialogue.skip()
		await frames(5)

	# Lore com dica da SINE.
	var term := get_tree().get_first_node_in_group("data_terminal")
	if term:
		term.call("open")
		await wait_real(6.0)
		var reader := get_tree().get_first_node_in_group("lore_reader")
		if reader:
			reader.call("_unhandled_input", _action_event("interact_world"))
		await wait_real(1.0)
		await shot("lore")
		if reader and reader.call("is_open"):
			reader.call("_close")
		await frames(5)

	# Game over.
	var p := get_tree().get_first_node_in_group("Player")
	p.call("take_damage", 1000.0)
	await wait_real(3.5)
	await shot("game_over")
	for c in get_tree().root.get_children():
		if c is GameOver:
			c.queue_free()
	get_tree().paused = false
	await frames(5)

	# Encerramento.
	GameManager.stats = {"time": 3725.0, "hacks": 42, "hack_errors": 9, "alarms": 3}
	get_tree().change_scene_to_file("res://scenes/ui/ending.tscn")
	await wait_real(4.0)
	await shot("encerramento_a")
	await wait_real(8.0)
	await shot("encerramento_b")


func _action_event(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev
