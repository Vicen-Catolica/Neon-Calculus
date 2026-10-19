extends Node
## Chama o MathGenerator (C#) via GDScript, como a HackingInterface faz.
func _ready() -> void:
	var g = load("res://scenes/hacking_ui/MathGenerator.cs").new()
	for stage in range(1, 5):
		for sub in 2:
			var eq = g.GenerateValidEquation(stage, sub)
			print("stage ", stage, "/", sub, ": ", eq["Expression"], "  x=", eq["Solution"], "  keys=", eq.size())
	get_tree().quit()