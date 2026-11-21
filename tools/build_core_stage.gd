extends "res://tools/stage_builder_base.gd"
## Monta a Fase 4 (Núcleo Quântico). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_core_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## GREYBOX (etapa 3 do docs/PLANO_FASE_4.md): a aproximação ao Domo (A–D) com as
## mecânicas que já existem. As pontes de luz (etapa 4) ainda são passarelas
## comuns marcadas em "BridgeSlots"; embaixo do abismo há um piso de segurança
## com escadas (vira queda com retorno na etapa 4). O Duelo (E) vem nas etapas 5–6.
## Arte provisória: tiles do P&D escurecidos, geometrias em Polygon2D.
##
## Percurso, da esquerda para a direita:
##   A  chegada do elevador executivo (diálogo)
##   B  vazio com plataformas flutuantes ligadas por pontes de luz
##   C  galeria dos servidores massivos: 2 Unidades Lógicas, lasers, domo
##   D  antecâmara do Domo de Controle Neural (porta = saída)

const GROUND_TS := "res://assets/tilesets/rnd/rnd_ground.tres"
const OUT_LEVEL := "res://scenes/levels/core/core_stage4.tscn"
## A porta do Domo leva ao Duelo de Paradoxo (etapas 5–6).
const NEXT_STAGE := ""

const GROUND_TINT := Color(0.42, 0.46, 0.56)
const WALL_TINT := Color(0.3, 0.33, 0.42)
const HALL_CEILING_Y := -368.0
const CATCH_Y := 336.0          # piso de segurança sob o abismo
const DOOR_X := 126 * 32 - 24   # porta do Domo (saída)

const GROUND_RECTS := [
	[-12, 0, 12, 12],     # A: plataforma de chegada
	[20, 0, 27, 2],       # B: plataforma flutuante 1
	[35, 0, 42, 2],       # B: plataforma flutuante 2
	[50, 0, 126, 12],     # C + D
	[13, 10, 49, 14],     # piso de segurança sob o abismo (greybox)
]

const WALL_RECTS := [
	[-12, -24, -7, -1],   # parede esquerda (elevador)
	[50, -16, 51, -6],    # C: verga da entrada da galeria (vão de 192 px)
	[52, -16, 126, -12],  # C + D: teto da galeria (face de baixo em -368)
	[126, -24, 131, -1],  # parede direita (Domo)
]

## Passarelas (mão única): [x0, x1, linha, vigas de apoio?]
const CATWALKS := [
	[58, 97, -5, false],  # C: mezanino dos servidores (y = -144)
]

## Pontes de luz da etapa 4 (por enquanto passarelas comuns): [x0, x1, linha]
const BRIDGES := [
	[13, 19, 0],
	[28, 34, 0],
	[43, 49, 0],
]

## Escadas: [célula x, linha do topo, y da base]
const LADDERS := [
	[58, -5, 16.0],       # C: chão -> mezanino
	[97, -5, 16.0],
	[16, 0, CATCH_Y],     # abismo -> pontes (greybox)
	[31, 0, CATCH_Y],
	[46, 0, CATCH_Y],
]

const SHOW_ZONE_LABELS := true
const ZONES := [
	["A // ELEVADOR EXECUTIVO", Vector2(-180, -330)],
	["B // PONTES DE LUZ", Vector2(560, -330)],
	["C // GALERIA DOS SERVIDORES", Vector2(1700, -330)],
	["D // ANTECÂMARA DO DOMO", Vector2(3420, -330)],
]

const RND_PROPS := "res://assets/props/rnd/"


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("CoreStage4", 4, -208, 131 * T, -900, 420)
	# O Núcleo inteiro é segurança máxima (hacks com 80% do tempo).
	lvl.set("max_security_rect", Rect2(-400, -1200, 131 * T + 800, 1800))
	_add_background(lvl)
	var all_walks: Array = CATWALKS.duplicate()
	for b in BRIDGES:
		all_walks.append([b[0], b[1], b[2], false])
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	_structures(lvl, all_walks)
	_catwalk_band(lvl, CATWALKS)
	_ladders(lvl, LADDERS)
	_add_bridge_slots(lvl)
	_add_servers(lvl)
	_add_lasers(lvl)
	_add_cameras(lvl)
	_add_guards(lvl)
	_add_exit(lvl)
	if SHOW_ZONE_LABELS:
		_add_zone_labels(lvl)
	_dialogue_trigger(lvl, "core_elevator", Vector2(64, 16))
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


# --- Fundo: vazio escuro com geometrias flutuando ------------------------------

func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.025, 0.05)
	bg.position = Vector2(-1200, -2000)
	bg.size = Vector2(7000, 3000)
	lvl.add_child(bg)
	var par := Parallax2D.new()
	par.name = "Geometry"
	par.scroll_scale = Vector2(0.5, 0.8)
	lvl.add_child(par)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 26:
		var poly := Line2D.new()
		poly.name = "Shape%d" % i
		var r := rng.randf_range(18.0, 60.0)
		var sides: int = [3, 4, 6][i % 3]
		var pts := PackedVector2Array()
		var rot := rng.randf() * TAU
		for k in sides + 1:
			pts.append(Vector2.from_angle(rot + TAU * k / sides) * r)
		poly.points = pts
		poly.width = 1.5
		poly.default_color = Color(1.0, 0.45, 0.12, 0.35) if i % 4 == 0 else Color(0.0, 0.9, 1.0, 0.22)
		poly.position = Vector2(rng.randf_range(-300, 4300), rng.randf_range(-800, 300))
		par.add_child(poly)


# --- B: pontes de luz (marcadores) --------------------------------------------

func _add_bridge_slots(lvl: Node) -> void:
	var holder := _holder(lvl, "BridgeSlots")
	for b in BRIDGES:
		var m := Marker2D.new()
		m.name = "Bridge%d" % b[0]
		m.position = Vector2(b[0] * T, _y(b[2]))
		m.set_meta("width", (b[1] - b[0] + 1) * T)
		holder.add_child(m)
		var glow := ColorRect.new()
		glow.name = "Glow"
		glow.color = Color(0.0, 0.9, 1.0, 0.25)
		glow.position = Vector2(0, -2)
		glow.size = Vector2((b[1] - b[0] + 1) * T, 4)
		m.add_child(glow)


# --- C: servidores massivos (cobertura escura) ---------------------------------

func _add_servers(lvl: Node) -> void:
	var props := _holder(lvl, "Servers")
	var spots := _holder(lvl, "HideSpots")
	var tex: Texture2D = load(RND_PROPS + "server_white.png")
	# [x, chão]: servidores em escala 2 (≈ 150 px), todos no escuro.
	var list := [[1900.0, 16.0], [2400.0, 16.0], [2750.0, 16.0], [3200.0, 16.0], [2300.0, -144.0]]
	for s in list:
		var spr := Sprite2D.new()
		spr.name = "Server%d_%d" % [int(s[0]), int(-s[1])]
		spr.texture = tex
		spr.scale = Vector2(2, 2)
		spr.modulate = Color(0.7, 0.75, 0.85)
		spr.position = Vector2(s[0], s[1] - tex.get_height() - 4.0)
		props.add_child(spr)
		_hide_spot(spots, s[0], s[1], 70, "Hide_server_%d_%d" % [int(s[0]), int(-s[1])])


func _add_lasers(lvl: Node) -> void:
	var holder := _holder(lvl, "Lasers")
	# Só no chão da galeria (até o mezanino); o mezanino é a outra rota.
	for l in [[2150.0, 0.0], [2950.0, 1.8]]:
		var laser := _instance("res://scenes/objects/laser_barrier.tscn", "Laser%d" % int(l[0]), Vector2(l[0], 16))
		laser.set("height", 16.0 + 144.0 - 8.0)
		laser.set("mode", LaserBarrier.Mode.TIMED)
		laser.set("phase", l[1])
		holder.add_child(laser)


func _add_cameras(lvl: Node) -> void:
	var holder := _holder(lvl, "Cameras")
	# B: vigia as pontes do alto da plataforma 2.
	_camera(holder, false, "BridgeCamera", Vector2(42 * T + 10, -60),
		{"facing_left": true, "sweep_min_deg": 10.0, "sweep_max_deg": 50.0, "vision_range": 520.0})
	_camera(holder, true, "GalleryDome", Vector2(2550, HALL_CEILING_Y + 24),
		{"sweep_min_deg": 55.0, "sweep_max_deg": 125.0, "vision_range": 400.0, "fov_deg": 30.0})


func _add_guards(lvl: Node) -> void:
	_guards(lvl, [
		["cyborg", 2500.0, 16.0, 1750.0, 3300.0],    # C: chão
		["cyborg", 2500.0, -144.0, 1950.0, 3050.0],  # C: mezanino
	])


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, Vector2(DOOR_X, 16))
	exit.name = "LevelExit"
	var door := ColorRect.new()
	door.name = "DomeDoor"
	door.color = Color(1.0, 0.42, 0.1, 0.25)
	door.position = Vector2(DOOR_X - 40, -176)
	door.size = Vector2(80, 192)
	lvl.add_child(door)
	var sign := Label.new()
	sign.name = "DomeSign"
	sign.text = "DOMO DE CONTROLE NEURAL\n(Duelo de Paradoxo em construção)"
	sign.position = Vector2(DOOR_X - 160, -260)
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color("FF6A1A"))
	lvl.add_child(sign)


func _add_zone_labels(lvl: Node) -> void:
	var holder := _holder(lvl, "ZoneLabels")
	for z in ZONES:
		var l := Label.new()
		l.name = "Zone_" + String(z[0]).left(1)
		l.text = z[0]
		l.position = z[1]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3, 0.6))
		holder.add_child(l)
