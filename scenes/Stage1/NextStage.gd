extends Area2D

@export_file("*.tscn") var next_stage: String

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if next_stage != "":
			# Usa call_deferred para evitar o erro de física ao remover a cena
			get_tree().change_scene_to_file.call_deferred(next_stage)
		else:
			print("ERRO: O campo 'Next Stage' está vazio no Inspetor!")
