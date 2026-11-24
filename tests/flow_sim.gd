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


## Põe o Eduardo em pé dentro da saída (elas só valem em pé) e espera a troca.
func stand_in_exit(exit: LevelExit, pl: CharacterBody2D) -> void:
	pl.global_position = exit.global_position + Vector2(0, -4)
	pl.velocity = Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame
		if LevelTransition.is_busy():
			break


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
	# A saída da Fase 2 é a cabine do elevador: subir a escada por baixo não
	# conta, só em pé lá dentro.
	check("saída da Fase 2 exige estar em pé na cabine", exit.require_standing)
	p.global_position = exit.global_position + Vector2(0, 128 + 40)  # escada de baixo, cabeça na área
	p.velocity = Vector2.ZERO
	for i in 3:
		await get_tree().physics_frame
	check("encostar na área por baixo não troca de fase", not LevelTransition.is_busy())
	p.global_position = exit.global_position + Vector2(0, -4)
	p.velocity = Vector2.ZERO
	for i in 30:
		await get_tree().physics_frame
		if LevelTransition.is_busy():
			break
	dt = await wait_transition()
	lvl = get_tree().current_scene as Level
	check("elevador leva à Fase 3", lvl != null and lvl.floor_number == 3)
	check("transição para a Fase 3 em menos de 2 s", dt < 2.0, "%.2f s" % dt)
	check("andar 3 no GameManager e no save", GameManager.current_floor == 3 and int(SaveGame.load_checkpoint()["floor"]) == 3)
	for i in 10:
		await get_tree().process_frame
	check("diálogo de elevador abre ao chegar", Dialogue.is_open() and Dialogue.current_speaker() == "SINE")
	check("diálogo pausa o jogo", get_tree().paused)
	Dialogue.skip()
	check("diálogo visto vai para o save", "rnd_elevator" in SaveGame.load_checkpoint().get("dialogues_seen", []))
	check("jogo volta depois do diálogo", not get_tree().paused and GameManager.state == GameManager.State.PLAYING)
	GameManager.set_flag("vance_rescued")
	check("resgate do Vance vai para o save na hora", "vance_rescued" in SaveGame.load_checkpoint().get("story_flags", []))
	GameManager.reset_progress()
	check("continuar aponta para a Fase 3", SaveGame.restore() == l3 and GameManager.current_floor == 3)
	check("continuar lembra o diálogo visto", "rnd_elevator" in GameManager.dialogues_seen)
	check("continuar lembra o resgate", GameManager.has_flag("vance_rescued"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("Player")
	check("Eduardo nasce no chão da Fase 3", p != null and p.is_on_floor(), str(p.global_position) if p else "")
	# Elevador executivo (Fase 3) -> Fase 4.
	var l4: String = GameManager.LEVELS[4]["scene"]
	var exit3 := lvl.get_node("LevelExit") as LevelExit
	check("saída da Fase 3 aponta para a Fase 4", exit3.next_stage == l4, exit3.next_stage)
	check("título da Fase 4 na transição", GameManager.level_title(l4) == "Núcleo Quântico")
	check("saída da Fase 3 exige estar em pé no elevador", exit3.require_standing)
	await stand_in_exit(exit3, p)
	dt = await wait_transition()
	lvl = get_tree().current_scene as Level
	check("elevador executivo leva à Fase 4", lvl != null and lvl.floor_number == 4)
	check("transição para a Fase 4 em menos de 2 s", dt < 2.0, "%.2f s" % dt)
	check("andar 4 no GameManager e no save", GameManager.current_floor == 4 and int(SaveGame.load_checkpoint()["floor"]) == 4)
	check("save da Fase 4 mantém o resgate do Vance", "vance_rescued" in SaveGame.load_checkpoint().get("story_flags", []))
	GameManager.reset_progress()
	check("continuar aponta para a Fase 4", SaveGame.restore() == l4 and GameManager.current_floor == 4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("Player")
	check("Eduardo nasce no chão da Fase 4", p != null and p.is_on_floor(), str(p.global_position) if p else "")

	# Porta do Domo (antecâmara) -> arena do Duelo, com checkpoint próprio.
	var ld: String = GameManager.LEVELS[5]["scene"]
	if Dialogue.is_open():
		Dialogue.skip()
	var exit4 := lvl.get_node("LevelExit") as LevelExit
	check("porta do Domo leva à arena do Duelo", exit4.next_stage == ld, exit4.next_stage)
	check("porta do Domo exige estar em pé na frente dela", exit4.require_standing)
	await stand_in_exit(exit4, p)
	dt = await wait_transition()
	lvl = get_tree().current_scene as Level
	check("arena do Duelo carrega (ainda andar 4)", lvl != null and lvl.scene_file_path == ld and lvl.floor_number == 4)
	check("título do Domo na transição", GameManager.level_title(ld) == "Domo de Controle Neural")
	check("checkpoint fica antes do chefe", SaveGame.load_checkpoint()["scene"] == ld)
	for i in 10:
		await get_tree().process_frame
	check("confronto com a Axioma abre ao entrar no Domo", Dialogue.is_open())
	Dialogue.skip()
	await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("Player")
	p.take_damage(1000.0)
	await wait_real(1.3)
	var go4 := get_tree().root.find_children("*", "GameOver", false, false)
	if go4.size() == 1:
		(go4[0] as GameOver)._on_restart_pressed()
		await wait_transition()
	lvl = get_tree().current_scene as Level
	check("game over no Duelo volta ao começo do Duelo", go4.size() == 1 and lvl != null and lvl.scene_file_path == ld)
	for i in 10:
		await get_tree().process_frame
	check("depois do game over, o confronto não se repete", not Dialogue.is_open())

	# Restaura o save do jogador.
	SaveGame.clear()
	if not backup.is_empty():
		GameManager.lore_read.clear()
		GameManager.dialogues_seen.clear()
		GameManager.story_flags.clear()
		for id in backup.get("story_flags", []):
			GameManager.story_flags.append(String(id))
		for id in backup.get("dialogues_seen", []):
			GameManager.dialogues_seen.append(String(id))
		for id in backup.get("lore_read", []):
			GameManager.lore_read.append(String(id))
		SaveGame.save_checkpoint(int(backup["floor"]), String(backup["scene"]))

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
