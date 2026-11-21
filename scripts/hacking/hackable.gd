class_name Hackable
extends Node2D
## Componente de alvo hackeável. Fica como filho do objeto (câmera, letreiro,
## porta, quiosque, guarda). A posição deste nó é o ponto onde a linha da visão
## hacker termina. O objeto pai reage ao sinal `hacked`.

signal hacked
signal hack_failed

## Novos tipos sempre no fim: o valor numérico fica salvo nas cenas.
enum Kind { CAMERA, DOOR, GUARD, CYBORG, LIGHT, KIOSK, VALVE, CONVEYOR, DRONE, LASER, BRIDGE, NODE }

@export var kind: Kind = Kind.CAMERA
@export var display_name: String = "ALVO"
@export var enabled: bool = true
## Variância somada ao hackear com sucesso / ao falhar.
@export var variance_cost: float = 12.0
@export var variance_fail_cost: float = 25.0
## Somado ao nível da equação (ex.: saída de um lockdown = +1).
@export var difficulty_bonus: int = 0
## Multiplica o tempo limite da equação (< 1 = desafio rápido).
@export var time_limit_mult: float = 1.0
## Falso: Esc não abandona o hack (lockdown).
@export var abortable: bool = true
## >= 0: força o subtópico da equação (nós do Duelo escolhem o tipo do nível 5).
@export var sub_topic_override: int = -1
## Alvo do Paradoxo final (abre a "equação" x = x + 1 em vez do gerador).
@export var paradox: bool = false
## Abre o passo a passo da SINE já no começo do hack.
@export var sine_at_start: bool = false
## Colisor do próprio alvo, ignorado no teste de linha de visão (ex.: porta).
@export var ignore_body: CollisionObject2D

const KIND_LABEL := {
	Kind.CAMERA: "CÂMERA", Kind.DOOR: "PORTA", Kind.GUARD: "AGENTE",
	Kind.CYBORG: "UNIDADE LÓGICA", Kind.LIGHT: "LUZ NEON", Kind.KIOSK: "QUIOSQUE AXIOMA",
	Kind.VALVE: "VÁLVULA DE VAPOR", Kind.CONVEYOR: "ESTEIRA",
	Kind.DRONE: "DRONE DE PATRULHA", Kind.LASER: "BARREIRA LASER",
	Kind.BRIDGE: "PONTE DE LUZ", Kind.NODE: "NODO DE VIGILÂNCIA",
}


func _ready() -> void:
	add_to_group("hackable")


func get_label() -> String:
	return display_name if display_name != "ALVO" else KIND_LABEL[kind]


## Nível (1–5) e subtópico (0/1) passados à HackingInterface.
## Andar atual + dificuldade do tipo: câmera/luz/quiosque < porta/agente < ciborgue.
func get_difficulty() -> Vector2i:
	var floor_level: int = GameManager.current_floor
	var sub_topic := 0
	match kind:
		Kind.DOOR, Kind.GUARD, Kind.DRONE:
			sub_topic = 1
		Kind.CYBORG:
			floor_level += 1
			sub_topic = 1
	if sub_topic_override >= 0:
		sub_topic = sub_topic_override
	return Vector2i(clampi(floor_level + difficulty_bonus, 1, 5), sub_topic)


## Multiplicador final do tempo do hack: o do alvo (ex.: lockdown) vezes o da
## área de segurança máxima da fase, se o alvo estiver dentro dela.
func get_time_mult() -> float:
	var m := time_limit_mult
	var lvl := _level()
	if lvl and lvl.max_security_rect.has_area() and lvl.max_security_rect.has_point(global_position):
		m *= lvl.max_security_time_mult
	return m


func in_max_security() -> bool:
	var lvl := _level()
	return lvl != null and lvl.max_security_rect.has_area() and lvl.max_security_rect.has_point(global_position)


func _level() -> Level:
	var n := get_parent()
	while n and not (n is Level):
		n = n.get_parent()
	return n as Level


func can_be_hacked() -> bool:
	if not enabled:
		return false
	var p := get_parent()
	if p and p.has_method("can_be_hacked"):
		return p.can_be_hacked()
	return true


func resolve(success: bool) -> void:
	if success:
		GameManager.add_variance(variance_cost)
		GameManager.add_stat("hacks")
		hacked.emit()
	else:
		GameManager.add_variance(variance_fail_cost)
		hack_failed.emit()
