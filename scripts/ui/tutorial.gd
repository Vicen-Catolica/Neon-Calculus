extends Node
## Autoload "Tutorial": a SINE ensinando dentro do jogo.
##
## 1. Eventos (`Tutorial.event("spotted")`): uma fala de data/dialogue/*.json,
##    uma vez por save, assim que o jogo estiver livre.
## 2. Guias (`Tutorial.guide("hack", origem)`): roteiros passo a passo. A SINE
##    pausa o jogo, a câmera vai até o que ela está mostrando e depois um aviso
##    no alto da tela espera o jogador fazer a ação (segurar Q, apertar E...).
##    Disparados por DialogueTrigger com `guide` (ver stage_builder_base
##    `_tutorial_trigger`). Também uma vez por save (id "guide_<nome>").
##
## As teclas mostradas saem do InputMap: se o jogador remapear, o texto acompanha.

## evento -> id do roteiro
const EVENTS := {
	"spotted": "tut_spotted",
}

const CYAN := Color("00f0ff")
const PAN_TIME := 0.9

signal guide_finished(guide_name: String, completed: bool)

## As simulações de tests/ rodam sem as falas (elas pausam o jogo); um teste
## que queira as falas liga isto.
var allow_in_tests: bool = false
## Guia em andamento ("" = nenhum) e o passo atual (para testes e depuração).
var current_guide: String = ""
var current_step: String = ""

var _pending: Dictionary = {}
var _layer: CanvasLayer
var _banner: PanelContainer
var _banner_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_banner()


# --- Eventos --------------------------------------------------------------

func event(name: String) -> void:
	var id: String = EVENTS.get(name, "")
	if id == "" or id in GameManager.dialogues_seen or _pending.has(id):
		return
	if Dialogue.lines_for(id).is_empty() or not _allowed_here():
		return
	_pending[id] = true
	_play_when_free(id)


## Conversas da SINE nas Fases 1 e 2 (e os guias) ficam mudas nas simulações
## antigas de tests/, que atravessam essas fases sem esperar diálogo.
## As de P&D e Núcleo já eram testadas com diálogo e continuam tocando.
const QUIET_IN_TESTS := ["slums_", "ind_"]


func muted_in_tests(dialogue_id: String) -> bool:
	if _allowed_here():
		return false
	for prefix in QUIET_IN_TESTS:
		if dialogue_id.begins_with(prefix):
			return true
	return false


func _allowed_here() -> bool:
	if allow_in_tests:
		return true
	for a in OS.get_cmdline_args():
		if String(a).begins_with("res://tests/"):
			return false
	return true


func _play_when_free(id: String) -> void:
	# Um instante antes de falar: o jogador vê o "!" do agente primeiro.
	await get_tree().create_timer(0.5, false).timeout
	await _wait_free()
	if _player_ok() and not (id in GameManager.dialogues_seen):
		Dialogue.play_id(id)
	_pending.erase(id)


func _wait_free() -> void:
	while get_tree().paused or Dialogue.is_open() or LevelTransition.is_busy() \
			or GameManager.state != GameManager.State.PLAYING:
		await get_tree().process_frame


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("Player") as Node2D


func _player_ok() -> bool:
	var p := _player()
	return p != null and not p.get("is_dead")


# --- Guias ----------------------------------------------------------------

## Começa um guia (uma vez por save). `origin` é onde ele foi disparado: os
## guias procuram o alvo (agente, câmera...) mais próximo à frente dali.
func guide(guide_name: String, origin: Vector2) -> void:
	var seen_id := "guide_" + guide_name
	if current_guide != "" or seen_id in GameManager.dialogues_seen or not _allowed_here():
		return
	if not has_method("_guide_" + guide_name):
		push_warning("Tutorial: guia '%s' não existe" % guide_name)
		return
	current_guide = guide_name
	var completed: bool = await call("_guide_" + guide_name, origin)
	GameManager.mark_dialogue_seen(seen_id)
	_hide_banner()
	current_guide = ""
	current_step = ""
	guide_finished.emit(guide_name, completed)


## Guia do hack (Fase 1): o primeiro agente. SINE mostra o agente, ensina a
## segurar a visão hacker, mirar e apertar E, e comenta depois do resultado.
func _guide_hack(origin: Vector2) -> bool:
	var guard := _nearest_ahead("guards", origin)
	if guard == null:
		return false
	var hack := _hackable_of(guard)
	await _wait_free()
	if not _player_ok():
		return false

	current_step = "show"
	_pan_to(guard)
	await _say("tut_hack_show")
	_pan_back()

	# Passo 1: segurar a visão hacker.
	current_step = "vision"
	_show_banner("Segure [b][%s][/b] para ativar a visão hacker" % key_of("hack_vision"))
	if not await _wait_until(func() -> bool: return GameManager.state == GameManager.State.HACK_VISION, guard):
		return false

	# Passo 2: mirar no agente e apertar E (segurando Q).
	current_step = "confirm"
	var result := {"done": false, "ok": false}
	if hack:
		hack.hacked.connect(func() -> void: result.done = true; result.ok = true, CONNECT_ONE_SHOT)
		hack.hack_failed.connect(func() -> void: result.done = true, CONNECT_ONE_SHOT)
	var msg_aim := "Continue segurando [b][%s][/b], mire no agente com o mouse e aperte [b][%s][/b]   ([%s] troca de alvo)" % [
		key_of("hack_vision"), key_of("hack_confirm"), key_of("hack_next_target")]
	var msg_back := "Segure [b][%s][/b] de novo para voltar à visão hacker" % key_of("hack_vision")
	while true:
		if not _guide_alive(guard):
			return false
		var st: int = GameManager.state
		if st == GameManager.State.HACKING:
			break
		_show_banner(msg_aim if st == GameManager.State.HACK_VISION else msg_back)
		await get_tree().process_frame

	# Passo 3: a equação (o aviso fica acima da tela de hack).
	current_step = "solve"
	_show_banner("Descubra o valor de [b]x[/b], digite o número e aperte [b][Enter][/b]. Errar custa tempo.", true)
	while GameManager.state == GameManager.State.HACKING:
		await get_tree().process_frame
	_hide_banner()
	await get_tree().process_frame

	current_step = "result"
	await _wait_free()
	if result.ok:
		await _say("tut_hack_done")
		return true
	await _say("tut_hack_failed")
	return false


## Espera `cond` ficar verdadeira; desiste se o guia "morrer" (agente alertado,
## Eduardo morto, fase trocada).
func _wait_until(cond: Callable, guard: Node) -> bool:
	while not cond.call():
		if not _guide_alive(guard):
			return false
		await get_tree().process_frame
	return true


func _guide_alive(guard: Node) -> bool:
	if not _player_ok() or not is_instance_valid(guard) or not guard.is_inside_tree():
		return false
	if guard.has_method("_current_state_name") and guard._current_state_name() == "maxalert":
		return false
	return true


func _say(id: String) -> void:
	if Dialogue.lines_for(id).is_empty():
		return
	if not Dialogue.play_id(id):
		return
	while Dialogue.is_open():
		await get_tree().process_frame


func _nearest_ahead(group: String, origin: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		var n2 := n as Node2D
		if n2 == null or n2.global_position.x < origin.x - 64.0:
			continue
		var d := n2.global_position.distance_to(origin)
		if d < best_d:
			best_d = d
			best = n2
	return best


func _hackable_of(node: Node) -> Hackable:
	for c in node.get_children():
		if c is Hackable:
			return c
	return null


# --- Câmera ---------------------------------------------------------------

var _cam_tween: Tween
var _cam_mode: int = Node.PROCESS_MODE_INHERIT


func _camera() -> Camera2D:
	return get_viewport().get_camera_2d()


## Leva a câmera até `target` (o jogo fica pausado pelo diálogo; a câmera roda
## mesmo assim enquanto o guia a usa).
func _pan_to(target: Node2D) -> void:
	var cam := _camera()
	if cam == null:
		return
	_cam_mode = cam.process_mode
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	var off := target.global_position + Vector2(0, -60) - cam.get_screen_center_position()
	_tween_offset(cam, cam.offset + off)


func _pan_back() -> void:
	var cam := _camera()
	if cam == null:
		return
	_tween_offset(cam, Vector2.ZERO)
	await _cam_tween.finished
	if is_instance_valid(cam):
		cam.process_mode = _cam_mode


func _tween_offset(cam: Camera2D, to: Vector2) -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cam_tween.tween_property(cam, "offset", to, PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Teclas ---------------------------------------------------------------

## Nome da primeira tecla de teclado ligada à ação (ex.: "Q", "Tab").
func key_of(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code: Key = k.keycode
			if code == KEY_NONE:
				code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
			if code == KEY_NONE:
				code = k.physical_keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return action


# --- Aviso no alto da tela ------------------------------------------------

func _build_banner() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 35  # acima da tela de hack (30), abaixo do diálogo (40)
	add_child(_layer)
	_banner = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.08, 0.88)
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_banner.add_theme_stylebox_override("panel", sb)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-440, 36)
	_banner.custom_minimum_size = Vector2(880, 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_banner)
	_banner_label = RichTextLabel.new()
	_banner_label.bbcode_enabled = true
	_banner_label.fit_content = true
	_banner_label.scroll_active = false
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.add_theme_font_size_override("normal_font_size", 22)
	_banner_label.add_theme_font_size_override("bold_font_size", 22)
	var font = load("res://assets/fonts/ui_font.tres") if ResourceLoader.exists("res://assets/fonts/ui_font.tres") else null
	if font:
		_banner_label.add_theme_font_override("normal_font", font)
	_banner.add_child(_banner_label)
	_banner.visible = false


## `bottom`: embaixo da tela (durante o hack, para não cobrir o título).
func _show_banner(text: String, bottom: bool = false) -> void:
	_banner.position.y = 962.0 if bottom else 36.0
	var full := "[center][color=#00f0ff]S.I.N.E. ›[/color]  %s[/center]" % text
	if _banner_label.text != full:
		_banner_label.text = full
		if not _banner.visible:
			Sfx.play("blip_sine", -6.0)
	_banner.visible = true


func _hide_banner() -> void:
	_banner.visible = false


func banner_text() -> String:
	return _banner_label.get_parsed_text() if _banner.visible else ""
