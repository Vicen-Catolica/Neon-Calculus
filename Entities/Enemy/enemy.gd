class_name Enemy
extends CharacterBody2D

@export var waypoints: Array[Node2D] = []
@export var speed_patrol: float = 60.0
@export var speed_search: float = 130.0

# Obtém a gravidade padrão configurada no projeto
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_raycast: RayCast2D = $RayCast2D
@onready var hearing_area: Area2D = $HearingArea
@onready var fsm: FiniteStateMachine = $FiniteStateMachine

var player: CharacterBody2D = null
var last_known_player_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	hearing_area.body_entered.connect(_on_hearing_body_entered)

func _physics_process(delta: float) -> void:
	# Aplica gravidade se o inimigo não estiver no chão
	if not is_on_floor():
		velocity.y += gravity * delta

	check_vision()

func check_vision() -> void:
	if vision_raycast.is_colliding():
		var collider = vision_raycast.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("Player")):
			player = collider as CharacterBody2D
			last_known_player_position = player.global_position
			
			# Transita diretamente para Alerta Máximo ao avistar
			if fsm.current_state.name.to_lower() != "alert":
				fsm.change_state("alert")

func _on_hearing_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"):
		player = body as CharacterBody2D
		if body.has_method("is_running") and body.is_running():
			last_known_player_position = body.global_position
			if fsm.current_state.name.to_lower() == "patrol":
				fsm.change_state("suspect")
