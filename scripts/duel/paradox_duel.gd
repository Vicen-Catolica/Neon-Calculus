class_name ParadoxDuel
extends Node
## Duelo de Paradoxo (GDD §1, §2, §9): o clímax no Domo de Controle Neural.
##
##   ESPERA -> CAMADA 1 -> 2 -> 3 -> PARADOXO -> VITÓRIA
##
## Em cada camada um Nodo de Vigilância acende (esquerda, direita, topo) e o
## núcleo ataca em padrões que aceleram e se combinam. Hackear o nó (nível 5)
## derruba a camada; errar ou estourar o tempo não mata: o núcleo "recupera a
## camada" (o nó apaga por alguns segundos) e a variância sobe. Quem derruba o
## Eduardo é a Defesa Neural zerar com os ataques (game over volta ao começo do
## Duelo, o checkpoint do andar). Com os 3 nós no chão, o núcleo abre: hackeá-lo
## é o Paradoxo final (x = x + 1, "Ø SEM SOLUÇÃO").
##
## Protocolo Vance (resgate na Fase 3): brecha maior nos pulsos (a "porta" que
## ele deixou) e o passo a passo da SINE já aberto na última camada.

signal layer_started(n: int)
signal layer_cleared(n: int)
signal paradox_ready
signal won
## Depois das falas da vitória: hora da tela de encerramento.
signal ending_ready

enum State { WAITING, LAYER, BETWEEN, PARADOX, WON }

@export var start_delay: float = 2.0
## Tempo das equações dos nós (vezes o 0,8 da segurança máxima): pressão do Duelo.
@export var node_time_mult: float = 0.6
@export var recover_time: float = 4.0
## Pausa (s) entre um padrão de ataque e o próximo em cada camada (a última vale
## também no Paradoxo). Um padrão por vez: o próximo só começa quando o anterior
## acaba, para as saídas nunca se contradizerem (balanceamento, etapa 11).
@export var intervals: Array[float] = [2.4, 1.9, 1.5]
@export var rng_seed: int = 0
## Depois das falas da vitória: branco, silêncio e a tela de encerramento.
## (As simulações desligam para não trocar de cena.)
@export var go_to_ending: bool = true

const ENDING_SCENE := "res://scenes/ui/ending.tscn"
const MUSIC := "res://assets/Music/The_Axioma_Resolve.mp3"

const VANCE_FLAG := "vance_rescued"
## O Duelo só começa depois do confronto (e não o repete após um game over).
const INTRO_DIALOGUE := "duel_confront"
const WIN_FLAG := "axioma_defeated"
const PULSE_GAP := 90.0
const VANCE_PULSE_GAP := 120.0
const GRID_SLOTS := [240.0, 480.0, 720.0, 960.0, 1200.0, 1440.0, 1680.0]
## Brechas sorteadas perto do jogador (balanceamento, etapa 11): a varredura
## chega à altura dele em ~2,6 s e correr cobre ~520 px nesse tempo.
const GAP_NEAR_MIN := 120.0
const GAP_NEAR_MAX := 420.0
## Distância (graus) da borda da brecha até o jogador: sempre fora dela, perto.
const PULSE_OFF_MIN := 4.0
const PULSE_OFF_MAX := 12.0
const CYAN := Color(0.0, 0.94, 1.0)
const RED := Color(1.0, 0.2, 0.25)

var state: State = State.WAITING
var layer: int = 0
var attacks_spawned: int = 0
var core: AxiomaCore
var nodes: Array[SurveillanceNode] = []
var _timer: float = 0.0
var _recover_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _music: AudioStreamPlayer


func _ready() -> void:
	add_to_group("paradox_duel")
	if rng_seed != 0:
		_rng.seed = rng_seed
	var lvl := get_parent()
	core = lvl.get_node("AxiomaCore") as AxiomaCore
	for name in ["NodeLeft", "NodeRight", "NodeTop"]:
		nodes.append(lvl.get_node("SurveillanceNodes/" + name) as SurveillanceNode)
	for i in nodes.size():
		var n := nodes[i]
		n.broken.connect(_on_node_broken.bind(i))
		var h := n.get_node("Hackable") as Hackable
		h.time_limit_mult = node_time_mult
		h.hack_failed.connect(_on_node_failed.bind(i))
	# Protocolo Vance: a SINE abre o passo a passo já no começo da última camada.
	(nodes[2].get_node("Hackable") as Hackable).sine_at_start = GameManager.has_flag(VANCE_FLAG)
	(core.get_node("Hackable") as Hackable).hacked.connect(_on_paradox_inserted)
	_timer = start_delay
	# Trilha do Duelo (GDD §6: synthwave no Duelo de Paradoxo).
	_music = AudioStreamPlayer.new()
	_music.name = "DuelMusic"
	_music.stream = load(MUSIC)
	_music.volume_db = -6.0
	add_child(_music)


func vance() -> bool:
	return GameManager.has_flag(VANCE_FLAG)


func _process(delta: float) -> void:
	# A música cede lugar à do terminal durante o hack.
	if _music.playing:
		_music.stream_paused = GameManager.state == GameManager.State.HACKING
	if _recover_left > 0.0:
		_recover_left -= delta
		if _recover_left <= 0.0 and state == State.LAYER:
			nodes[layer - 1].activate()
	match state:
		State.WAITING:
			if not (INTRO_DIALOGUE in GameManager.dialogues_seen):
				return
			_timer -= delta
			if _timer <= 0.0:
				_begin_layer(1)
		State.LAYER, State.PARADOX:
			if attack_running():
				return
			_timer -= delta
			if _timer <= 0.0:
				spawn_pattern()
				_timer = intervals[clampi(layer, 1, 3) - 1]
		State.BETWEEN:
			_timer -= delta
			if _timer <= 0.0:
				if layer < 3:
					_begin_layer(layer + 1)
				else:
					_open_paradox()


func _begin_layer(n: int) -> void:
	layer = n
	state = State.LAYER
	nodes[n - 1].activate()
	_timer = 1.5
	_flash("CAMADA %d/3 — HACKEIE O NODO DE VIGILÂNCIA" % n, CYAN)
	if n == 1 and not _music.playing:
		_music.play()
	layer_started.emit(n)


func _on_node_broken(i: int) -> void:
	if state != State.LAYER or i != layer - 1:
		return
	core.set_damage(layer)
	clear_attacks()
	_recover_left = 0.0
	state = State.BETWEEN
	_timer = 2.5
	_flash("CAMADA %d DERRUBADA" % layer, Color(0.22, 1.0, 0.08))
	layer_cleared.emit(layer)
	_say("duel_layer_%d" % layer)


func _on_node_failed(i: int) -> void:
	if state != State.LAYER or i != layer - 1:
		return
	nodes[i].deactivate()
	_recover_left = recover_time
	_flash("O NÚCLEO RECUPEROU A CAMADA — O NÓ VOLTA EM %d s" % int(recover_time), RED)


func _open_paradox() -> void:
	state = State.PARADOX
	core.paradox_open = true
	_timer = 2.0
	_flash("O NÚCLEO ABRIU: HACKEIE-O E INSIRA O PARADOXO", CYAN)
	paradox_ready.emit()


func _on_paradox_inserted() -> void:
	if state != State.PARADOX:
		return
	state = State.WON
	add_to_group("blocks_pause")
	clear_attacks()
	_music.stop()  # a vitória é em silêncio
	core.collapse()
	GameManager.set_flag(WIN_FLAG)
	won.emit()
	# Deixa o colapso aparecer um pouco antes das falas finais.
	await get_tree().create_timer(1.5).timeout
	if _say("duel_victory"):
		await Dialogue.finished
	ending_ready.emit()
	if go_to_ending:
		await _white_out(2.5)
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(ENDING_SCENE)


## Tela vai ao branco (tempo real): os neons apagam, sobra a luz.
func _white_out(seconds: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(white)
	get_parent().add_child(layer)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(white, "color:a", 1.0, seconds)
	await tw.finished


## Toca uma fala da Axioma/SINE (pausa o jogo enquanto aberta). false se não há roteiro.
func _say(dialogue_id: String) -> bool:
	if Dialogue.lines_for(dialogue_id).is_empty() or Dialogue.is_open():
		return false
	return Dialogue.play_id(dialogue_id)


func attack_running() -> bool:
	for a in get_tree().get_nodes_in_group("duel_attack"):
		if (a as DuelAttack).phase != DuelAttack.Phase.DONE:
			return true
	return false


func clear_attacks() -> void:
	for a in get_tree().get_nodes_in_group("duel_attack"):
		a.queue_free()


# --- Padrões de ataque ---------------------------------------------------------

## Escolhe e dispara o padrão da camada atual (a camada 3 vale no Paradoxo).
func spawn_pattern() -> void:
	var options := ["sweep_down", "pulse"]
	if layer >= 2:
		options += ["sweep_side", "grid"]
	if layer >= 3:
		options += ["combo", "combo"]
	match options[_rng.randi() % options.size()]:
		"sweep_down":
			_add(_sweep_down(_near_x(GAP_NEAR_MIN, GAP_NEAR_MAX)))
		"pulse":
			_add(_pulse())
		"sweep_side":
			var s := SweepAttack.new()
			s.dir = SweepAttack.Dir.RIGHT if _rng.randi() % 2 == 0 else SweepAttack.Dir.LEFT
			s.gap_center = SweepAttack.CROUCH_GAP
			_add(s)
		"grid":
			_add(_grid(_grid_columns()))
		"combo":
			# Grade + varredura descendo com a brecha num vão da grade: sempre há saída.
			var cols := _grid_columns()
			var free: Array = GRID_SLOTS.filter(func(x): return not (x in cols))
			var px := _player_pos().x
			free.sort_custom(func(a, b): return absf(a - px) < absf(b - px))
			_add(_grid(cols))
			_add(_sweep_down(free[0]))  # o vão livre mais perto do jogador


func _add(a: DuelAttack) -> void:
	a.add_to_group("duel_attack")
	get_parent().add_child(a)
	a.finished.connect(a.queue_free)
	core.charge(a.telegraph_time)
	a.start()
	attacks_spawned += 1


func _sweep_down(gap_x: float) -> SweepAttack:
	var s := SweepAttack.new()
	s.dir = SweepAttack.Dir.DOWN
	s.gap_center = gap_x
	return s


func _pulse() -> PulseAttack:
	var p := PulseAttack.new()
	p.center = core.global_position
	# Brecha perto do ângulo do jogador (mas não em cima dele): exige se mexer,
	# sem pedir uma travessia impossível da arena.
	var to_player := _player_pos() + Vector2(0, -50) - core.global_position
	# A brecha gira para dentro da arena (rumo a "para baixo", 90°): nunca para
	# cima de quem está no chão.
	var pang := rad_to_deg(to_player.angle())
	var side := -1.0 if pang > 90.0 or pang < -90.0 else 1.0
	if absf(pang - 90.0) < 20.0:
		side = 1.0 if _rng.randi() % 2 == 0 else -1.0
	p.gap_width_deg = VANCE_PULSE_GAP if vance() else PULSE_GAP
	p.gap_angle_deg = rad_to_deg(to_player.angle()) + side * (p.gap_width_deg / 2.0 + _rng.randf_range(PULSE_OFF_MIN, PULSE_OFF_MAX))
	return p


func _grid(cols: Array) -> LaserGridAttack:
	var g := LaserGridAttack.new()
	var typed: Array[float] = []
	for c in cols:
		typed.append(float(c))
	g.columns = typed
	return g


func _grid_columns() -> Array:
	var slots: Array = GRID_SLOTS.duplicate()
	for i in range(slots.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	return slots.slice(0, 4)


func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("Player") as Node2D
	return p.global_position if p else Vector2(960, 16)


## x perto do jogador (de `lo` a `hi` px para um lado), dentro da arena.
func _near_x(lo: float, hi: float) -> float:
	var px := _player_pos().x
	var side := 1.0 if _rng.randi() % 2 == 0 else -1.0
	var x := px + side * _rng.randf_range(lo, hi)
	if x < 150.0 or x > 1770.0:
		x = px - side * _rng.randf_range(lo, hi)
	return clampf(x, 150.0, 1770.0)


func _flash(text: String, color: Color) -> void:
	get_tree().call_group("stealth_hud", "_flash", text, color)
