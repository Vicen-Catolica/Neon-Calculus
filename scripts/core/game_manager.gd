extends Node
## Autoload global. Guarda o estado de alto nível do jogo e centraliza os sinais
## (padrão Observer) que o resto do jogo escuta.

signal state_changed(new_state: State)
signal hack_vision_changed(active: bool)
signal variance_changed(value: float, limit: float)
signal sweep_triggered
## Câmera/varredura detectou o jogador: guardas próximos vão até a posição.
signal alarm_raised(world_position: Vector2)
signal lore_unlocked(entry_id: String)

enum State { PLAYING, HACK_VISION, HACKING, PAUSED, GAME_OVER }

## Fator de velocidade do mundo em cada modo.
const WORLD_SPEED_NORMAL: float = 1.0
const WORLD_SPEED_HACK_VISION: float = 0.25
const WORLD_SPEED_HACKING: float = 0.05

var state: State = State.PLAYING
var variance: float = 0.0
var variance_limit: float = 100.0
## Andar atual da torre (1 = favelas). Define a dificuldade base das equações.
var current_floor: int = 1
## Logs de lore já lidos (ids do JSON), persistem entre fases.
var lore_read: Array[String] = []
## Variância somada por cada alarme disparado.
const ALARM_VARIANCE: float = 20.0
## Segundos sem hack/alarme até a variância começar a cair.
const VARIANCE_DECAY_DELAY: float = 8.0
## Pontos de variância perdidos por segundo depois do atraso.
const VARIANCE_DECAY_RATE: float = 2.5
var _calm_time: float = 0.0
## Acessibilidade: pausa total durante a equação em vez de câmera lenta.
var pause_on_hacking: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Variância baixa sozinha quando o jogador passa um tempo sem hackear nem ser visto.
func _process(delta: float) -> void:
	if state != State.PLAYING or get_tree().paused:
		return
	_calm_time += delta
	if _calm_time >= VARIANCE_DECAY_DELAY and variance > 0.0:
		variance = maxf(variance - VARIANCE_DECAY_RATE * delta, 0.0)
		variance_changed.emit(variance, variance_limit)


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	var was_vision := state == State.HACK_VISION
	state = new_state
	Engine.time_scale = _time_scale_for(new_state)
	# Pausa total (acessibilidade): HackingInterface roda em PROCESS_MODE_ALWAYS.
	get_tree().paused = new_state == State.HACKING and pause_on_hacking
	state_changed.emit(new_state)
	var is_vision := new_state == State.HACK_VISION
	if was_vision != is_vision:
		hack_vision_changed.emit(is_vision)


func add_variance(amount: float) -> void:
	if amount > 0.0:
		_calm_time = 0.0
	variance = clampf(variance + amount, 0.0, variance_limit)
	variance_changed.emit(variance, variance_limit)
	if variance >= variance_limit:
		sweep_triggered.emit()


func reset_variance() -> void:
	variance = 0.0
	_calm_time = 0.0
	variance_changed.emit(variance, variance_limit)


## Chamado ao entrar numa fase nova (ou recomeçar após game over).
func start_level(floor_number: int) -> void:
	current_floor = floor_number
	set_state(State.PLAYING)
	Engine.time_scale = WORLD_SPEED_NORMAL
	reset_variance()


func raise_alarm(world_position: Vector2) -> void:
	alarm_raised.emit(world_position)
	add_variance(ALARM_VARIANCE)


func mark_lore_read(entry_id: String) -> void:
	if entry_id in lore_read:
		return
	lore_read.append(entry_id)
	lore_unlocked.emit(entry_id)


func _time_scale_for(s: State) -> float:
	match s:
		State.HACK_VISION:
			return WORLD_SPEED_HACK_VISION
		State.HACKING:
			return WORLD_SPEED_HACKING
		_:
			return WORLD_SPEED_NORMAL
