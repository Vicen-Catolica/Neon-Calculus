extends Node
## Gera scenes/levels/slums_test.tscn. Rodar como cena principal:
##   godot --headless --path . res://tools/build_slums_test.tscn
## Coordenadas de tile: o topo visual do chão fica em y = linha*32 + 16.

const TILE := 32
const WIDTH := 128
const OUT := "res://scenes/levels/slums_test.tscn"

var root: Node2D
var ground: TileMapLayer
var structs: TileMapLayer


func _ready() -> void:
	root = Node2D.new()
	root.name = "SlumsTest"
	root.set_script(load("res://scripts/core/slums_level.gd"))

	_build_background()
	_build_tiles()
	_build_ladder()
	_build_props()
	_build_signs()
	_build_player()

	var packed := PackedScene.new()
	print("pack: ", packed.pack(root))
	print("save: ", ResourceSaver.save(packed, OUT))
	get_tree().quit()


func _own(n: Node, parent: Node) -> Node:
	parent.add_child(n)
	n.owner = root
	return n


func _build_background() -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color("0f0c1f")
	sky.position = Vector2(-2000, -1400)
	sky.size = Vector2(WIDTH * TILE + 4000, 1700)
	_own(sky, root)

	var par := Parallax2D.new()
	par.name = "BackgroundFar"
	par.scroll_scale = Vector2(0.35, 1.0)
	par.repeat_size = Vector2(1536, 0)
	par.repeat_times = 6
	par.scroll_offset = Vector2(-768, 0)
	_own(par, root)
	var bg := Sprite2D.new()
	bg.name = "Favela"
	bg.texture = load("res://assets/backgrounds/slums/bg_favela_dark_seamless.png")
	bg.centered = false
	bg.position = Vector2(0, 24 - 340)
	_own(bg, par)


func _build_tiles() -> void:
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load("res://assets/tilesets/slums/slums_ground.tres")
	_own(ground, root)

	structs = TileMapLayer.new()
	structs.name = "Structures"
	structs.tile_set = load("res://assets/tilesets/slums/slums_structures.tres")
	_own(structs, root)

	var cells: Array[Vector2i] = []
	# Rua inteira.
	_rect(cells, 0, 0, WIDTH - 1, 9)
	# Degrau de 2 tiles (64 px) que o pulo alcança: x 88..127.
	_rect(cells, 88, -2, WIDTH - 1, -1)
	# Teto baixo (obriga a agachar). A borda do terreno fica no CENTRO dos tiles:`n	# última linha -3 => base em y = -80, vão de 96 px (< 118 em pé, > 86 agachado).
	_rect(cells, 52, -9, 60, -3)
	ground.set_cells_terrain_connect(cells, 0, 0)

	# Passarela de mão única na linha -5 (x 30..44): topo em y = -144.
	structs.set_cell(Vector2i(30, -5), 0, Vector2i(0, 0))
	for x in range(31, 44):
		structs.set_cell(Vector2i(x, -5), 0, Vector2i(1, 0))
	structs.set_cell(Vector2i(44, -5), 0, Vector2i(2, 0))
	# Escada visual (tile 1:1) nas linhas -4..-1, coluna 31.
	for y in range(-4, 0):
		structs.set_cell(Vector2i(31, y), 0, Vector2i(1, 1))


func _rect(cells: Array[Vector2i], x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells.append(Vector2i(x, y))


func _build_ladder() -> void:
	# Área da escada: do chão (y = 16) até 6 px acima do topo da passarela (-144).
	var ladder: Node2D = load("res://scenes/objects/ladder.tscn").instantiate()
	ladder.name = "Ladder"
	# A cena da escada vai de y = -128 a 0 (escala em y); ajusta para 16 .. -150.
	ladder.position = Vector2(31 * TILE + 16, 16)
	ladder.scale = Vector2(1, 166.0 / 128.0)
	_own(ladder, root)


func _build_props() -> void:
	var decor := Node2D.new()
	decor.name = "Props"
	_own(decor, root)
	# [arquivo, tile x, deslocamento x em px]
	var list := [
		["barrel", 6, 0], ["cardboard_box", 20, 0], ["dumpster", 24, 0],
		["trash_bags", 47, 0], ["crates", 66, 0], ["ac_unit", 72, 0],
		["tire", 80, 0],
	]
	for p in list:
		_prop(decor, p[0], Vector2(p[1] * TILE + p[2], 16))
	# Em cima do degrau (topo em y = -48).
	_prop(decor, "pipes_cable", Vector2(104 * TILE, -48))
	_prop(decor, "crates", Vector2(116 * TILE, -48))


func _prop(parent: Node, file: String, base: Vector2) -> void:
	var s := Sprite2D.new()
	s.name = file.to_pascal_case()
	s.texture = load("res://assets/props/slums/%s.png" % file)
	s.centered = false
	s.position = base - Vector2(s.texture.get_width() / 2.0, s.texture.get_height())
	_own(s, parent)


func _build_signs() -> void:
	var holder := Node2D.new()
	holder.name = "NeonSigns"
	_own(holder, root)
	# [nome, tile x, y do centro, flicker?]
	var list := [
		["neon_RAMEN", 10, -170], ["neon_ramen_bowl", 14, -190],
		["neon_HOTEL_vertical", 26, -200], ["neon_BAR", 40, -220],
		["neon_OPEN_24H", 62, -230], ["neon_REPAIR", 96, -190],
		["neon_hanging_sign_arrow", 108, -250],
	]
	for e in list:
		var path := "res://assets/neon/slums/%s_flicker_2f.png" % e[0]
		var has_flicker := ResourceLoader.exists(path)
		var sign_node := NeonSign.new()
		sign_node.name = (e[0] as String).to_pascal_case()
		sign_node.texture = load(path if has_flicker else "res://assets/neon/slums/%s.png" % e[0])
		if has_flicker:
			sign_node.hframes = 2
		else:
			sign_node.flicker = false
		sign_node.position = Vector2(e[1] * TILE, e[2])
		_own(sign_node, holder)


func _build_player() -> void:
	var p: Node2D = load("res://scenes/player/eduardo.tscn").instantiate()
	p.name = "Eduardo"
	p.position = Vector2(3 * TILE, 16)
	_own(p, root)