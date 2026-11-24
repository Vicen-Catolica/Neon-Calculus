extends "res://tools/stage_builder_base.gd"
## Monta a Fase 4 (Núcleo Quântico). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_core_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## GREYBOX (etapas 3–4 do docs/PLANO_FASE_4.md): a aproximação ao Domo (A–D).
## B tem pontes de luz (hack / temporizada) sobre o abismo; cair volta à última
## plataforma com dano. O Duelo (E) vem nas etapas 5–6.
## Arte: tileset do tema "core" (tools/gen_rnd_tiles.py core) e o fundo do vazio
## do PixelLab (tools/gen_core_art.py).
##
## Percurso, da esquerda para a direita:
##   A  chegada do elevador executivo (diálogo)
##   B  vazio com plataformas flutuantes ligadas por pontes de luz
##   C  galeria dos servidores massivos: 2 Unidades Lógicas, lasers, domo
##   D  antecâmara do Domo de Controle Neural (porta = saída)

const GROUND_TS := "res://assets/tilesets/core/core_ground.tres"
const OUT_LEVEL := "res://scenes/levels/core/core_stage4.tscn"
## A porta do Domo leva à arena do Duelo de Paradoxo.
const NEXT_STAGE := "res://scenes/levels/core/core_duel.tscn"

const GROUND_TINT := Color.WHITE
const WALL_TINT := Color(0.78, 0.8, 0.86)
const HALL_CEILING_Y := -368.0
const DOOR_X := 126 * 32 - 70   # porta do Domo (saída), encostada na parede direita

const GROUND_RECTS := [
	[-12, 0, 12, 12],     # A: plataforma de chegada
	[20, 0, 27, 2],       # B: plataforma flutuante 1
	[35, 0, 42, 2],       # B: plataforma flutuante 2
	[50, 0, 126, 12],     # C + D
]

const WALL_RECTS := [
	[-12, -24, -7, -1],   # parede esquerda (elevador)
	[50, -16, 51, -6],    # C: verga da entrada da galeria (vão de 192 px)
	[52, -16, 126, -12],  # C + D: teto da galeria (face de baixo em -368)
	[126, -24, 131, 0],   # parede direita (Domo), até o chão
]

## Passarelas (mão única): [x0, x1, linha, vigas de apoio?]
const CATWALKS := [
	[58, 97, -5, false],  # C: mezanino dos servidores (y = -144)
]

## Pontes de luz: [x0, x1 (células), modo, fase]. A 1ª e a 3ª só por hack
## (a 3ª sob a câmera); a do meio liga e desliga sozinha.
const BRIDGES := [
	[13, 19, LightBridge.Mode.HACK, 0.0],
	[28, 34, LightBridge.Mode.TIMED, 0.0],
	[43, 49, LightBridge.Mode.HACK, 0.0],
]

## Pontos de retorno de quem cai no abismo (ponta direita de cada plataforma).
const RESPAWNS := [Vector2(360, 16), Vector2(840, 16), Vector2(1320, 16), Vector2(1640, 16)]

## Escadas: [célula x, linha do topo, y da base]
const LADDERS := [
	[58, -5, 16.0],       # C: chão -> mezanino
	[97, -5, 16.0],
]

const SHOW_ZONE_LABELS := false
const ZONES := [
	["A // ELEVADOR EXECUTIVO", Vector2(-180, -330)],
	["B // PONTES DE LUZ (hackeie o emissor)", Vector2(560, -330)],
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
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	# Piso em profundidade (falso 3D) como nas outras fases (tools/gen_floor_band.py core).
	_floor_band(lvl, _surface_runs(GROUND_RECTS), "res://assets/tilesets/core/floor_band.png")
	_structures(lvl, CATWALKS)
	_catwalk_band(lvl, CATWALKS)
	_ladders(lvl, LADDERS)
	_add_bridges(lvl)
	_add_abyss(lvl)
	_add_servers(lvl)
	_add_lasers(lvl)
	_add_cameras(lvl)
	_add_guards(lvl)
	_data_terminals(lvl, [
		["core_01_foundation", Vector2(200, 16)],      # A: chegada
		["core_02_sine_log", Vector2(1230, 16)],       # B: plataforma flutuante 2
		["core_03_manifesto", Vector2(2700, -144)],    # C: mezanino dos servidores
		["core_04_paradox", Vector2(3700, 16)],        # D: antecâmara
	])
	_add_exit(lvl)
	if SHOW_ZONE_LABELS:
		_add_zone_labels(lvl)
	_dialogue_trigger(lvl, "core_elevator", Vector2(64, 16))
	# A Axioma fala pelos alto-falantes no primeiro alarme do Núcleo.
	var ad := Node.new()
	ad.name = "AlarmDialogue"
	ad.set_script(load("res://scripts/core/alarm_dialogue.gd"))
	ad.set("dialogue_id", "core_first_alarm")
	lvl.add_child(ad)
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
	# O vazio do topo da torre (PixelLab), em parallax: geometrias e torres de
	# servidores ao longe, mais escuro para cima.
	var par := Parallax2D.new()
	par.name = "BackgroundFar"
	par.scroll_scale = Vector2(0.4, 0.9)
	par.repeat_size = Vector2(1536, 0)
	par.repeat_times = 6
	lvl.add_child(par)
	var tex: Texture2D = load("res://assets/backgrounds/core/bg_core_seamless.png")
	var h := tex.get_height()
	var tints := [Color(1, 1, 1), Color(0.6, 0.6, 0.68), Color(0.4, 0.4, 0.46)]
	for k in range(tints.size() - 1, -1, -1):
		var s := Sprite2D.new()
		s.name = "Void%d" % k
		s.texture = tex
		s.centered = false
		s.modulate = tints[k]
		s.flip_h = k % 2 == 1
		s.position = Vector2(-768, 120 - h * (k + 1))
		par.add_child(s)


# --- B: pontes de luz e abismo -------------------------------------------------

func _add_bridges(lvl: Node) -> void:
	var holder := _holder(lvl, "LightBridges")
	for b in BRIDGES:
		# Encosta 8 px em cada plataforma: sem frestas para os pés escorregarem.
		var x0: float = b[0] * T - 8.0
		var w: float = (b[1] - b[0] + 1) * T + 16.0
		var br := _instance("res://scenes/objects/light_bridge.tscn", "Bridge%d" % b[0], Vector2(x0, 16))
		br.set("width", w)
		br.set("mode", b[2])
		br.set("phase", b[3])
		holder.add_child(br)


## Faixa sob as plataformas de B: quem cai volta à última plataforma (com dano).
func _add_abyss(lvl: Node) -> void:
	var zone := Area2D.new()
	zone.name = "Abyss"
	zone.set_script(load("res://scripts/core/abyss_zone.gd"))
	var rect := Rect2(12 * T, 220, (50 - 12) * T, 200)
	zone.position = rect.get_center()
	zone.add_child(_rect_shape(rect.size))
	var pts: Array[Vector2] = []
	for r in RESPAWNS:
		pts.append(r)
	zone.set("respawn_points", pts)
	lvl.add_child(zone)


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
		# Emissor encostado na face de baixo do mezanino (antes sobrava um vão de 8 px).
		laser.set("height", 16.0 + 144.0)
		laser.set("mode", LaserBarrier.Mode.TIMED)
		laser.set("phase", l[1])
		holder.add_child(laser)


func _add_cameras(lvl: Node) -> void:
	var holder := _holder(lvl, "Cameras")
	# B: vigia as pontes do alto da plataforma 2.
	# (em cima da plataforma: a haste desce até ela)
	_camera(holder, false, "BridgeCamera", Vector2(42 * T - 24, -60),
		{"facing_left": true, "sweep_min_deg": 10.0, "sweep_max_deg": 50.0, "vision_range": 520.0})
	_camera(holder, true, "GalleryDome", Vector2(2550, HALL_CEILING_Y + 24),
		{"sweep_min_deg": 55.0, "sweep_max_deg": 125.0, "vision_range": 400.0, "fov_deg": 30.0})


func _add_guards(lvl: Node) -> void:
	_guards(lvl, [
		["cyborg", 2500.0, 16.0, 1750.0, 3300.0],    # C: chão
		["cyborg", 2500.0, -144.0, 1950.0, 3050.0],  # C: mezanino
	])


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, Vector2(DOOR_X, 16), Vector2(80, 120))
	exit.name = "LevelExit"
	exit.set("require_standing", true)
	# Porta do Domo: as portas do elevador executivo, tingidas do laranja da Axioma.
	var door := _prop(lvl, RND_PROPS + "exec_elevator.png", DOOR_X, 16.0, "DomeDoor")
	door.modulate = Color(1.0, 0.62, 0.45)
	var sign := Label.new()
	sign.name = "DomeSign"
	sign.text = "DOMO DE CONTROLE NEURAL"
	sign.position = Vector2(DOOR_X - 150, -250)
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
