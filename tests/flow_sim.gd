extends Node
## Simulação do fluxo entre andares: transição da Axioma, checkpoint (save),
## "Continuar", game over pelo taser e "Reiniciar checkpoint". Uso:
##   godot --headless --path . res://tests/flow_sim.tscn
## Preserva o save do jogador: guarda o que havia e regrava no fim.

var fails := 0


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func wait_transition() -> float:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while LevelTransition.is_busy():
		await get_tree().process_frame
	return (Time.get_ticks_msec() - t0) / 1000.0


func wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	# Sai da cena atual para sobreviver às trocas de cena feitas pela transição.
	var tree := get_tree()
	await tree.process_frame
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	_run()


func _run() -> void:
	var backup := SaveGame.load_checkpoint()
	var l1: String = GameManager.LEVELS[1]["scene"]
	var l2: String = GameManager.LEVELS[2]["scene"]

	SaveGame.clear()
	GameManager.reset_progress()
	check("sem save depois de limpar", not SaveGame.has_save())

	# Novo jogo -> Fase 1 pela transição.
	LevelTransition.change_level(l1)
	var dt := await wait_transition()
	var lvl := get_tree().current_scene as Level
	check("transição carrega a Fase 1", lvl != null and lvl.floor_number == 1)
	check("transição em menos de 2 s", dt < 2.0, "%.2f s" % dt)
	check("andar 1 no GameManager", GameManager.current_floor == 1)
	check("checkpoint gravado ao entrar", SaveGame.has_save() and SaveGame.load_checkpoint()["scene"] == l1)

	GameManager.mark_lore_read("slums_01_sine")
	check("lore lida vai para o save", "slums_01_sine" in SaveGame.load_checkpoint()["lore_read"])

	# Saída da Fase 1 -> Fase 2.
	var exit := lvl.get_node("LevelExit") as LevelExit
	check("saída aponta para a Fase 2", exit.next_stage == l2, exit.next_stage)
	var p := get_tree().get_first_node_in_group("Player")
	exit._on_body_entered(p)
	dt = await wait_transition()
	lvl = get_tree().current_scene as Level
	check("saída leva à Fase 2", lvl != null and lvl.floor_number == 2)
	check("andar 2 no GameManager e no save", GameManager.current_floor == 2 and int(SaveGame.load_checkpoint()["floor"]) == 2)
	check("lore lida continua depois da troca", "slums_01_sine" in GameManager.lore_read)

	# "Continuar": simula jogo reaberto (estado em memória perdido).
	GameManager.reset_progress()
	var scene := SaveGame.restore()
	check("continuar aponta para a Fase 2", scene == l2)
	check("continuar restaura a lore", "slums_01_sine" in GameManager.lore_read)
	check("continuar restaura o andar", GameManager.current_floor == 2)

	# Game over pelo taser na Fase 2 -> reiniciar checkpoint.
	await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("Player")
	p.take_damage(1000.0)
	await get_tree().physics_frame
	check("pego pelo taser toca 'caught'", p.sprite.animation == &"caught", String(p.sprite.animation))
	await wait_real(1.3)
	var go := get_tree().root.find_children("*", "GameOver", false, false)
	check("tela de game over aparece", go.size() == 1)
	if go.size() == 1:
		(go[0] as GameOver)._on_restart_pressed()
		await wait_transition()
	lvl = get_tree().current_scene as Level
	check("reiniciar volta ao checkpoint da Fase 2", lvl != null and lvl.floor_number == 2)
	check("jogo despausado depois de reiniciar", not get_tree().paused)
	p = get_tree().get_first_node_in_group("Player")
	check("Eduardo vivo depois de reiniciar", p != null and not p.is_dead)

	# Saída da Fase 2 (elevador de carga) -> Fase 3.
	var l3: String = GameManager.LEVELS[3]["scene"]
	exit = lvl.get_node("LevelExit") as LevelExit
	check("saída da Fase 2 aponta para a Fase 3", exit.next_stage == l3, exit.next_stage)
	check("título da Fase 3 na transição", GameManager.level_title(l3) == "Setor de P&D")
	exit._on_body_entered(p)
	dt = await wait_transition()
	lvl = get_tree().current_scene as Level
	check("elevador leva à Fase 3", lvl != null and lvl.floor_number == 3)
	check("transição para a Fase 3 em menos de 2 s", dt < 2.0, "%.2f s" % dt)
	check("andar 3 no GameManager e no save", GameManager.current_floor == 3 and int(SaveGame.load_checkpoint()["floor"]) == 3)
	GameManager.reset_progress()
	check("continuar aponta para a Fase 3", SaveGame.restore() == l3 and GameManager.current_floor == 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("Player")
	check("Eduardo nasce no chão da Fase 3", p != null and p.is_on_floor(), str(p.global_position) if p else "")
	var exit3 := lvl.get_node("LevelExit") as LevelExit
	check("saída da Fase 3 desligada até existir a Fase 4", exit3.next_stage == "")

	# Restaura o save do jogador.
	SaveGame.clear()
	if not backup.is_empty():
		GameManager.lore_read.clear()
		for id in backup.get("lore_read", []):
			GameManager.lore_read.append(String(id))
		SaveGame.save_checkpoint(int(backup["floor"]), String(backup["scene"]))

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
