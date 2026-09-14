class_name StateMachine
extends Node

@export var initial_state: EnemyState
var current_state: EnemyState
var states: Dictionary = {}
var enemy: CharacterBody2D

func init(enemy_ref: CharacterBody2D) -> void:
	enemy = enemy_ref
	
	for child in get_children():
		if child is EnemyState:
			states[child.name.to_lower()] = child
			child.enemy = enemy_ref
			child.state_machine = self
	
	if initial_state:
		current_state = initial_state
		current_state.enter()
		if enemy and enemy.has_method("update_state_indicator"):
			enemy.update_state_indicator(initial_state.name)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_name: String) -> void:
	var key = target_name.to_lower()
	if not states.has(key) or current_state == states[key]:
		return
	
	current_state.exit()
	current_state = states[key]
	current_state.enter()

	if enemy and enemy.has_method("update_state_indicator"):
		enemy.update_state_indicator(key)