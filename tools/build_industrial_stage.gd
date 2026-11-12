extends "res://tools/stage_builder_base.gd"
## Monta a Fase 2 (Setor Industrial e de Manutenção). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_industrial_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## GREYBOX (etapa 3 do docs/PLANO_FASE_2.md): layout definitivo com as mecânicas
## que já existem; a arte é provisória (tiles da favela tingidos, caixas
## coloridas). Vapor, esteiras, drones e lockdown entram nas etapas 4–7.
##
## Percurso, da esquerda para a direita, tudo dentro da torre (teto em y = -368):
##   A  sala de chegada + duto de manutenção (vão de 96 px: só agachado)
##   B  casa de caldeiras: chão vigiado + passarela superior
##   C  linha de montagem de drones: fosso escuro por baixo ou passarela por cima
##   D  sala dos servidores de refrigeração (teto baixo), porta biométrica na saída
##   E  poço do elevador de carga: 8 andares de grade até o elevador para o P&D

const GROUND_TS := "res://assets/tilesets/industrial/industrial_ground.tres"
const OUT_LEVEL := "res://scenes/levels/industrial/industrial_stage2.tscn"
## Fase 3 (P&D) ainda não existe: a saída fica desligada até lá.
const NEXT_STAGE := ""

## Chão em cor cheia; paredes/teto escurecidos para não lerem como piso.
const WALL_TINT := Color(0.5, 0.46, 0.46)
const PROP_TINT := Color(0.92, 0.9, 0.9)
const CEILING_Y := -368.0        # face de baixo do teto principal
const SERVER_CEILING_Y := -176.0 # face de baixo do teto da sala D
const PIT_Y := 112.0             # fundo do fosso (C)

const GROUND_RECTS := [
	[-12, 0, 83, 12],     # A + B + começo de C
	[84, 3, 104, 12],     # fundo do fosso (96 px abaixo do chão)
	[105, 0, 175, 12],    # fim de C + D + E
]

const WALL_RECTS := [
	[-12, -16, -7, -1],   # parede esquerda (sala de chegada)
	[-8, -16, 151, -12],  # teto principal (face de baixo em -368)
	[7, -11, 24, -3],     # teto do duto: vão de 96 px, só agachado
	[111, -11, 145, -6],  # teto baixo da sala dos servidores (vão de 192 px)
	[146, -11, 151, -5],  # verga da porta D -> E (vão de 160 px)
	[146, -40, 151, -17], # parede esquerda do poço, acima do teto
	[166, -40, 175, -1],  # parede direita do poço
	[146, -46, 175, -41], # tampa do poço
]

## Passarelas de grade (mão única): [x0, x1, linha, vigas de apoio?]
const CATWALKS := [
	[30, 66, -5, false],      # B: passarela das caldeiras (y = -144)
	[76, 110, -4, false],     # C: passarela sobre a linha de montagem (y = -112)
	[84, 86, 0, false],       # C: patamar da escada do fosso (esquerda)
	[102, 104, 0, false],     # C: patamar da escada do fosso (direita)
	# E: poço do elevador, um andar a cada 128 px
	[152, 165, -4, false],
	[152, 165, -8, false],
	[152, 165, -12, false],
	[152, 165, -16, false],
	[152, 165, -20, false],
	[152, 165, -24, false],
	[152, 165, -28, false],
	[152, 165, -32, false],   # topo: elevador de carga
]

## Escadas: [célula x, linha do topo, y da base]
const LADDERS := [
	[31, -5, 16.0],           # B: chão -> passarela
	[65, -5, 16.0],
	[77, -4, 16.0],           # C: chão -> passarela
	[109, -4, 16.0],
	[85, 0, 112.0],           # C: fundo do fosso -> chão
	[103, 0, 112.0],
	[163, -4, 16.0],          # E: zigue-zague até o topo
	[154, -8, -112.0],
	[163, -12, -240.0],
	[154, -16, -368.0],
	[163, -20, -496.0],
	[154, -24, -624.0],
	[163, -28, -752.0],
	[154, -32, -880.0],
]

## Placas com o nome de cada trecho (ajuda no playtest; desligadas com a arte final).
const SHOW_ZONE_LABELS := false
const ZONES := [
	["A // DUTO DE MANUTENÇÃO", Vector2(-180, -330)],
	["B // CASA DE CALDEIRAS", Vector2(1120, -330)],
	["C // LINHA DE MONTAGEM DE DRONES", Vector2(2420, -330)],
	["D // SERVIDORES DE REFRIGERAÇÃO", Vector2(3640, -160)],
	["E // POÇO DO ELEVADOR", Vector2(4880, -330)],
]


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("IndustrialStage2", 2, -208, 166 * T + 16, -1300, 300)
	_add_background(lvl)
	_add_machinery(lvl)   # atrás do terreno e das passarelas
	_add_tiles(lvl)
	_ladders(lvl, LADDERS)
	_add_props(lvl)
	_add_terminals(lvl)
	_add_kiosk_and_door(lvl)
	_add_valves(lvl)
	_add_conveyors(lvl)
	_add_cameras(lvl)
	_add_drones(lvl)
	_add_guards(lvl)
	_add_exit(lvl)
	if SHOW_ZONE_LABELS:
		_add_zone_labels(lvl)
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


# --- Fundo -------------------------------------------------------------------

func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.045, 0.045)
	bg.position = Vector2(-1200, -1800)
	bg.size = Vector2(7600, 2400)
	lvl.add_child(bg)
	# Acima do teto principal (visível ao lado do poço): concreto maciço.
	var mass := ColorRect.new()
	mass.name = "AboveCeiling"
	mass.color = Color(0.085, 0.065, 0.06)
	mass.position = Vector2(-1200, -1800)
	mass.size = Vector2(151 * T + 16 + 1200, 1800 - 496)
	# Salão da fábrica ao fundo (PixelLab), em parallax, empilhado até o topo
	# do poço e cada vez mais escuro para cima.
	var par := Parallax2D.new()
	par.name = "BackgroundFar"
	par.scroll_scale = Vector2(0.4, 1.0)
	par.repeat_size = Vector2(1536, 0)
	par.repeat_times = 8
	lvl.add_child(par)
	var tex: Texture2D = load("res://assets/backgrounds/industrial/bg_industrial_seamless.png")
	var h := tex.get_height()
	var tints := [Color(1, 1, 1), Color(0.7, 0.66, 0.66), Color(0.5, 0.47, 0.48), Color(0.36, 0.34, 0.36)]
	for k in range(tints.size() - 1, -1, -1):
		var hall := Sprite2D.new()
		hall.name = "Hall%d" % k
		hall.texture = tex
		hall.centered = false
		hall.modulate = tints[k]
		hall.flip_h = k % 2 == 1
		hall.position = Vector2(-768, 40 - h * (k + 1))
		par.add_child(hall)
	lvl.add_child(mass)


# --- Terreno -----------------------------------------------------------------

func _add_tiles(lvl: Node) -> void:
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS)
	# Sem a faixa de calçada da favela: aqui o topo é o friso + faixa de perigo do tile.
	_structures(lvl, CATWALKS)
	_catwalk_band(lvl, CATWALKS)


# --- Máquinas (greybox: caixas coloridas no lugar da arte) --------------------

func _box(parent: Node, node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.position = rect.position
	r.size = rect.size
	r.color = color
	parent.add_child(r)
	return r


func _add_machinery(lvl: Node) -> void:
	var m := _holder(lvl, "Machinery")
	var steel := Color(0.22, 0.2, 0.2)
	# (as caldeiras agora estão no fundo gerado)
	# C: braços robóticos pendurados no teto sobre o fosso
	for x in [2850.0, 3130.0]:
		_box(m, "Arm%d" % int(x), Rect2(x, CEILING_Y, 16, 150), steel)
		_box(m, "ArmHead%d" % int(x), Rect2(x - 14, CEILING_Y + 150, 44, 20), Color(0.5, 0.18, 0.1))
	# E: elevador de carga no topo do poço
	_box(m, "ElevatorCage", Rect2(5150, -1008 - 170, 160, 170), Color(0.2, 0.17, 0.16, 0.85))


# --- Props e esconderijos ----------------------------------------------------

const PROP_DIR := "res://assets/props/industrial/"
const SLUM_PROPS := "res://assets/props/slums/"


func _add_props(lvl: Node) -> void:
	var props := _holder(lvl, "Props")
	props.modulate = PROP_TINT
	var spots := _holder(lvl, "HideSpots")
	# [textura, x, chão, esconderijo?, largura]
	var list := [
		["drum", -120.0, 16.0, false, 0],
		["generator", 30.0, 16.0, false, 0],         # A: sala de chegada
		["locker", 1180.0, 16.0, true, 80],          # B: armários de vestiário
		["crates", 1960.0, 16.0, true, 56],          # B: antes do quiosque
		["gas_cylinders", 2150.0, 16.0, false, 0],
		["tool_cart", 2560.0, 16.0, false, 0],
		["hazard_barrier", 2640.0, 16.0, false, 0],  # C: beira do fosso
		["crates", 3260.0, PIT_Y, true, 56],         # C: no escuro do fosso, fora da esteira
		["crates", 1500.0, -144.0, true, 56],        # B: na passarela
		["drum", 4400.0, 16.0, false, 0],            # D
		["crates", 5000.0, -496.0, true, 56],        # E: no meio do poço
	]
	var n := 0
	for p in list:
		n += 1
		_prop(props, PROP_DIR + p[0] + ".png", p[1], p[2], "%s_%d" % [p[0], n])
		if p[3]:
			_hide_spot(spots, p[1], p[2], p[4], "Hide_%s_%d" % [p[0], n])
	_wall_prop(props, SLUM_PROPS + "pipes_cable.png", Vector2(520, -150), "pipes_duct")
	_wall_prop(props, PROP_DIR + "control_panel.png", Vector2(4590, -80), "control_panel_door")
	_wall_prop(props, SLUM_PROPS + "ac_unit.png", Vector2(4300, -260), "ac_unit_wall")
	# D: racks de servidor — esconderijos escuros entre as câmeras
	var racks := _holder(lvl, "ServerRacks")
	for x in [3800.0, 4160.0, 4520.0]:
		_prop(racks, PROP_DIR + "server_rack.png", x, 16.0, "Rack%d" % int(x))
		if x != 4520.0:
			_hide_spot(spots, x, 16.0, 80, "Hide_rack_%d" % int(x))


# --- Objetos interativos -----------------------------------------------------

func _add_terminals(lvl: Node) -> void:
	_data_terminals(lvl, [
		["industrial_01_sine", Vector2(120, 16)],          # A: chegada
		["industrial_02_drones", Vector2(2350, 16)],       # C: antes do fosso
		["industrial_03_mandatory", Vector2(3660, 16)],    # D: entrada dos servidores
		["industrial_04_vance", Vector2(4960, -1008)],     # E: topo, ao lado do elevador
	])


func _add_kiosk_and_door(lvl: Node) -> void:
	# Quiosque perto das caldeiras: distração para o guarda do chão de B.
	lvl.add_child(_instance("res://scenes/objects/axioma_kiosk.tscn", "AxiomaKiosk", Vector2(2080, 16)))
	# Porta biométrica na passagem D -> E.
	lvl.add_child(_instance("res://scenes/objects/security_door.tscn", "SecurityDoor", Vector2(146 * T + 40, 16)))
	# Porta blindada na entrada de D: aberta, só fecha no lockdown (não é hackeável).
	var shutter := _instance("res://scenes/objects/security_door.tscn", "LockdownShutterWest", Vector2(3590, 16))
	shutter.set("start_open", true)
	shutter.set("hackable_enabled", false)
	lvl.add_child(shutter)
	_add_lockdown(lvl)


## D: se um alarme soar com o jogador na sala dos servidores, a Axioma fecha as
## duas portas e o jogador tem 25 s para hackear a saída (equação +1 e mais curta).
func _add_lockdown(lvl: Node) -> void:
	var room := Rect2(3610, SERVER_CEILING_Y, 4680 - 3610, 16 - SERVER_CEILING_Y)
	var zone := Area2D.new()
	zone.name = "ServerLockdown"
	zone.set_script(load("res://scripts/core/lockdown_zone.gd"))
	zone.position = room.get_center()
	zone.add_child(_rect_shape(room.size))
	zone.set("door_paths", [NodePath("../LockdownShutterWest")] as Array[NodePath])
	zone.set("exit_door_path", NodePath("../SecurityDoor"))
	zone.set("countdown", 25.0)
	zone.set("tint_rect", room)
	zone.set("axioma_message", "Variância intolerável no Setor 2-D. Eduardo: erro de cálculo identificado.\nSetor isolado. Unidades pesadas a caminho.")
	lvl.add_child(zone)


## Válvula de vapor apoiada no chão `pos`; o cano sobe até o teto `ceiling_y`.
func _valve(parent: Node, node_name: String, pos: Vector2, nozzle_height: float, ceiling_y: float,
		cloud: Vector2 = Vector2(200, 170)) -> void:
	var v := _instance("res://scenes/objects/steam_valve.tscn", node_name, pos)
	v.set("nozzle_height", nozzle_height)
	v.set("pipe_length", pos.y - nozzle_height - ceiling_y)
	v.set("cloud_size", cloud)
	parent.add_child(v)


func _add_valves(lvl: Node) -> void:
	var holder := _holder(lvl, "SteamValves")
	# B: no meio da patrulha do chão — o vapor esconde quem atravessa por baixo do domo.
	_valve(holder, "BoilerValveFloor", Vector2(1560, 16), 150.0, CEILING_Y, Vector2(200, 150))  # bico logo abaixo da passarela
	# B: na passarela, entre o guarda de cima e a escada da direita.
	_valve(holder, "BoilerValveCatwalk", Vector2(1850, -144), 120.0, CEILING_Y, Vector2(180, 140))
	# D: vapor frio entre os racks, sob o 2º domo dos servidores.
	_valve(holder, "ServerValve", Vector2(4250, 16), 120.0, SERVER_CEILING_Y, Vector2(200, 150))


## C: esteira no fundo do fosso correndo para a esquerda, contra o jogador.
## Andando (110 px/s) não se vence os 140 px/s; correndo (200) até dá, mas o
## barulho chega ao guarda da passarela. O caminho furtivo é hackear e parar.
func _add_conveyors(lvl: Node) -> void:
	var holder := _holder(lvl, "Conveyors")
	var c := _instance("res://scenes/objects/conveyor.tscn", "PitConveyor", Vector2(2980, PIT_Y - 10))
	c.set("width", 420.0)
	c.set("speed", -140.0)
	c.set("stop_time", 10.0)
	holder.add_child(c)


func _add_cameras(lvl: Node) -> void:
	var holder := _holder(lvl, "Cameras")
	_camera(holder, true, "BoilerDome", Vector2(1700, CEILING_Y + 24),
		{"sweep_min_deg": 55.0, "sweep_max_deg": 125.0, "vision_range": 420.0, "fov_deg": 30.0})
	# C: vigia só a passarela; o fundo do fosso fica fora do alcance.
	_camera(holder, true, "AssemblyDome", Vector2(3000, CEILING_Y + 24),
		{"sweep_min_deg": 50.0, "sweep_max_deg": 130.0, "vision_range": 300.0, "fov_deg": 30.0})
	_camera(holder, true, "ServerDome1", Vector2(3980, SERVER_CEILING_Y + 24),
		{"sweep_min_deg": 60.0, "sweep_max_deg": 120.0, "vision_range": 220.0, "fov_deg": 28.0})
	_camera(holder, true, "ServerDome2", Vector2(4340, SERVER_CEILING_Y + 24),
		{"sweep_min_deg": 60.0, "sweep_max_deg": 120.0, "vision_range": 220.0, "fov_deg": 28.0})
	_camera(holder, false, "ShaftCamera", Vector2(166 * T + 16 - 35, _y(-18)),
		{"facing_left": true, "sweep_min_deg": 15.0, "sweep_max_deg": 65.0, "vision_range": 420.0})


## C: drones de patrulha (abaixo da passarela alta, para o sensor alcançar o chão).
func _add_drones(lvl: Node) -> void:
	var holder := _holder(lvl, "Drones")
	# Sobre o fosso: o caminho escuro deixa de ser de graça — espere a volta ou hackeie.
	_drone(holder, "PitDrone", Vector2(2780, -30), Vector2(3220, -30), 230.0)
	# Entrada de C: vigia o quiosque, o terminal e a base da escada da passarela.
	_drone(holder, "FloorDrone", Vector2(2160, -60), Vector2(2650, -60), 220.0)


func _drone(parent: Node, node_name: String, a: Vector2, b: Vector2, vision: float) -> void:
	var d := _instance("res://scenes/enemies/patrol_drone.tscn", node_name, a)
	d.set("point_a", a)
	d.set("point_b", b)
	d.set("vision_range", vision)
	parent.add_child(d)


func _add_guards(lvl: Node) -> void:
	# [variante, x inicial, chão, waypoint A, waypoint B]
	_guards(lvl, [
		["v1", 1500.0, 16.0, 1150.0, 1900.0],        # B: chão (não chega a ver a boca do duto)
		["v2", 1700.0, -144.0, 1150.0, 2000.0],      # B: passarela
		["v1", 3000.0, -112.0, 2600.0, 3350.0],      # C: passarela
		["v2", 4100.0, 16.0, 3700.0, 4500.0],        # D: servidores
	])


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, Vector2(5230, -1008))
	exit.name = "LevelExit"
	var sign := Label.new()
	sign.name = "ElevatorSign"
	sign.text = "ELEVADOR DE CARGA  ->  P&D\n(fase 3 em construção)"
	sign.position = Vector2(4900, -1240)
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color("FF6A1A"))
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
		l.add_theme_color_override("font_color", Color(1, 0.55, 0.3, 0.6))
		holder.add_child(l)
