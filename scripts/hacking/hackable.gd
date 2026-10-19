class_name Hackable
extends Node2D
## Componente de alvo hackeável. Fica como filho do objeto (câmera, letreiro,
## porta, quiosque, guarda). A posição deste nó é o ponto onde a linha da visão
## hacker termina. O objeto pai reage ao sinal `hacked`.

signal hacked
signal hack_failed

enum Kind { CAMERA, DOOR, GUARD, CYBORG, LIGHT, KIOSK }

@export var kind: Kind = Kind.CAMERA
@export var display_name: String = "ALVO"
@export var enabled: bool = true
## Variância somada ao hackear com sucesso / ao falhar.
@export var variance_cost: float = 12.0
@export var variance_fail_cost: float = 25.0
## Colisor do próprio alvo, ignorado no teste de linha de visão (ex.: porta).
@export var ignore_body: CollisionObject2D

const KIND_LABEL := {
	Kind.CAMERA: "CÂMERA", Kind.DOOR: "PORTA", Kind.GUARD: "AGENTE",
	Kind.CYBORG: "UNIDADE LÓGICA", Kind.LIGHT: "LUZ NEON", Kind.KIOSK: "QUIOSQUE AXIOMA",
}


func _ready() -> void:
	add_to_group("hackable")


func get_label() -> String:
	return display_name if display_name != "ALVO" else KIND_LABEL[kind]


## Nível (1–4) e subtópico (0/1) passados à HackingInterface.
## Andar atual + dificuldade do tipo: câmera/luz/quiosque < porta/agente < ciborgue.
func get_difficulty() -> Vector2i:
	var floor_level: int = GameManager.current_floor
	var sub_topic := 0
	match kind:
		Kind.DOOR, Kind.GUARD:
			sub_topic = 1
		Kind.CYBORG:
			floor_level += 1
			sub_topic = 1
	return Vector2i(clampi(floor_level, 1, 4), sub_topic)


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
		hacked.emit()
	else:
		GameManager.add_variance(variance_fail_cost)
		hack_failed.emit()
