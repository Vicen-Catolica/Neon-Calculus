extends Node
## Autoload global. Guarda o estado de alto nível do jogo e centraliza os sinais
## (padrão Observer) que o resto do jogo escuta.

signal state_changed(new_state: State)
signal hack_vision_changed(active: bool)
signal variance_changed(value: float, limit: float)
signal sweep_triggered

enum State { PLAYING, HACK_VISION, HACKING, PAUSED, GAME_OVER }

## Fator de velocidade do mundo em cada modo.
const WORLD_SPEED_NORMAL: float = 1.0
const WORLD_SPEED_HACK_VISION: float = 0.25
const WORLD_SPEED_HACKING: float = 0.05

var state: State = State.PLAYING
var variance: float = 0.0
var variance_limit: float = 100.0
## Acessibilidade: pausa total durante a equação em vez de câmera lenta.
var pause_on_hacking: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	variance = clampf(variance + amount, 0.0, variance_limit)
	variance_changed.emit(variance, variance_limit)
	if variance >= variance_limit:
		sweep_triggered.emit()


func reset_variance() -> void:
	variance = 0.0
	variance_changed.emit(variance, variance_limit)


func _time_scale_for(s: State) -> float:
	match s:
		State.HACK_VISION:
			return WORLD_SPEED_HACK_VISION
		State.HACKING:
			return WORLD_SPEED_HACKING
		_:
			return WORLD_SPEED_NORMAL
