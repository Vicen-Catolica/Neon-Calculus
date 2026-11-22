class_name DuelAttack
extends Node2D
## Base dos ataques do núcleo no Duelo de Paradoxo. Ciclo: TELEGRAPH (aviso,
## sem dano) -> ACTIVE (causa dano) -> DONE (emite `finished` e se apaga).
## Subclasses implementam _tick(delta, k) e _draw_attack(); `_hits_player()`
## decide o acerto. Tempo do mundo (no hack, desacelera como todo o resto).

signal finished
signal hit_player

enum Phase { IDLE, TELEGRAPH, ACTIVE, DONE }

const RED := Color(1.0, 0.18, 0.25)

@export var telegraph_time: float = 0.8
@export var active_time: float = 2.0
@export var damage: float = 25.0
## Área da arena (global): limites dos desenhos.
@export var arena: Rect2 = Rect2(0, -1090, 1920, 1106)

var phase: Phase = Phase.IDLE
var t: float = 0.0
var hits: int = 0


func start() -> void:
	phase = Phase.TELEGRAPH
	t = 0.0
	hits = 0
	z_index = 40
	queue_redraw()


func is_dangerous() -> bool:
	return phase == Phase.ACTIVE


func _process(delta: float) -> void:
	if phase == Phase.IDLE or phase == Phase.DONE:
		return
	t += delta
	if phase == Phase.TELEGRAPH and t >= telegraph_time:
		phase = Phase.ACTIVE
		t = 0.0
	elif phase == Phase.ACTIVE:
		_tick(delta, clampf(t / active_time, 0.0, 1.0))
		var p := get_tree().get_first_node_in_group("Player") as Node2D
		# Só acerta dentro da janela ativa [0, active_time): no quadro em que ela
		# fecha, a invulnerabilidade de 1 s de um golpe no começo também acaba,
		# e um ataque de 1 s acertava duas vezes.
		if p and t < active_time and _hits_player(p) and DuelHit.hit(p, damage):
			hits += 1
			hit_player.emit()
		if t >= active_time:
			phase = Phase.DONE
			finished.emit()
	queue_redraw()


func _draw() -> void:
	if phase == Phase.TELEGRAPH or phase == Phase.ACTIVE:
		_draw_attack()


## Avanço do ataque ativo; k = fração do tempo ativo (0..1).
func _tick(_delta: float, _k: float) -> void:
	pass


func _hits_player(_p: Node2D) -> bool:
	return false


func _draw_attack() -> void:
	pass


## Alfa do aviso: pisca acelerando até o golpe.
func _telegraph_alpha() -> float:
	var k := clampf(t / telegraph_time, 0.0, 1.0)
	return 0.25 + 0.35 * (0.5 + 0.5 * sin(t * (10.0 + 30.0 * k)))
