extends Node
## Autoload "Sfx": toca efeitos sonoros de assets/sfx/<nome>.wav no bus SFX.
## Os sons são carregados pelo nome na primeira vez; som que não existe fica
## mudo (sem erro), então dá para trocar/remover arquivos à vontade.
##
##   Sfx.play("hack_ok")                  # som de interface (não posicional)
##   Sfx.play_at("taser", global_position) # som no mundo (atenua com a distância)
##   Sfx.play_any(["step_1", "step_2"], -6.0)
##
## Roda também com o jogo pausado (diálogos e tela de hack pausam a árvore).

const DIR := "res://assets/sfx/"
const POOL := 12
const POOL_2D := 10
## O mesmo som não repete antes disto (evita "metralhar" o mesmo efeito).
const MIN_GAP_MS := 35

var _cache: Dictionary = {}
var _last_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _next := 0
var _next_2d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer2D.new()
		q.bus = bus
		q.max_distance = 1400.0
		q.attenuation = 1.6
		add_child(q)
		_players_2d.append(q)


func stream(sfx_name: String) -> AudioStream:
	if not _cache.has(sfx_name):
		var path := DIR + sfx_name + ".wav"
		_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sfx_name]


func _ready_to_play(sfx_name: String) -> AudioStream:
	var s := stream(sfx_name)
	if s == null:
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sfx_name, -100000)) < MIN_GAP_MS:
		return null
	_last_ms[sfx_name] = now
	return s


func play(sfx_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	var s := _ready_to_play(sfx_name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_at(sfx_name: String, world_pos: Vector2, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	var s := _ready_to_play(sfx_name)
	if s == null:
		return
	var q := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	q.stream = s
	q.global_position = world_pos
	q.volume_db = volume_db
	q.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	q.play()


func play_any(names: Array, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if names.is_empty():
		return
	play(String(names[randi() % names.size()]), volume_db, pitch_jitter)


## Últimos sons pedidos (para os testes).
func last_played_ms(sfx_name: String) -> int:
	return int(_last_ms.get(sfx_name, -1))
