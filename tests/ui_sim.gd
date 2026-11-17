extends Node
## Simulação da interface: retorno da tela de hack (acerto, erro, vazio, tempo
## esgotado), cronômetro em tempo real com o mundo desacelerado, passo a passo
## da SINE, tela "Como jogar" e menu de pausa. Uso:
##   godot --headless --path . res://tests/ui_sim.tscn

var fails := 0
var ui
var results: Array = []


func check(label: String, cond: bool, extra: String = "") -> void:
	print(("OK      " if cond else "FALHOU  ") + label + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func feedback() -> String:
	return (ui.find_child("FeedbackLabel", true, false) as Label).text


func type_answer(v: int) -> void:
	ui.current_input_text = str(v)
	ui._update_input_display()


func _ready() -> void:
	var tree := get_tree()
	await tree.process_frame
	# Roda fora da cena atual: a fase vira a cena atual (o menu de pausa exige isso).
	get_parent().remove_child(self)
	tree.root.add_child(self)
	var lvl: Node = load("res://scenes/levels/slums/slums_stage1.tscn").instantiate()
	tree.root.add_child(lvl)
	tree.current_scene = lvl
	await frames(5)
	for g in tree.get_nodes_in_group("guards"):
		g.process_mode = Node.PROCESS_MODE_DISABLED
	ui = tree.get_first_node_in_group("hacking_ui")
	ui.hacking_succeeded.connect(func() -> void: results.append("ok"))
	ui.hacking_failed.connect(func() -> void: results.append("fail"))

	# --- Tela de hack ---
	GameManager.set_state(GameManager.State.HACKING)  # mundo a 5%
	ui.start_hacking(2, 1)
	await frames(3)
	var sol: int = ui.final_target_solution
	check("cronômetro ignora a câmera lenta", ui.hack_timer.ignore_time_scale)
	var t0: float = ui.hack_timer.time_left
	await real(1.0)
	var spent: float = t0 - ui.hack_timer.time_left
	check("com o mundo a 5% o relógio anda 1 s por segundo", absf(spent - 1.0) < 0.25, "%.2f s" % spent)
	check("instrução inicial abaixo da resposta", feedback().begins_with("Digite o valor de x"), feedback())

	t0 = ui.hack_timer.time_left
	ui._on_submit_pressed()
	await frames(2)
	check("confirmar vazio só avisa", "Digite um número" in feedback() and ui.error_count == 0, feedback())
	check("confirmar vazio não tira tempo", ui.hack_timer.time_left > t0 - 0.5)

	type_answer(sol + 1)
	t0 = ui.hack_timer.time_left
	ui._on_submit_pressed()
	await frames(2)
	check("erro mostra mensagem de incorreto com o valor", "INCORRETO" in feedback() and str(sol + 1) in feedback(), feedback())
	check("erro tira 3 s", ui.hack_timer.time_left < t0 - 2.5, "%.1f -> %.1f" % [t0, ui.hack_timer.time_left])
	check("erro limpa a resposta", ui.current_input_text == "")
	check("SINE ainda fechada após 1 erro", not ui.ai_assistant_panel.visible)

	type_answer(sol + 2)
	ui._on_submit_pressed()
	await frames(2)
	check("2º erro abre o passo a passo da SINE", ui.ai_assistant_panel.visible and "SINE abriu" in feedback())
	var hint: String = ui.ai_hint_label.text
	check("passo a passo chega na resposta certa", hint.contains("x = %d / %d" % [sol * int(ui.eq_data["ParamMult"]), int(ui.eq_data["ParamMult"])]), hint.replace("\n", " | "))
	await real(1.4)
	check("texto da SINE aparece todo em tempo real", ui.ai_hint_label.visible_ratio >= 0.99, "%.2f" % ui.ai_hint_label.visible_ratio)

	type_answer(sol)
	ui._on_submit_pressed()
	await frames(2)
	check("acerto mostra CORRETO antes de fechar", "CORRETO" in feedback() and ui.visible, feedback())
	ui._on_numpad_key_pressed("7")
	check("teclado travado enquanto mostra o acerto", ui.current_input_text == "" or ui.current_input_text == str(sol))
	await real(1.2)
	check("acerto fecha a tela e conclui o hack", not ui.visible and results.back() == "ok")

	ui.start_hacking(1, 0)
	await frames(3)
	ui._on_hack_timer_timeout()
	await frames(2)
	check("tempo esgotado avisa antes de fechar", "TEMPO ESGOTADO" in feedback() and ui.visible, feedback())
	await real(1.2)
	check("tempo esgotado conclui como falha", not ui.visible and results.back() == "fail")
	GameManager.set_state(GameManager.State.PLAYING)

	# Dicas de cada tipo de equação usam o x minúsculo da equação.
	var bad := []
	for d in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 0), Vector2i(4, 1)]:
		ui.current_floor_level = d.x
		ui.current_sub_topic = d.y
		ui.eq_data = ui.math_generator.GenerateValidEquation(d.x, d.y)
		var h: String = ui._generate_step_by_step_hint()
		if "X" in h.replace("SINE", "").replace("PASSO", ""):
			bad.append(d)
	check("passo a passo sem X maiúsculo em todos os tipos", bad.is_empty(), str(bad))

	# --- Como jogar ---
	var how := HowToPlay.new()
	tree.root.add_child(how)
	await frames(2)
	var body := how.find_child("Body", true, false) as RichTextLabel
	check("Como jogar traz o objetivo", body != null and "OBJETIVO" in body.get_parsed_text() and "Axioma" in body.get_parsed_text())
	check("Como jogar explica o erro na equação", "Resposta errada" in body.get_parsed_text())
	how.close()
	await frames(2)
	check("Como jogar fecha", not is_instance_valid(how))

	# --- Caixa de diálogo ---
	var script_lines: Array = Dialogue.lines_for("rnd_elevator")
	var unknown := script_lines.filter(func(l): return not Dialogue.SPEAKERS.has(String(l["who"])))
	check("roteiro do elevador carrega do JSON", script_lines.size() >= 4 and unknown.is_empty(), "%d falas" % script_lines.size())
	var ended: Array = []
	Dialogue.finished.connect(func(id: String) -> void: ended.append(id), CONNECT_ONE_SHOT)
	GameManager.set_state(GameManager.State.HACK_VISION)  # mundo a 25%
	Dialogue.play("teste_ui", [{"who": "SINE", "text": "Linha um com bastante texto para digitar."}, {"who": "EDUARDO", "text": "Linha dois."}, {"who": "AXIOMA", "text": "Três."}])
	check("diálogo abre e pausa o jogo", Dialogue.is_open() and tree.paused and Engine.time_scale == 1.0)
	await real(0.3)
	check("texto aparece aos poucos", not Dialogue.is_line_complete())
	await real(1.0)
	check("digitação termina em tempo real", Dialogue.is_line_complete())
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)  # Esc com diálogo aberto não abre a pausa
	await frames(2)
	check("Esc pula o diálogo (sem abrir a pausa)", not Dialogue.is_open() and not PauseMenu.is_open() and ended == ["teste_ui"])
	check("fim do diálogo devolve o jogo", not tree.paused and GameManager.state == GameManager.State.PLAYING)
	check("diálogo marcado como visto", "teste_ui" in GameManager.dialogues_seen)
	Dialogue.play("teste_ui2", [{"who": "SINE", "text": "Primeira fala."}, {"who": "VANCE", "text": "Segunda."}])
	Dialogue.advance()
	check("primeiro E completa a fala", Dialogue.is_line_complete() and Dialogue.current_speaker() == "SINE")
	Dialogue.advance()
	check("segundo E passa para a próxima fala", Dialogue.current_speaker() == "VANCE")
	Dialogue.advance(); Dialogue.advance()
	check("última fala fecha o diálogo", not Dialogue.is_open() and not tree.paused)
	GameManager.dialogues_seen.clear()

	# --- Menu de pausa ---
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	check("Esc abre a pausa durante a fase", PauseMenu.is_open() and tree.paused)
	PauseMenu._show_how_to()
	await frames(2)
	check("pausa abre o Como jogar", PauseMenu._how_to != null)
	PauseMenu._how_to.close()
	await frames(2)
	PauseMenu.resume()
	await frames(2)
	check("retomar despausa", not PauseMenu.is_open() and not tree.paused)
	ui.start_hacking(1, 0)
	await frames(2)
	Input.parse_input_event(ev)
	await frames(3)
	check("Esc não abre a pausa durante o hack", not PauseMenu.is_open())
	check("Esc durante o hack aborta", "ABORTADO" in feedback(), feedback())
	await real(0.8)
	check("hack abortado fecha como falha", not ui.visible and results.back() == "fail")

	# Abortar (GDD §4): chance de alerta cresce com o tempo restante; lockdown não deixa.
	var aborted: Array = []
	ui.hacking_aborted.connect(func(alert: bool) -> void: aborted.append(alert))
	var alarms := [0]
	GameManager.alarm_raised.connect(func(_pp: Vector2) -> void: alarms[0] += 1)
	ui.start_hacking(1, 0)
	await frames(3)
	var c_full: float = ui.abort_alert_chance()
	ui.hack_timer.start(ui._time_total * 0.25)
	var c_late: float = ui.abort_alert_chance()
	check("abortar cedo arrisca mais que abortar no fim", c_full > c_late and c_full <= 0.6, "%.2f > %.2f" % [c_full, c_late])
	ui.abort_hack(0.0)  # sorteio garantido: alerta
	await real(0.8)
	check("abortar com rastro soa o alarme", aborted.back() == true and alarms[0] == 1)
	ui.start_hacking(1, 0)
	await frames(3)
	ui.abort_hack(0.99)  # sorteio acima da chance: sem alerta
	await real(0.8)
	check("abortar sem rastro não soa alarme", aborted.back() == false and alarms[0] == 1)
	ui.can_abort = false
	ui.start_hacking(1, 0)
	await frames(3)
	check("lockdown avisa que não dá para abortar", "não há como abortar" in feedback(), feedback())
	ui.abort_hack(0.99)
	await real(0.8)
	check("lockdown: Esc não fecha o hack", ui.visible and "LOCKDOWN" in feedback())
	ui._complete_hack(false)
	ui.can_abort = true

	print("TUDO OK — 0 falha(s)" if fails == 0 else "%d FALHA(S)" % fails)
	tree.quit(1 if fails > 0 else 0)
