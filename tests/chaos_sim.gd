extends Node
## Playtest de "caos": um robô aperta teclas ao acaso em cada fase (andar, correr,
## pular, agachar, esconder, visão hacker, hackear certo/errado/abortar/deixar o
## tempo acabar, sonar, camuflagem, pausa, reiniciar andar, game over) e vigia
## invariantes de estado a cada quadro: jogo pausado sem tela aberta, câmera
## lenta presa, estado HACKING sem a tela, duas telas ao mesmo tempo, mundo
## rodando atrás do game over, Eduardo fora do mapa etc.
## Não entra no roteiro do CI (é aleatório); serve para caçar bugs. Uso:
##   CHAOS_SECS=60 CHAOS_SEED=1 godot --headless --path . res://tests/chaos_sim.tscn
## Preserva o save do jogador.

var secs_per_level := float(OS.get_environment("CHAOS_SECS")) if OS.get_environment("CHAOS_SECS") != "" else 60.0
var seed_value := int(OS.get_environment("CHAOS_SEED")) if OS.get_environment("CHAOS_SEED") != "" else 1
var only_levels := OS.get_environment("CHAOS_LEVELS")

var rng := RandomNumberGenerator.new()
## label -> [contagem, primeiro detalhe]
var issues := {}
var counters := {}
## label -> segundos em que a condição ruim está valendo (para tolerar 1–2 quadros).
var _bad_since := {}
var _level_path := ""
var _last_teleport := -99.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	await tree.process_frame
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	_run()


func issue(label: String, detail: String = "") -> void:
	if not issues.has(label):
		issues[label] = [0, "%s @ %s t=%.1f" % [detail, _level_path.get_file(), _clock]]
		print("BUG?    %s  %s" % [label, issues[label][1]])
	issues[label][0] += 1


func count(label: String) -> void:
	counters[label] = int(counters.get(label, 0)) + 1


## Condição ruim que precisa durar `grace` segundos seguidos para virar problema.
func watch(label: String, bad: bool, grace: float, detail: String = "") -> void:
	if not bad:
		_bad_since.erase(label)
		return
	if not _bad_since.has(label):
		_bad_since[label] = _clock
	elif _clock - float(_bad_since[label]) >= grace:
		issue(label, detail)
		_bad_since[label] = _clock + 9999.0  # não repete a cada quadro


# --- entrada ------------------------------------------------------------

func act(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tap(action: String) -> void:
	act(action, true)
	await frames(2)
	act(action, false)
	await frames(1)


func key(code: Key, unicode: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(1)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)


func type_number(n: int) -> void:
	for ch in str(n):
		await key(KEY_0 + int(ch), ch.unicode_at(0))


func release_all() -> void:
	for a in ["move_left", "move_right", "run", "crouch", "jump", "climb_up", "climb_down",
			"hack_vision", "hack_confirm", "hack_next_target", "interact_world", "sonar_ping", "camo"]:
		act(a, false)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


# --- estado do jogo -----------------------------------------------------

func player() -> Eduardo:
	return get_tree().get_first_node_in_group("Player") as Eduardo


func hacking_ui() -> CanvasLayer:
	return get_tree().get_first_node_in_group("hacking_ui") as CanvasLayer


func hacking_open() -> bool:
	var h := hacking_ui()
	return h != null and h.visible


func game_over() -> Node:
	for c in get_tree().root.get_children():
		if c is GameOver:
			return c
	return null


func lore_open() -> bool:
	for r in get_tree().get_nodes_in_group("lore_reader"):
		if r.has_method("is_open") and r.is_open():
			return true
	return false


func how_to_open() -> bool:
	for c in get_tree().root.get_children():
		if c is HowToPlay:
			return true
	return PauseMenu.get("_how_to") != null


func overlays() -> Array[String]:
	var o: Array[String] = []
	if hacking_open():
		o.append("hack")
	if PauseMenu.is_open():
		o.append("pausa")
	if Dialogue.is_open():
		o.append("diálogo")
	if game_over() != null:
		o.append("game over")
	if lore_open():
		o.append("lore")
	if LevelTransition.is_busy():
		o.append("transição")
	return o


func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.01)
	var lvl := get_tree().current_scene as Level
	if lvl == null:
		_bad_since.clear()
		return
	var tree := get_tree()
	var ov := overlays()
	var st: int = GameManager.state
	var p := player()

	watch("jogo pausado sem nenhuma tela aberta", tree.paused and ov.is_empty() and not how_to_open(), 0.6,
			"state=%d" % st)
	watch("câmera lenta presa fora da visão hacker/hack", not tree.paused and ov.is_empty()
			and st == GameManager.State.PLAYING and not is_equal_approx(Engine.time_scale, 1.0), 0.5,
			"time_scale=%.2f" % Engine.time_scale)
	watch("estado HACKING sem a tela de hack", st == GameManager.State.HACKING and not hacking_open(), 0.5)
	watch("estado PAUSED sem diálogo/lore", st == GameManager.State.PAUSED and not Dialogue.is_open()
			and not lore_open() and not LevelTransition.is_busy(), 0.6)
	watch("tela de hack aberta fora do estado HACKING", hacking_open() and st != GameManager.State.HACKING, 0.5,
			"state=%d" % st)
	var ov_real := ov.filter(func(s: String) -> bool: return s != "transição")
	watch("duas telas abertas ao mesmo tempo", ov_real.size() >= 2, 0.3, ", ".join(ov))
	watch("mundo rodando atrás do game over", game_over() != null and not tree.paused, 0.3)
	if p:
		watch("Eduardo morto sem tela de game over", p.is_dead and game_over() == null
				and not LevelTransition.is_busy(), 2.5)
		watch("Eduardo fora do mapa", not p.is_dead and p.global_position.y > lvl.limit_bottom + 400
				and _clock - _last_teleport > 3.0, 1.0, "pos=%s" % p.global_position)
		watch("camuflagem ligada além da bateria", p.camouflaged and not tree.paused, 6.5)
		watch("Eduardo escondido e se movendo", p.is_hidden() and absf(p.velocity.x) > 1.0, 0.3)
		watch("HUD de vida escondido jogando normalmente", ov.is_empty() and not tree.paused
				and not p.is_dead and not _hud_visible(), 1.0)


func _hud_visible() -> bool:
	for h in get_tree().get_nodes_in_group("hud"):
		if h is HUD:
			return (h as HUD).visible
	return true


# --- roteiro ------------------------------------------------------------

func _run() -> void:
	rng.seed = seed_value
	var backup := SaveGame.load_checkpoint()
	var keys: Array = GameManager.LEVELS.keys()
	keys.sort()
	for n in keys:
		if only_levels != "" and not (str(n) in only_levels.split(",")):
			continue
		await _play_level(int(n))
	release_all()

	print("\n==== RESUMO DO CAOS (semente %d, %.0f s por fase) ====" % [seed_value, secs_per_level])
	var names := counters.keys()
	names.sort()
	for k in names:
		print("  %-40s %d" % [k, counters[k]])
	if issues.is_empty():
		print("Nenhuma invariante quebrada.")
	for k in issues:
		print("BUG?    %s  (%dx) primeiro: %s" % [k, issues[k][0], issues[k][1]])

	# Restaura o save do jogador.
	SaveGame.clear()
	if not backup.is_empty():
		SaveGame._write(backup)
	print("TUDO OK" if issues.is_empty() else "%d PROBLEMA(S)" % issues.size())
	get_tree().quit(0 if issues.is_empty() else 1)


func _load_level(n: int) -> void:
	_level_path = GameManager.LEVELS[n]["scene"]
	LevelTransition.change_level(_level_path)
	await frames(2)
	while LevelTransition.is_busy():
		await frames(1)
	await _prepare_level()


## Depois de (re)carregar: saída desligada, guardas sempre ativos (sem janela o
## VisibleOnScreenEnabler2D nunca liga).
func _prepare_level() -> void:
	await frames(3)
	var lvl := get_tree().current_scene
	if lvl == null:
		return
	for e in lvl.find_children("*", "LevelExit", true, false):
		(e as LevelExit).next_stage = ""
	for g in get_tree().get_nodes_in_group("guards"):
		var en := g.get_node_or_null("VisibleOnScreenEnabler2D")
		if en:
			en.queue_free()
		g.process_mode = Node.PROCESS_MODE_INHERIT


func _play_level(n: int) -> void:
	print("\n---- fase %d: %s" % [n, GameManager.LEVELS[n]["title"]])
	GameManager.reset_progress()
	SaveGame.clear()
	await _load_level(n)
	var t0 := _clock
	var scene_id := get_tree().current_scene.get_instance_id() if get_tree().current_scene else 0
	while _clock - t0 < secs_per_level:
		var cur := get_tree().current_scene
		if cur and cur.get_instance_id() != scene_id:
			scene_id = cur.get_instance_id()
			await _prepare_level()
		if cur == null and not LevelTransition.is_busy():
			# Foi para o menu principal: volta para a fase.
			await _load_level(n)
			continue
		await _step()
	release_all()
	# Fecha o que ficou aberto.
	if hacking_open():
		hacking_ui().call("_complete_hack", false)
	if Dialogue.is_open():
		Dialogue.skip()
	if PauseMenu.is_open():
		PauseMenu.resume()
	var go := game_over()
	if go:
		go.queue_free()
		get_tree().paused = false
	await frames(5)


## Uma ação aleatória, já reagindo a telas abertas.
func _step() -> void:
	if LevelTransition.is_busy():
		await frames(5)
		return
	var go := game_over()
	if go:
		count("game over")
		await wait_real(rng.randf_range(0.5, 2.0))
		if not is_instance_valid(go):
			return
		var b: Button = go.find_child("ButtonMenu" if rng.randf() < 0.15 else "ButtonRestart", true, false)
		if b:
			count("game over → " + b.name)
			b.pressed.emit()
		await frames(10)
		return
	if hacking_open():
		await _hack_answer()
		return
	if Dialogue.is_open():
		count("diálogo")
		var r := rng.randf()
		if r < 0.2:
			await tap("ui_cancel")
		elif r < 0.5:
			await tap("interact_world")
		else:
			await tap("hack_confirm")
		await wait_real(rng.randf_range(0.05, 0.6))
		return
	if lore_open():
		count("lore lida")
		await wait_real(rng.randf_range(0.2, 1.0))
		await tap("ui_cancel" if rng.randf() < 0.5 else "interact_world")
		return
	if PauseMenu.is_open():
		await _pause_menu()
		return

	var r := rng.randf()
	if r < 0.30:
		await _walk()
	elif r < 0.38:
		await _jump()
	elif r < 0.44:
		await _climb()
	elif r < 0.52:
		count("interagir (F)")
		await tap("interact_world")
		await wait_real(rng.randf_range(0.1, 1.5))
	elif r < 0.70:
		await _hack_vision()
	elif r < 0.75:
		count("sonar")
		await tap("sonar_ping")
	elif r < 0.80:
		count("camuflagem")
		await tap("camo")
	elif r < 0.84:
		count("pausa (Esc)")
		await tap("ui_cancel")
		await frames(3)
	elif r < 0.97:
		_teleport()
		await frames(2)
	else:
		# Esc no mesmo quadro de outras teclas (casos de borda).
		count("Esc + tecla junto")
		act("hack_vision", true)
		await frames(rng.randi_range(1, 20))
		act("hack_confirm", true)
		act("ui_cancel", true)
		await frames(2)
		release_all()
		act("ui_cancel", false)


func _walk() -> void:
	var dir := "move_left" if rng.randf() < 0.4 else "move_right"
	var mods: Array[String] = []
	if rng.randf() < 0.35:
		mods.append("run")
	if rng.randf() < 0.25:
		mods.append("crouch")
	count("andar" + ("+" + "+".join(mods) if not mods.is_empty() else ""))
	act(dir, true)
	for m in mods:
		act(m, true)
	var t := rng.randf_range(0.2, 2.0)
	var t0 := _clock
	while _clock - t0 < t:
		if rng.randf() < 0.03:
			await tap("jump")
		if game_over() or hacking_open() or Dialogue.is_open() or PauseMenu.is_open():
			break
		await frames(1)
	act(dir, false)
	for m in mods:
		act(m, false)


func _jump() -> void:
	count("pular")
	act("jump", true)
	await frames(rng.randi_range(1, 25))
	act("jump", false)
	await wait_real(rng.randf_range(0.1, 0.6))


func _climb() -> void:
	var p := player()
	var ladders := get_tree().get_nodes_in_group("ladder")
	if p and not ladders.is_empty() and rng.randf() < 0.6:
		var l := ladders[rng.randi() % ladders.size()] as Node2D
		p.global_position = l.global_position + Vector2(0, rng.randf_range(-20, 60))
		_last_teleport = _clock
		await frames(2)
	count("escada")
	var a := "climb_up" if rng.randf() < 0.6 else "climb_down"
	act(a, true)
	await wait_real(rng.randf_range(0.3, 2.5))
	if rng.randf() < 0.3:
		await tap("jump")
	act(a, false)


func _hack_vision() -> void:
	count("visão hacker")
	# Metade das vezes chega perto de um alvo antes (sem mouse, o alvo é o mais
	# próximo do canto da tela; Tab troca).
	var p := player()
	var targets := get_tree().get_nodes_in_group("hackable").filter(
			func(h: Node) -> bool: return h is Hackable and (h as Hackable).can_be_hacked())
	if p and not p.is_dead and not targets.is_empty() and rng.randf() < 0.6:
		var h := targets[rng.randi() % targets.size()] as Node2D
		p.global_position = _floor_below(h.global_position + Vector2(rng.randf_range(-120, 120), -10))
		p.velocity = Vector2.ZERO
		_last_teleport = _clock
		await frames(3)
	act("hack_vision", true)
	await wait_real(rng.randf_range(0.1, 1.0))
	if rng.randf() < 0.4:
		await tap("hack_next_target")
	if rng.randf() < 0.75:
		count("tentar hackear (E)")
		await tap("hack_confirm")
	if rng.randf() < 0.3:
		await wait_real(rng.randf_range(0.1, 0.8))
	act("hack_vision", false)
	await frames(2)


func _hack_answer() -> void:
	var h := hacking_ui()
	count("hack aberto")
	await wait_real(rng.randf_range(0.2, 1.5))
	if not hacking_open():
		return
	var sol := int(h.get("final_target_solution"))
	var paradox := bool(h.get("paradox_mode"))
	var r := rng.randf()
	if paradox and r < 0.5:
		count("hack: paradoxo N")
		await key(KEY_N, "n".unicode_at(0))
	elif r < 0.45:
		count("hack: resposta certa")
		await type_number(sol)
		await key(KEY_ENTER)
	elif r < 0.65:
		count("hack: resposta errada")
		await type_number(maxi(sol + rng.randi_range(1, 9), 0))
		await key(KEY_ENTER)
	elif r < 0.72:
		count("hack: Enter vazio / apagar")
		await type_number(rng.randi_range(1, 99))
		await key(KEY_BACKSPACE)
		await key(KEY_DELETE)
		await key(KEY_ENTER)
	elif r < 0.88:
		count("hack: Esc")
		await tap("ui_cancel")
	elif r < 0.93:
		count("hack: muitos dígitos")
		await type_number(123456)
		await key(KEY_ENTER)
	else:
		count("hack: deixar o tempo acabar")
		var t0 := _clock
		while hacking_open() and _clock - t0 < 260.0:
			await frames(10)
	await wait_real(0.3)


func _pause_menu() -> void:
	count("menu de pausa")
	await wait_real(rng.randf_range(0.1, 0.8))
	var r := rng.randf()
	if r < 0.45:
		await tap("ui_cancel")  # Retomar
	elif r < 0.6:
		PauseMenu.resume()
	elif r < 0.75:
		count("pausa → Como jogar")
		PauseMenu.call("_show_how_to")
		await wait_real(0.4)
		await tap("ui_cancel")
		await frames(3)
		if PauseMenu.is_open():
			await tap("ui_cancel")
	elif r < 0.93:
		count("pausa → Reiniciar andar")
		PauseMenu.call("_restart_floor")
		await frames(3)
	else:
		count("pausa → Menu principal")
		PauseMenu.call("_main_menu")
		await frames(5)


## Teleporta para perto de algo interessante (esconderijo, alvo, escada, terminal).
func _teleport() -> void:
	var p := player()
	if p == null or p.is_dead:
		return
	var groups := ["hide_spot", "hackable", "ladder", "data_terminal", "guards", "laser", "holding_cell", "kiosk"]
	var g: String = groups[rng.randi() % groups.size()]
	var nodes := get_tree().get_nodes_in_group(g)
	if nodes.is_empty():
		return
	var n := nodes[rng.randi() % nodes.size()] as Node2D
	if n == null:
		return
	count("teleporte → " + g)
	var target := n.global_position + Vector2(rng.randf_range(-60, 60), -8)
	if g == "hackable":
		target = _floor_below(target)
	p.global_position = target
	p.velocity = Vector2.ZERO
	_last_teleport = _clock


## Primeiro chão abaixo de `from` (raio para baixo); se não achar, `from`.
func _floor_below(from: Vector2) -> Vector2:
	var p := player()
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 900), 1)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2) + Vector2(0, -4) if not hit.is_empty() else from
