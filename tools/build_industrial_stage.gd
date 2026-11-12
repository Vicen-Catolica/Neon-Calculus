extends Node
## Gera a Fase 2 (Setor Industrial e de Manutenção). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_industrial_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## Etapa 1 do docs/PLANO_FASE_2.md: só um placeholder jogável (chão, paredes,
## Eduardo e a interface) para validar a transição e o checkpoint. O layout
## A–E entra na etapa 3, depois de o builder compartilhado existir (etapa 2).

const OUT_LEVEL := "res://scenes/levels/industrial/industrial_stage2.tscn"
const WIDTH := 2400.0
const FLOOR_Y := 16.0


func _ready() -> void:
	_build_level()
	print("build_industrial_stage: OK")
	get_tree().quit()


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	if node.scene_file_path != "":
		return
	for c in node.get_children():
		_own(c, owner_node)


func _build_level() -> void:
	var lvl := Node2D.new()
	lvl.name = "IndustrialStage2"
	lvl.set_script(load("res://scripts/core/level.gd"))
	lvl.set("floor_number", 2)
	lvl.set("limit_left", -32)
	lvl.set("limit_right", int(WIDTH) + 32)
	lvl.set("limit_top", -700)
	lvl.set("limit_bottom", 300)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.07, 0.055, 0.05)
	bg.position = Vector2(-1000, -1600)
	bg.size = Vector2(WIDTH + 2000, 2000)
	lvl.add_child(bg)

	var solid := StaticBody2D.new()
	solid.name = "Solid"
	lvl.add_child(solid)
	# chão + paredes das pontas
	for r in [Rect2(-64, FLOOR_Y, WIDTH + 128, 320), Rect2(-64, -900, 64, 1000), Rect2(WIDTH, -900, 64, 1000)]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		solid.add_child(cs)
		var vis := ColorRect.new()
		vis.color = Color(0.24, 0.17, 0.12)
		vis.position = r.position
		vis.size = r.size
		lvl.add_child(vis)

	var sign := Label.new()
	sign.name = "WipSign"
	sign.text = "SETOR INDUSTRIAL // EM CONSTRUÇÃO"
	sign.position = Vector2(420, -260)
	sign.add_theme_font_size_override("font_size", 28)
	sign.add_theme_color_override("font_color", Color("FF6A1A"))
	lvl.add_child(sign)

	var sweep := Node2D.new()
	sweep.name = "RoutineSweep"
	sweep.set_script(load("res://scripts/core/routine_sweep.gd"))
	lvl.add_child(sweep)

	var player: Node2D = (load("res://scenes/player/eduardo.tscn") as PackedScene).instantiate()
	player.name = "Eduardo"
	player.position = Vector2(96, FLOOR_Y)
	lvl.add_child(player)

	for path in ["res://scenes/Hud/HUD.tscn", "res://scenes/ui/stealth_hud.tscn",
			"res://scenes/hacking_ui/HackingInterface.tscn", "res://scenes/ui/lore_reader.tscn"]:
		var n: Node = (load(path) as PackedScene).instantiate()
		if path.ends_with("HackingInterface.tscn"):
			n.name = "HackingInterface"
			n.visible = false
		lvl.add_child(n)

	for c in lvl.get_children():
		_own(c, lvl)
	var ps := PackedScene.new()
	assert(ps.pack(lvl) == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_LEVEL.get_base_dir()))
	assert(ResourceSaver.save(ps, OUT_LEVEL) == OK)
	print("  salvo ", OUT_LEVEL)
	lvl.free()
