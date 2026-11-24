extends "res://tools/stage_builder_base.gd"
## Monta a Fase 3 (Setor de Administração e P&D). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_rnd_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## Layout da etapa 3 do docs/PLANO_FASE_3.md, com a arte da etapa 8: tileset de
## tools/gen_rnd_tiles.py, fundo/props/Vance/elevador do PixelLab via
## tools/gen_rnd_art.py; a luz do teto vem de tools/gen_rnd_placeholders.py. Lasers (etapa 4), ciborgues (etapa 5) e a cela
## do Dr. Vance (etapa 6) prontos.
##
## Percurso, da esquerda para a direita (teto em y = -368):
##   A  doca do elevador de carga + recepção: luz demais, apague para se esconder
##   B  escritórios open-space: chão com cubículos + mezanino
##   C  corredor de segurança (teto baixo) com 3 lasers, ou o duto por cima
##   D  laboratórios de P&D: ciborgue no chão, mezanino com o Lab 07; lockdown
##   E  átrio do elevador executivo: 6 andares de passarela até a saída

const GROUND_TS := "res://assets/tilesets/rnd/rnd_ground.tres"
const OUT_LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"
## Fase 4 (Núcleo Quântico) ainda não existe: a saída fica desligada até lá.
const NEXT_STAGE := ""

const GROUND_TINT := Color.WHITE
## Paredes/teto um pouco mais escuros que o chão, para não lerem como piso.
const WALL_TINT := Color(0.72, 0.76, 0.82)
const CEILING_Y := -368.0     # face de baixo do teto principal
const CORRIDOR_Y := -176.0    # face de baixo do teto do corredor C
const DUCT_Y := -272.0        # piso do duto sobre o corredor (vão de 96 px)
const EXIT_POS := Vector2(5300, -752)

const GROUND_RECTS := [
	[-12, 0, 175, 12],
]

const WALL_RECTS := [
	[-12, -16, -7, -1],    # parede esquerda (doca do elevador de carga)
	[-8, -16, 78, -12],    # teto principal (face de baixo em -368)...
	[81, -16, 155, -12],   # ...com uma chaminé nas colunas 79–80 (boca do duto)
	[78, -21, 81, -17],    # tampa da chaminé: dá para ficar em pé no topo da escada
	[80, -9, 110, -6],     # C: teto do corredor; em cima dele, o duto (96 px)
	[151, -11, 155, -5],   # verga da porta D -> E (vão de 160 px)
	[151, -30, 155, -17],  # parede esquerda do átrio, acima do teto
	[170, -30, 175, -1],   # parede direita do átrio
	[151, -34, 175, -31],  # tampa do átrio
]

## Passarelas (mão única): [x0, x1, linha, vigas de apoio?]
const CATWALKS := [
	[40, 74, -5, false],     # B: mezanino dos escritórios (y = -144)
	[116, 146, -5, false],   # D: mezanino dos laboratórios (Lab 07)
	[78, 79, -9, false],     # C: patamar da escada na boca do duto (y = -272)
	# E: átrio, um andar a cada 128 px
	[156, 169, -4, false],
	[156, 169, -8, false],
	[156, 169, -12, false],
	[156, 169, -16, false],
	[156, 169, -20, false],
	[156, 169, -24, false],  # topo: elevador executivo (y = -752)
]

## Escadas: [célula x, linha do topo, y da base]
const LADDERS := [
	[41, -5, 16.0],          # B: chão -> mezanino
	[73, -5, 16.0],
	[79, -9, 16.0],          # C: chão -> duto (sobe junto à parede do corredor)
	[111, -9, 16.0],         # C: duto -> chão de D
	[117, -5, 16.0],         # D: chão -> mezanino
	[145, -5, 16.0],
	[167, -4, 16.0],         # E: zigue-zague até o topo
	[158, -8, -112.0],
	[167, -12, -240.0],
	[158, -16, -368.0],
	[167, -20, -496.0],
	[158, -24, -624.0],
]

## Placas com o nome de cada trecho (playtest do greybox; desligar com a arte final).
const SHOW_ZONE_LABELS := false
const ZONES := [
	["A // DOCA + RECEPÇÃO", Vector2(-180, -330)],
	["B // ESCRITÓRIOS", Vector2(1140, -330)],
	["C // CORREDOR DE SEGURANÇA (duto por cima)", Vector2(2580, -330)],
	["D // LABORATÓRIOS P&D — LAB 07 no mezanino", Vector2(3640, -330)],
	["E // ÁTRIO", Vector2(4995, -860)],
]

const PROP_DIR := "res://assets/props/rnd/"
const LIGHT_TEX := "res://assets/props/rnd/ceiling_light_flicker_2f.png"


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("RndStage3", 3, -208, 170 * T + 16, -1100, 300)
	# Laboratórios (D) e átrio (E): segurança máxima, hacks com 80% do tempo.
	lvl.set("max_security_rect", Rect2(3600, -1100, 170 * T + 16 - 3600, 1400))
	_add_background(lvl)
	_add_tiles(lvl)
	_ladders(lvl, LADDERS)
	_add_props(lvl)
	_add_lights(lvl)
	_add_terminals(lvl)
	_add_kiosk_and_doors(lvl)
	_add_lasers(lvl)
	_add_lab07(lvl)
	_add_cameras(lvl)
	_add_guards(lvl)
	_add_exit(lvl)
	if SHOW_ZONE_LABELS:
		_add_zone_labels(lvl)
	# Diálogo de elevador (GDD §9): SINE e Eduardo assim que a porta abre.
	_dialogue_trigger(lvl, "rnd_elevator", Vector2(64, 16))
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


# --- Fundo e terreno ---------------------------------------------------------

func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.07, 0.09, 0.12)
	bg.position = Vector2(-1200, -1800)
	bg.size = Vector2(7800, 2400)
	lvl.add_child(bg)
	# Corredor de vidro com a cidade lá fora (PixelLab), em parallax; empilhado
	# até o topo do átrio e cada vez mais escuro para cima.
	var par := Parallax2D.new()
	par.name = "BackgroundFar"
	par.scroll_scale = Vector2(0.4, 1.0)
	par.repeat_size = Vector2(1536, 0)
	par.repeat_times = 8
	lvl.add_child(par)
	var tex: Texture2D = load("res://assets/backgrounds/rnd/bg_rnd_seamless.png")
	var h := tex.get_height()
	var tints := [Color(1, 1, 1), Color(0.7, 0.72, 0.76), Color(0.5, 0.52, 0.56)]
	for k in range(tints.size() - 1, -1, -1):
		var hall := Sprite2D.new()
		hall.name = "Hall%d" % k
		hall.texture = tex
		hall.centered = false
		hall.modulate = tints[k]
		hall.flip_h = k % 2 == 1
		hall.position = Vector2(-768, 40 - h * (k + 1))
		par.add_child(hall)
	# Faixa de luz no teto de A–D: o andar corporativo é claro e vigiado
	# (interrompida na chaminé da boca do duto).
	for span in [[-208.0, 2500.0], [2610.0, 151.0 * T]]:
		var strip := ColorRect.new()
		strip.name = "CeilingLight%d" % int(span[0])
		strip.color = Color(0.75, 0.95, 1.0, 0.35)
		strip.position = Vector2(span[0], CEILING_Y)
		strip.size = Vector2(span[1] - span[0], 6)
		lvl.add_child(strip)


func _add_tiles(lvl: Node) -> void:
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	_structures(lvl, CATWALKS)
	_catwalk_band(lvl, CATWALKS)


# --- Props e esconderijos ----------------------------------------------------

func _add_props(lvl: Node) -> void:
	var props := _holder(lvl, "Props")
	var spots := _holder(lvl, "HideSpots")
	# [textura, x, chão, esconderijo?, largura]
	var list := [
		["plant", -120.0, 16.0, false, 0],              # A: doca
		["water_cooler", 250.0, 16.0, false, 0],
		["reception_counter", 700.0, 16.0, true, 72],   # A: balcão, sob a luz
		["plant", 960.0, 16.0, false, 0],
		["cubicle", 1450.0, 16.0, true, 72],            # B: cubículo no escuro
		["cubicle", 1800.0, 16.0, true, 72],            # B: sob a luz
		["cubicle", 2150.0, 16.0, true, 72],            # B: sob a luz
		["monitor_stand", 1560.0, -144.0, false, 0],    # B: mezanino
		["filing_cabinet", 2000.0, -144.0, true, 44],   # B: mezanino
		["plant", 2420.0, 16.0, false, 0],
		["server_white", 3680.0, -144.0, false, 0],     # D: mezanino
		["lab_bench", 3800.0, 16.0, true, 72],          # D: bancada no escuro
		["sample_tank", 4050.0, 16.0, false, 0],
		["lab_bench", 4420.0, 16.0, true, 72],          # D: sob a luz
		["sample_tank", 4620.0, 16.0, false, 0],
		["filing_cabinet", 3900.0, -144.0, true, 44],   # D: mezanino
		["server_white", 4720.0, -144.0, false, 0],
		["filing_cabinet", 5100.0, -240.0, true, 44],   # E: no meio do átrio
		["water_cooler", 5360.0, -496.0, false, 0],
	]
	var n := 0
	for p in list:
		n += 1
		_prop(props, PROP_DIR + p[0] + ".png", p[1], p[2], "%s_%d" % [p[0], n])
		if p[3]:
			_hide_spot(spots, p[1], p[2], p[4], "Hide_%s_%d" % [p[0], n])
	# E: elevador executivo no topo do átrio (entrar nele = saída da fase)
	_prop(props, PROP_DIR + "exec_elevator.png", EXIT_POS.x, EXIT_POS.y + 12.0, "ExecElevator")


## Painéis de luz do teto: acesos, impedem o esconderijo embaixo deles.
## Hackeáveis (LUZ): apagam por 25 s. [x, chão, largura da luz, teto]
func _add_lights(lvl: Node) -> void:
	var holder := _holder(lvl, "CeilingLights")
	var list := [
		[700.0, 16.0, 260.0, CEILING_Y],     # A: balcão da recepção
		[1800.0, 16.0, 220.0, CEILING_Y],    # B: cubículos do meio
		[2150.0, 16.0, 220.0, CEILING_Y],
		[2000.0, -144.0, 160.0, CEILING_Y],  # B: arquivo do mezanino
		[4420.0, 16.0, 240.0, CEILING_Y],    # D: bancada da direita
		[3900.0, -144.0, 160.0, CEILING_Y],  # D: arquivo do mezanino (Lab 07)
	]
	for l in list:
		var ground: float = l[1]
		var ceiling: float = l[3]
		var h := ground - ceiling - 10.0
		var s := _neon(holder, LIGHT_TEX, Vector2(l[0], ceiling + 7.0), true,
			Vector2(l[2], minf(h, 200.0)), ground, Color(0.8, 0.97, 1.0, 0.08))
		s.name = "Light_%d_%d" % [int(l[0]), int(-ground)]
		s.set("flicker", false)
		(s.get_node("Hackable") as Hackable).display_name = "LUZ DO TETO"


# --- Objetos interativos -----------------------------------------------------

func _add_terminals(lvl: Node) -> void:
	_data_terminals(lvl, [
		["rnd_01_sine", Vector2(180, 16)],              # A: doca
		["rnd_02_memo", Vector2(2300, -144)],           # B: mezanino
		["rnd_03_trials", Vector2(3050, DUCT_Y)],       # C: só quem vai pelo duto acha
		["rnd_04_kessler", Vector2(3700, 16)],          # D: entrada dos laboratórios
		["rnd_05_logic_units", Vector2(5150, -752)],    # E: topo, ao lado do elevador
	])


func _add_kiosk_and_doors(lvl: Node) -> void:
	# B: quiosque/monitor corporativo — distrai os agentes do chão.
	lvl.add_child(_instance("res://scenes/objects/axioma_kiosk.tscn", "AxiomaKiosk", Vector2(1650, 16)))
	# D -> E: porta biométrica do átrio.
	lvl.add_child(_instance("res://scenes/objects/security_door.tscn", "SecurityDoor", Vector2(151 * T + 40, 16)))
	# Entrada de D: aberta; só fecha no lockdown (não é hackeável).
	var shutter := _instance("res://scenes/objects/security_door.tscn", "LockdownShutterWest", Vector2(3600, 16))
	shutter.set("start_open", true)
	shutter.set("hackable_enabled", false)
	lvl.add_child(shutter)
	_add_lockdown(lvl)


## D: alarme com o jogador nos laboratórios fecha as portas; 20 s para hackear a saída.
func _add_lockdown(lvl: Node) -> void:
	var room := Rect2(3620, CEILING_Y, 151 * T + 30 - 3620, 16 - CEILING_Y)
	var zone := Area2D.new()
	zone.name = "LabLockdown"
	zone.set_script(load("res://scripts/core/lockdown_zone.gd"))
	zone.position = room.get_center()
	zone.add_child(_rect_shape(room.size))
	zone.set("door_paths", [NodePath("../LockdownShutterWest")] as Array[NodePath])
	zone.set("exit_door_path", NodePath("../SecurityDoor"))
	zone.set("countdown", 20.0)
	zone.set("tint_rect", room)
	zone.set("axioma_message", "Intrusão no Setor de P&D. Eduardo: sua variância já foi calculada.\nLaboratórios isolados. Unidades Lógicas a caminho.")
	lvl.add_child(zone)


## D: Laboratório 07 no mezanino — a cela do Dr. Vance (resgate opcional).
func _add_lab07(lvl: Node) -> void:
	lvl.add_child(_instance("res://scenes/objects/holding_cell.tscn", "Lab07Cell", Vector2(4480, -144)))
	var sign := Label.new()
	sign.name = "Lab07Sign"
	sign.text = "LAB 07 // ACESSO RESTRITO"
	sign.position = Vector2(4400, -350)
	sign.add_theme_font_size_override("font_size", 14)
	sign.add_theme_color_override("font_color", Color("FF6A1A"))
	lvl.add_child(sign)
	# SINE avisa ao subir no mezanino do laboratório.
	_dialogue_trigger(lvl, "rnd_lab07", Vector2(4150, -144), Vector2(80, 128))


## C: barreiras a laser do chão ao teto do corredor. A 1ª é fixa (hackear para
## passar); as outras duas ligam e desligam fora de sincronia (passar no ritmo,
## ou hackear para segurar desligado). Quem vai pelo duto não precisa de nenhuma.
func _add_lasers(lvl: Node) -> void:
	var holder := _holder(lvl, "Lasers")
	# [x, modo, fase]
	var list := [
		[2760.0, LaserBarrier.Mode.ALWAYS, 0.0],
		[3020.0, LaserBarrier.Mode.TIMED, 0.0],
		[3280.0, LaserBarrier.Mode.TIMED, 2.0],
	]
	for l in list:
		var laser := _instance("res://scenes/objects/laser_barrier.tscn", "Laser%d" % int(l[0]), Vector2(l[0], 16))
		laser.set("height", 16.0 - CORRIDOR_Y)
		laser.set("mode", l[1])
		laser.set("phase", l[2])
		holder.add_child(laser)


func _add_cameras(lvl: Node) -> void:
	var holder := _holder(lvl, "Cameras")
	# A: na parede do fim da recepção, olhando para o balcão.
	_camera(holder, false, "ReceptionCamera", Vector2(1080, -250),
		{"facing_left": true, "sweep_min_deg": 20.0, "sweep_max_deg": 60.0, "vision_range": 420.0})
	_camera(holder, true, "OfficeDome", Vector2(1900, CEILING_Y + 24),
		{"sweep_min_deg": 55.0, "sweep_max_deg": 125.0, "vision_range": 420.0, "fov_deg": 30.0})
	# C: no fim do corredor, olhando para trás (o duto fica fora do alcance).
	_camera(holder, false, "CorridorCamera", Vector2(3500, CORRIDOR_Y + 30),
		{"facing_left": true, "sweep_min_deg": 5.0, "sweep_max_deg": 30.0, "vision_range": 480.0})
	_camera(holder, true, "LabDome", Vector2(4200, CEILING_Y + 24),
		{"sweep_min_deg": 60.0, "sweep_max_deg": 120.0, "vision_range": 380.0, "fov_deg": 28.0})
	_camera(holder, false, "AtriumCamera", Vector2(170 * T + 16 - 35, _y(-14)),
		{"facing_left": true, "sweep_min_deg": 15.0, "sweep_max_deg": 65.0, "vision_range": 420.0})


func _add_guards(lvl: Node) -> void:
	# [variante, x inicial, chão, waypoint A, waypoint B]
	_guards(lvl, [
		["v2", 600.0, 16.0, 400.0, 1050.0],          # A: recepção
		["v2", 1700.0, 16.0, 1250.0, 2450.0],        # B: chão
		["v1", 1800.0, -144.0, 1350.0, 2350.0],      # B: mezanino
		["cyborg", 4200.0, 16.0, 3700.0, 4700.0],    # D: Unidade Lógica no chão dos laboratórios
		["v1", 4200.0, -144.0, 3750.0, 4600.0],      # D: mezanino
		["cyborg", 5200.0, -240.0, 5000.0, 5400.0],  # E: Unidade Lógica na passarela do meio
	])


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, EXIT_POS)
	exit.name = "LevelExit"
	var sign := Label.new()
	sign.name = "ElevatorSign"
	sign.text = "ELEVADOR EXECUTIVO  ->  NÚCLEO\n(fase 4 em construção)"
	sign.position = Vector2(5150, -968)
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color("00F0FF"))
	lvl.add_child(sign)


## Placas de greybox com o nome de cada trecho (saem na troca pela arte final).
func _add_zone_labels(lvl: Node) -> void:
	var holder := _holder(lvl, "ZoneLabels")
	for z in ZONES:
		var l := Label.new()
		l.name = "Zone_" + String(z[0]).left(1)
		l.text = z[0]
		l.position = z[1]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 0.6))
		holder.add_child(l)
