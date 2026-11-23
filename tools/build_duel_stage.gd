extends "res://tools/stage_builder_base.gd"
## Monta a arena do Duelo de Paradoxo (Domo de Controle Neural, Fase 4). Uso:
##   godot --headless --path . res://tools/build_duel_stage.tscn
## Cena própria: o checkpoint do andar fica logo antes do chefe (game over aqui
## volta ao começo do Duelo, não ao elevador). Câmera com zoom 1: a arena cabe
## inteira na tela (~1920×1080).
##
## Etapas 5–6 do docs/PLANO_FASE_4.md: arena, núcleo (hackeável no fim: o
## Paradoxo), 3 Nodos de Vigilância e o controlador (scripts/duel/paradox_duel.gd),
## que cria os ataques.
##
## Arena: chão inteiro; plataforma esquerda e direita (y = -272) com um nó cada;
## plataforma do meio (y = -464) leva à plataforma de cima (y = -624), sobre o
## núcleo, com o terceiro nó.

const GROUND_TS := "res://assets/tilesets/core/core_ground.tres"
const OUT_LEVEL := "res://scenes/levels/core/core_duel.tscn"
const GROUND_TINT := Color.WHITE
const WALL_TINT := Color(0.7, 0.72, 0.8)
const CORE_POS := Vector2(960, -400)

const GROUND_RECTS := [
	[-6, 0, 66, 12],
]

const WALL_RECTS := [
	[-6, -40, -1, -1],    # parede esquerda
	[60, -40, 66, -1],    # parede direita
	[-6, -44, 66, -35],   # teto (face de baixo em -1104)
]

const CATWALKS := [
	[5, 13, -9, false],    # esquerda (y = -272)
	[47, 55, -9, false],   # direita
	[13, 24, -15, false],  # meio (y = -464)
	[24, 36, -20, false],  # topo, sobre o núcleo (y = -624)
]

const LADDERS := [
	[5, -9, 16.0],         # chão -> esquerda
	[55, -9, 16.0],        # chão -> direita
	[13, -15, -272.0],     # esquerda -> meio
	[24, -20, -464.0],     # meio -> topo
]

## [nome, posição (chão), subtópico do nível 5]
const NODES := [
	["NodeLeft", Vector2(300, -272), 0],
	["NodeRight", Vector2(1660, -272), 0],
	["NodeTop", Vector2(1060, -624), 1],
]


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("CoreDuel", 4, -16, 60 * T + 16, -1104, 60)
	lvl.set("camera_zoom", 1.0)
	lvl.set("max_security_rect", Rect2(-400, -1400, 60 * T + 800, 1600))
	_add_background(lvl)
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	# Piso em profundidade (falso 3D) como nas outras fases (tools/gen_floor_band.py core).
	_floor_band(lvl, _surface_runs(GROUND_RECTS), "res://assets/tilesets/core/floor_band.png")
	_structures(lvl, CATWALKS)
	_catwalk_band(lvl, CATWALKS)
	_ladders(lvl, LADDERS)
	var core := Node2D.new()
	core.name = "AxiomaCore"
	core.set_script(load("res://scripts/duel/axioma_core.gd"))
	core.position = CORE_POS
	var ch := _hackable("NÚCLEO DA AXIOMA", Vector2.ZERO)
	ch.kind = Hackable.Kind.NODE
	ch.paradox = true
	ch.abortable = false
	core.add_child(ch)
	lvl.add_child(core)
	var nodes := _holder(lvl, "SurveillanceNodes")
	for n in NODES:
		var node := _instance("res://scenes/objects/surveillance_node.tscn", n[0], n[1])
		node.set("sub_topic", n[2])
		nodes.add_child(node)
	var duel := Node.new()
	duel.name = "ParadoxDuel"
	duel.set_script(load("res://scripts/duel/paradox_duel.gd"))
	lvl.add_child(duel)
	# Confronto com a Axioma ao entrar no Domo (o Duelo espera ele terminar).
	_dialogue_trigger(lvl, "duel_confront", Vector2(120, 16))
	_player_and_ui(lvl, Vector2(120, 16))
	return lvl


func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.015, 0.02, 0.04)
	bg.position = Vector2(-600, -1600)
	bg.size = Vector2(3200, 2000)
	lvl.add_child(bg)
	# O Domo (PixelLab): túnel de anéis com o "olho" atrás do núcleo (3×, sem filtro).
	var dome_bg := Sprite2D.new()
	dome_bg.name = "DomeArt"
	dome_bg.texture = load("res://assets/backgrounds/core/bg_dome.png")
	dome_bg.scale = Vector2(3, 3)
	dome_bg.position = CORE_POS + Vector2(0, -40)
	dome_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lvl.add_child(dome_bg)
	# Grade fina e anéis concêntricos atrás do núcleo: o Domo.
	var dome := Node2D.new()
	dome.name = "DomeLines"
	lvl.add_child(dome)
	for i in 6:
		var ring := Line2D.new()
		ring.name = "Ring%d" % i
		var pts := PackedVector2Array()
		var r := 220.0 + i * 140.0
		for k in 65:
			pts.append(CORE_POS + Vector2.from_angle(TAU * k / 64.0) * r)
		ring.points = pts
		ring.width = 1.0
		ring.default_color = Color(1.0, 0.42, 0.1, 0.12 - i * 0.015)
		dome.add_child(ring)
