class_name State
extends Node

@warning_ignore("unused_signal")
signal transitioned(state, new_state_name: String)

var actor: CharacterBody2D
var fsm

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass