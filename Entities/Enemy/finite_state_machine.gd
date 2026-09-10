class_name FiniteStateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	await owner.ready
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transitioned)
			child.actor = owner as CharacterBody2D
			child.fsm = self

	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func change_state(new_state_name: String) -> void:
	var new_state: State = states.get(new_state_name.to_lower())
	if not new_state or new_state == current_state:
		return

	if current_state:
		current_state.exit()

	new_state.enter()
	current_state = new_state

func _on_child_transitioned(state: State, new_state_name: String) -> void:
	if state != current_state:
		return
	change_state(new_state_name)