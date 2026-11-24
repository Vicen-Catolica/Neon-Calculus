extends Node
## Tutorial guiado da SINE na Fase 1 (playtest à mão: faltava a SINE ensinar
## dentro do jogo) e as conversas novas das Fases 1 e 2. Uso:
##   godot --headless --path . res://tests/tutorial_sim.tscn

const LEVEL := "res://scenes/levels/slums/slums_stage1.tscn"

var lvl: Node
var p: Eduardo
var fails := 0


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Fecha o diálogo aberto avançando fala por fala (como o jogador).
func read_all() -> void:
	var guard := 0
	while Dialogue.is_open() and guard < 200:
		Dialogue.advance()
		await frames(2)
		guard += 1


func _ready() -> void:
	Tutorial.allow_in_tests = true
	GameManager.dialogues_seen.clear()
	var ids := ["slums_intro", "slums_suit", "slums_kiosk", "slums_upstairs", "ind_arrival", "ind_drones", "ind_top",
		"tut_hack_show", "tut_hack_done", "tut_hack_failed", "tut_spotted"]
	var missing := ids.filter(func(id): return Dialogue.lines_for(id).is_empty())
	check("roteiros novos da SINE carregam", missing.is_empty(), str(missing))
	var bad: Array = []
	for id in ids:
		for l in Dialogue.lines_for(id):
			if not Dialogue.SPEAKERS.has(String(l["who"])):
				bad.append(id)
	check("falantes conhecidos", bad.is_empty(), str(bad))

	lvl = load(LEVEL).instantiate()
	add_child(lvl)
	p = lvl.get_node("Eduardo")
	check("Fase 1 tem o gatilho do guia do hack", lvl.get_node_or_null("Tutorial_hack") != null)
	# Abertura: a SINE fala assim que a fase começa.
	for i in 240:
		await get_tree().process_frame
		if Dialogue.is_open():
			break
	check("conversa de abertura da SINE na Fase 1", Dialogue.is_open() and Dialogue.current_speaker() == "SINE")
	await read_all()
	# Dica de tecla logo depois da abertura (para quem não abriu o "Como jogar").
	for i in 30:
		await get_tree().process_frame
		if Tutorial.current_hint != "":
			break
	var move_txt := Tutorial.banner_text()
	check("dica de andar/pular/correr aparece depois da abertura", Tutorial.current_hint == "move"
		and "[A]" in move_txt and "[Espaço]" in move_txt and "[Shift]" in move_txt, move_txt)
	check("dica de tecla não pausa o jogo", not get_tree().paused)
	# Agentes parados (o guia não pode morrer porque alguém viu o Eduardo).
	var guard := lvl.get_node("Guards/Guard1") as Enemy
	for g in get_tree().get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := get_viewport().get_camera_2d()

	# 1. Entra na área do guia: SINE pausa e a câmera vai até o agente.
	p.global_position = Vector2(470, 16)
	for i in 240:
		await get_tree().process_frame
		if Dialogue.is_open():
			break
	check("guia do hack começa ao chegar perto do agente", Tutorial.current_guide == "hack" and Dialogue.is_open())
	check("jogo pausado enquanto a SINE fala", get_tree().paused)
	await frames(80)
	var center := cam.get_screen_center_position()
	check("câmera vai até o agente", center.x > p.global_position.x + 250.0, "centro x=%.0f, agente x=%.0f" % [center.x, guard.global_position.x])
	await read_all()
	await get_tree().create_timer(1.3, true, false, true).timeout
	check("câmera volta para o Eduardo", absf(cam.offset.x) < 4.0, "offset %s" % cam.offset)

	# 2. Aviso: segurar a visão hacker (tecla do InputMap).
	await frames(5)
	var key := Tutorial.key_of("hack_vision")
	check("aviso pede para segurar a visão hacker", Tutorial.current_step == "vision" and key in Tutorial.banner_text(), Tutorial.banner_text())
	check("tecla mostrada é a do InputMap (Q)", key == "Q", key)
	Input.action_press("hack_vision")
	await frames(6)
	check("com a visão ligada, pede para mirar e apertar E", Tutorial.current_step == "confirm" and Tutorial.key_of("hack_confirm") in Tutorial.banner_text(), Tutorial.banner_text())
	Input.action_release("hack_vision")
	await frames(4)
	check("soltou a visão: pede para segurar de novo", "de novo" in Tutorial.banner_text(), Tutorial.banner_text())

	# 3. Abre o hack do agente: o aviso explica a equação, por cima da tela.
	var hv := p.get_node("HackVision") as HackVision
	var hack: Hackable = null
	for c in guard.get_children():
		if c is Hackable:
			hack = c
	hv._start_hack(hack)
	await frames(4)
	check("na tela de hack, aviso explica a equação", Tutorial.current_step == "solve" and "x" in Tutorial.banner_text())
	var ui := get_tree().get_first_node_in_group("hacking_ui")
	check("aviso fica acima da tela de hack", ui != null and 35 > int(ui.get("layer")))
	ui.call("_complete_hack", true)
	for i in 120:
		await get_tree().process_frame
		if Dialogue.is_open():
			break
	check("depois do hack a SINE comenta", Dialogue.is_open() and Tutorial.current_step == "result")
	await read_all()
	await frames(4)
	check("guia termina e fica salvo (uma vez por save)", Tutorial.current_guide == "" and "guide_hack" in GameManager.dialogues_seen)
	check("aviso some no fim", Tutorial.banner_text() == "")

	# 2. Jogador ignora o guia e segue adiante: o aviso não fica preso na tela.
	# (dicas de tecla já vistas, para não ocuparem o aviso neste trecho)
	for h in Tutorial.HINTS:
		GameManager.mark_dialogue_seen("hint_" + h)
	GameManager.dialogues_seen.erase("guide_hack")
	p.global_position = Vector2(470, 16)
	Tutorial.guide("hack", p.global_position)
	for i in 240:
		await get_tree().process_frame
		if Dialogue.is_open():
			break
	await read_all()
	await frames(4)
	check("guia de novo: pede a visão hacker", Tutorial.current_step == "vision" and Tutorial.banner_text() != "")
	var away := guard.global_position.x + Tutorial.GIVE_UP_DISTANCE + 60.0
	if away > 1740.0:
		away = guard.global_position.x - Tutorial.GIVE_UP_DISTANCE - 60.0
	p.global_position = Vector2(away, 16)
	await frames(10)
	check("passou do agente sem hackear: o guia desiste e o aviso some",
		Tutorial.current_guide == "" and Tutorial.banner_text() == "", "x=%.0f passo=%s" % [away, Tutorial.current_step])

	# 3. Dica de agachar: mostra as duas teclas e some depois de agachar.
	await frames(10)
	GameManager.dialogues_seen.erase("hint_crouch")
	Tutorial.hint("crouch", p.global_position)
	for i in 30:
		await get_tree().process_frame
		if Tutorial.current_hint == "crouch":
			break
	var cr := Tutorial.banner_text()
	check("dica de agachar mostra as duas teclas", Tutorial.current_hint == "crouch" and "[S ou Ctrl]" in cr, cr)
	Input.action_press("crouch")
	await get_tree().create_timer(Tutorial.HINT_MIN + 0.5, true, false, true).timeout
	Input.action_release("crouch")
	await frames(5)
	check("agachou: a dica some e fica salva", Tutorial.current_hint == "" and Tutorial.banner_text() == ""
		and "hint_crouch" in GameManager.dialogues_seen)
	# Remapeou a tecla nas Opções: dica e aviso da HUD acompanham.
	var old_events := InputMap.action_get_events("camo")
	InputMap.action_erase_events("camo")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	InputMap.action_add_event("camo", g)
	check("tecla remapeada aparece na dica", "[G]" in Tutorial.hint_text("suit"), Tutorial.hint_text("suit"))
	InputMap.action_erase_events("camo")
	for e in old_events:
		InputMap.action_add_event("camo", e)

	# Saiu da fase com a dica aberta (ex.: Menu pela pausa): o aviso não fica preso.
	GameManager.dialogues_seen.erase("hint_crouch")
	Tutorial.hint("crouch", p.global_position)
	for i in 30:
		await get_tree().process_frame
		if Tutorial.current_hint == "crouch":
			break
	var holder := p.get_parent()
	holder.remove_child(p)
	await frames(3)
	check("trocou de cena com a dica aberta: o aviso some", Tutorial.current_hint == "" and Tutorial.banner_text() == "",
		Tutorial.banner_text())
	holder.add_child(p)

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
