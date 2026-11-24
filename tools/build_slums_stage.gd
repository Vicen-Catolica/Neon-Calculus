extends "res://tools/stage_builder_base.gd"
## Monta a Fase 1 (Favelas / "The Gutter"). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_slums_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
## As cenas de objetos (guardas, câmeras...) vêm de tools/build_objects.gd.
##
## Percurso: rua (térreo) da esquerda para a direita -> porta da torre -> poço
## vertical com escadas no canto direito -> lajes das casas de volta para a
## esquerda (2º andar da fase) -> escada no escuro no canto esquerdo -> fase 2.

const GROUND_TS := "res://assets/tilesets/slums/slums_ground.tres"
const OUT_LEVEL := "res://scenes/levels/slums/slums_stage1.tscn"
const NEXT_STAGE := "res://scenes/levels/industrial/industrial_stage2.tscn"

const GROUND_RECTS := [
	[-6, 0, 200, 12],     # rua
	[62, -1, 63, 12],     # degrau intermediário (32 px)
	[64, -2, 175, 12],    # quarteirão elevado (superfície y = -48)
]

## Prédios: colidem como o chão, mas ficam numa camada escurecida para lerem
## como estruturas, não como piso.
const BUILDING_RECTS := [
	[-12, -40, -2, 12],   # parede do esconderijo, sobe até o topo da fase
	[105, -18, 118, -5],  # prédio T1 — túnel baixo por baixo (vão de 96 px: só agachado)
	[124, -18, 142, -7],  # marquise T2 — beco coberto (vão de 160 px)
	[146, -26, 154, -6],  # torre — vão da porta de 128 px; o telhado é o topo do poço
	[166, -40, 175, 12],  # parede final (lado direito do poço)
	[88, -27, 92, -23],   # puxadinho na laje H4: passa-se agachado por baixo (vão de 96 px)
]
const BUILDING_TINT := Color(0.42, 0.4, 0.5)

## Casas (fachada sem colisão + laje andável no topo): [x0, x1, linha da laje, loja].
## A fachada vai da laje até a rua; onde há prédio/chão na frente, ele cobre.
## Da direita para a esquerda, na ordem em que o jogador passa no 2º andar.
const HOUSES := [
	[133, 143, -24, ""],
	[112, 124, -22, ""],
	[100, 109, -22, ""],
	[86, 97, -20, "repair"],
	[74, 84, -21, ""],
	[61, 71, -22, ""],
	[44, 58, -20, ""],        # casa da passarela (a passarela é a varanda do 2º andar)
	[30, 38, -21, "ramen"],
	[16, 27, -19, ""],
	[2, 13, -20, "24h"],
]

## Lojas no térreo: centro x de cada uma (a placa de neon fica no letreiro dela).
const STOREFRONTS := {
	"24h": 256.0,
	"ramen": 1060.0,
	"repair": 2880.0,
}

## Passarelas de grade (mão única): [x0, x1, linha, vigas de apoio?]
const CATWALKS := [
	[46, 60, -5, true],       # varanda da casa H7, sobre a rua
	[39, 43, -20, false],     # ponte entre as lajes H7 e H8
	[126, 131, -24, false],   # ponte entre as lajes H1 e H2
	# poço do canto direito: andares a cada 128 px
	[155, 165, -6, false],
	[155, 165, -10, false],
	[155, 165, -14, false],
	[155, 165, -18, false],
	[155, 165, -22, false],
	[155, 165, -26, false],
	[2, 6, -36, false],       # patamar da escada final (no escuro)
]

## Escadas: [célula x, linha do topo, y da base]
const LADDERS := [
	[46, -5, 16.0],           # rua -> varanda da casa da passarela
	[163, -6, -48.0],         # poço: zigue-zague até o telhado da torre
	[157, -10, -176.0],
	[163, -14, -304.0],
	[157, -18, -432.0],
	[163, -22, -560.0],
	[157, -26, -688.0],
	[4, -36, -624.0],         # escada final, da laje H10 para o escuro
]

const STOREY_TEX := ["storey_a", "storey_b", "storey_c"]
const FACADE_DIR := "res://assets/props/slums/facades/"
const STOREY_H := 128.0
const SLAB_H := 10.0
const FACADE_TINT := Color(0.47, 0.45, 0.55)
const STOREFRONT_TINT := Color(0.78, 0.76, 0.85)
const STREET_Y := 16.0


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("SlumsStage1", 1, -48, 166 * T + 16, -1400, 300)
	_add_background(lvl)
	_add_houses(lvl)
	_add_tiles(lvl)
	_ladders(lvl, LADDERS)
	_add_props(lvl)
	_add_neon(lvl)
	# Puxadinho da laje H4: pilares até a laje (o vão de 96 px continua livre).
	_posts(_holder(lvl, "Supports"), 2832.0, 2968.0, -720.0, -624.0)  # bordas do bloco (colisão) e laje
	_add_terminals(lvl)
	_add_kiosk_and_door(lvl)
	_add_cameras(lvl)
	_add_guards(lvl)
	_add_exit(lvl)
	# SINE: conversa de abertura, guia do hack antes do primeiro agente e uma
	# conversa no meio do caminho (relação criador e criação).
	_dialogue_trigger(lvl, "slums_intro", Vector2(64, 16))
	_tutorial_trigger(lvl, "hack", Vector2(460, 16))
	# Módulos do traje (Sonar [V] e Camuflagem [C]) depois do primeiro agente.
	_dialogue_trigger(lvl, "slums_suit", Vector2(1800, 16), Vector2(120, 400))
	_dialogue_trigger(lvl, "slums_kiosk", Vector2(2300, -48), Vector2(120, 400))
	_dialogue_trigger(lvl, "slums_upstairs", Vector2(3500, -48), Vector2(120, 400))
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


func _ground_y_at(x: float) -> float:
	# Superfície do térreo (rua, degrau ou quarteirão) numa coordenada x.
	if x < 62 * T + 16:
		return 16.0
	if x < 64 * T + 16:
		return -16.0
	return -48.0


func _all_ground_rects() -> Array:
	var rects := GROUND_RECTS.duplicate()
	for h in HOUSES:
		rects.append([h[0], h[2], h[1], h[2] + 1])  # laje de 32 px de espessura
	return rects


func _add_background(lvl: Node) -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.color = Color(0.047, 0.04, 0.1, 1)
	sky.position = Vector2(-2000, -2400)
	sky.size = Vector2(9600, 2800)
	lvl.add_child(sky)
	var par := Parallax2D.new()
	par.name = "BackgroundFar"
	par.scroll_scale = Vector2(0.35, 1.0)
	par.repeat_size = Vector2(1536, 0)
	par.repeat_times = 8
	lvl.add_child(par)
	# A favela "empilhada": cópias da arte para cima, cada vez mais escuras e
	# azuladas, cobrem toda a altura que a câmera alcança (limit_top).
	var tex: Texture2D = load("res://assets/backgrounds/slums/bg_favela_dark_seamless.png")
	var h := tex.get_height()
	var tints := [Color(1, 1, 1), Color(0.72, 0.7, 0.82), Color(0.55, 0.53, 0.68),
		Color(0.42, 0.4, 0.55), Color(0.32, 0.3, 0.44), Color(0.24, 0.22, 0.34)]
	# de cima para baixo: a cópia da rua (0) é desenhada por último, na frente
	for i in range(tints.size() - 1, -1, -1):
		var fav := Sprite2D.new()
		fav.name = "Favela%d" % i
		fav.texture = tex
		fav.centered = false
		fav.modulate = tints[i]
		# cópias ímpares espelhadas e deslocadas para disfarçar a repetição
		fav.flip_h = i % 2 == 1
		fav.position = Vector2(-768 + (i % 2) * 400, 16 - h * (i + 1) + i * 24)
		par.add_child(fav)
	# Névoa nas emendas entre as cópias (esconde a linha reta do topo da arte).
	for i in range(1, tints.size()):
		var seam_y := 16.0 - h * i + (i - 1) * 24 + 12
		var c := Color(0.047, 0.04, 0.1)
		var x0 := -768.0
		var x1 := x0 + 1536.0
		var fog := Polygon2D.new()
		fog.name = "SeamFog%d" % i
		fog.polygon = PackedVector2Array([
			Vector2(x0, seam_y - 50), Vector2(x1, seam_y - 50), Vector2(x1, seam_y), Vector2(x0, seam_y),
		])
		fog.vertex_colors = PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, 0.85), Color(c, 0.85)])
		par.add_child(fog)
		var fog2 := Polygon2D.new()
		fog2.name = "SeamFogLow%d" % i
		fog2.polygon = PackedVector2Array([
			Vector2(x0, seam_y), Vector2(x1, seam_y), Vector2(x1, seam_y + 40), Vector2(x0, seam_y + 40),
		])
		fog2.vertex_colors = PackedColorArray([Color(c, 0.85), Color(c, 0.85), Color(c, 0.0), Color(c, 0.0)])
		par.add_child(fog2)


# --- Casas (fachadas no plano do jogo, sem colisão) ------------------------

func _add_houses(lvl: Node) -> void:
	var holder := _holder(lvl, "Houses")
	var slab: Texture2D = load(FACADE_DIR + "slab_strip.png")
	var storeys: Array[Texture2D] = []
	for n in STOREY_TEX:
		storeys.append(load(FACADE_DIR + n + ".png"))
	var idx := 0
	for h in HOUSES:
		idx += 1
		var house := Node2D.new()
		house.name = "House%d" % idx
		holder.add_child(house)
		var left: float = h[0] * T + 16.0
		var right: float = h[1] * T + 16.0
		var top: float = (h[2] + 1) * T + 16.0   # embaixo da laje
		var bottom := STREET_Y - 10.0            # atrás da faixa de calçada
		var width := right - left
		# Andares empilhados de baixo para cima; o último é recortado na laje.
		var y := bottom
		var row := 0
		while y > top:
			var sh := minf(STOREY_H, y - top)
			var x := left
			var col := 0
			while x < right:
				var sw := minf(192.0, right - x)
				var pick := absi(idx * 7 + row * 3 + col * 5) % storeys.size()
				var s := Sprite2D.new()
				s.name = "Storey_%d_%d" % [row, col]
				s.texture = storeys[pick]
				s.centered = false
				s.region_enabled = true
				s.region_rect = Rect2(0, STOREY_H - sh, sw, sh)
				s.flip_h = (idx + row + col) % 2 == 1
				s.position = Vector2(x, y - sh)
				s.modulate = FACADE_TINT
				house.add_child(s)
				x += 192.0
				col += 1
			y -= sh
			# laje de concreto entre andares (esconde a emenda dos módulos)
			if y - SLAB_H > top:
				var sl := Sprite2D.new()
				sl.name = "Slab_%d" % row
				sl.texture = slab
				sl.centered = false
				sl.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				sl.region_enabled = true
				sl.region_rect = Rect2(0, 0, width, SLAB_H)
				sl.position = Vector2(left, y - SLAB_H)
				sl.modulate = FACADE_TINT
				house.add_child(sl)
				y -= SLAB_H
			row += 1
		# contorno escuro nas laterais
		for edge_x in [left - 2.0, right - 1.0]:
			var e := ColorRect.new()
			e.color = Color(0.03, 0.025, 0.04)
			e.position = Vector2(edge_x, top)
			e.size = Vector2(3, bottom - top)
			house.add_child(e)
		var shop: String = h[3]
		if shop != "":
			var sf := Sprite2D.new()
			sf.name = "Storefront_" + shop
			sf.texture = load(FACADE_DIR + "storefront_%s.png" % shop)
			var cx: float = STOREFRONTS[shop]
			var gy := _ground_y_at(cx) - 10.0
			sf.position = Vector2(cx, gy - sf.texture.get_height() / 2.0)
			sf.modulate = STOREFRONT_TINT
			house.add_child(sf)


## Braço de ferro saindo da parede em `wall_x` (altura `arm_y`) até `x_end`, com
## mão-francesa e correntes até `hang_y` (topo da placa pendurada).
func _hang_bracket(parent: Node, wall_x: float, arm_y: float, x_end: float, chains: Array, hang_y: float) -> void:
	var b := Node2D.new()
	b.name = "Bracket_%d" % int(wall_x)
	parent.add_child(b)
	var iron := Color(0.16, 0.15, 0.17)
	var lines := [[Vector2(wall_x, arm_y), Vector2(x_end, arm_y), 4.0],
		[Vector2(wall_x, arm_y + 26.0), Vector2(wall_x + (x_end - wall_x) * 0.6, arm_y), 3.0],
		[Vector2(wall_x - 2.0, arm_y - 6.0), Vector2(wall_x - 2.0, arm_y + 30.0), 5.0]]
	for cx in chains:
		lines.append([Vector2(cx, arm_y), Vector2(cx, hang_y), 2.0])
	for l in lines:
		var ln := Line2D.new()
		ln.width = l[2]
		ln.default_color = iron
		ln.points = PackedVector2Array([l[0], l[1]])
		b.add_child(ln)


## Pilares de madeira/ferro sob um bloco suspenso (só visual: não colidem, o vão
## de baixo continua livre para passar agachado).
func _posts(parent: Node, x0: float, x1: float, top: float, bottom: float) -> void:
	var holder := Node2D.new()
	holder.name = "Posts_%d" % int(x0)
	parent.add_child(holder)
	for x in [x0 + 7.0, x1 - 7.0]:
		var post := Polygon2D.new()
		post.color = Color(0.2, 0.17, 0.16)
		post.polygon = PackedVector2Array([Vector2(x - 6, top), Vector2(x + 6, top), Vector2(x + 6, bottom), Vector2(x - 6, bottom)])
		holder.add_child(post)
		var hi := Polygon2D.new()
		hi.color = Color(0.34, 0.29, 0.26)
		hi.polygon = PackedVector2Array([Vector2(x - 6, top), Vector2(x - 3, top), Vector2(x - 3, bottom), Vector2(x - 6, bottom)])
		holder.add_child(hi)
		var foot := Polygon2D.new()
		foot.color = Color(0.12, 0.11, 0.12)
		foot.polygon = PackedVector2Array([Vector2(x - 9, bottom - 4), Vector2(x + 9, bottom - 4), Vector2(x + 9, bottom), Vector2(x - 9, bottom)])
		holder.add_child(foot)
	# travessa em X entre os pilares, no alto (não atrapalha a leitura do vão)
	var brace := Line2D.new()
	brace.width = 3.0
	brace.default_color = Color(0.2, 0.17, 0.16)
	brace.points = PackedVector2Array([Vector2(x0 + 7, top + 2), Vector2(x0 + 30, top + 22)])
	holder.add_child(brace)
	var brace2 := Line2D.new()
	brace2.width = 3.0
	brace2.default_color = Color(0.2, 0.17, 0.16)
	brace2.points = PackedVector2Array([Vector2(x1 - 7, top + 2), Vector2(x1 - 30, top + 22)])
	holder.add_child(brace2)


## Topo do letreiro da loja (para a placa de neon): y do centro do letreiro.
func _storefront_sign_y(shop: String) -> float:
	var tex: Texture2D = load(FACADE_DIR + "storefront_%s.png" % shop)
	var gy := _ground_y_at(STOREFRONTS[shop]) - 10.0
	var top := gy - tex.get_height()
	var board := {"24h": 43.0, "ramen": 15.0, "repair": 12.0}
	return top + float(board[shop])


func _add_tiles(lvl: Node) -> void:
	_terrain_layer(lvl, "Buildings", GROUND_TS, BUILDING_RECTS, BUILDING_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, _all_ground_rects())
	_floor_band(lvl, _surface_runs(_all_ground_rects() + BUILDING_RECTS))
	_structures(lvl, CATWALKS)
	_catwalk_band(lvl, CATWALKS)


# --- Props e esconderijos ----------------------------------------------------

## Prop da favela pelo nome: procura em props/slums e depois nas fachadas.
func _slum_prop_path(tex: String) -> String:
	var path := "res://assets/props/slums/%s.png" % tex
	if not ResourceLoader.exists(path):
		path = FACADE_DIR + tex + ".png"
	return path


func _add_props(lvl: Node) -> void:
	var props := _holder(lvl, "Props")
	var spots := _holder(lvl, "HideSpots")
	var street := 16.0
	var block := -48.0
	# [textura, x, chão, esconderijo?, largura]
	var list := [
		["barrel", 300.0, street, false, 0],
		["trash_bags", 430.0, street, true, 70],
		["crates", 1000.0, street, true, 56],
		["dumpster", 1260.0, street, true, 60],
		["tire", 1620.0, street, false, 0],
		["trash_bags", 2210.0, block, true, 70],
		["cardboard_box", 2800.0, block, true, 60],
		["barrel", 2990.0, block, false, 0],
		["crates", 4050.0, block, true, 56],
		["tire", 4480.0, block, false, 0],
		# poço
		["crates", 5200.0, _y(-14), true, 56],
		["barrel", 5010.0, _y(-22), false, 0],
		# 2º andar (lajes), da direita para a esquerda
		["antenna", 4860.0, _y(-26), false, 0],
		["water_tank", 4720.0, _y(-26), true, 60],
		["laundry_line", 4440.0, _y(-24), true, 140],
		["antenna", 3940.0, _y(-22), false, 0],
		["water_tank", 3700.0, _y(-22), true, 60],
		["cardboard_box", 3290.0, _y(-22), true, 60],
		["laundry_line", 3040.0, _y(-20), true, 140],
		["ac_unit", 2500.0, _y(-21), false, 0],
		["trash_bags", 2120.0, _y(-22), true, 70],
		["water_tank", 1560.0, _y(-20), true, 60],
		["antenna", 1820.0, _y(-20), false, 0],
		["laundry_line", 1100.0, _y(-21), true, 140],
		["water_tank", 620.0, _y(-19), true, 60],
		["barrel", 800.0, _y(-19), false, 0],
		["antenna", 380.0, _y(-20), false, 0],
	]
	var n := 0
	for p in list:
		n += 1
		_prop(props, _slum_prop_path(p[0]), p[1], p[2], "%s_%d" % [p[0], n])
		if p[3]:
			_hide_spot(spots, p[1], p[2], p[4], "Hide_%s_%d" % [p[0], n])
	# Presos nas fachadas (sobre os tiles do prédio, não no chão nem no ar):
	# canos no prédio T1 logo acima da boca do túnel; ar-condicionado na torre.
	_wall_prop(props, "res://assets/props/slums/pipes_cable.png", Vector2(110 * T, -190), "pipes_cable_wall")
	_wall_prop(props, "res://assets/props/slums/ac_unit.png", Vector2(151 * T, -250), "ac_unit_wall")


# --- Neon ----------------------------------------------------------------------

func _slum_neon(parent: Node, tex: String, pos: Vector2, hackable: bool,
		light_size: Vector2 = Vector2.ZERO, light_ground: float = 0.0) -> void:
	var glow := Color(1.0, 0.35, 0.8, 0.07) if "RAMEN" in tex else Color(1.0, 0.6, 0.2, 0.07)
	_neon(parent, "res://assets/neon/slums/%s.png" % tex, pos, hackable, light_size, light_ground, glow)


func _add_neon(lvl: Node) -> void:
	var ns := _holder(lvl, "NeonSigns")
	# Placas presas nas lojas/casas (antes flutuavam sobre o fundo).
	_slum_neon(ns, "neon_OPEN_24H_flicker_2f", Vector2(STOREFRONTS["24h"], _storefront_sign_y("24h")), false)
	# RAMEN ilumina os caixotes: é preciso hackear a luz para se esconder ali.
	_slum_neon(ns, "neon_RAMEN_flicker_2f", Vector2(STOREFRONTS["ramen"], _storefront_sign_y("ramen")), true, Vector2(260, 150), 16.0)
	# Tigela pendurada num braço de ferro preso na quina da loja (antes flutuava).
	_hang_bracket(ns, 1140.0, -186.0, 1200.0, [1150.0, 1190.0], -179.0)
	_slum_neon(ns, "neon_ramen_bowl", Vector2(1170, -150), false)
	_slum_neon(ns, "neon_BAR_flicker_2f", Vector2(1700, -300), false)       # 2º andar da casa da passarela
	_slum_neon(ns, "neon_hanging_sign_arrow", Vector2(2030, -250), false)   # parede da casa H6
	# REPAIR ilumina a caixa de papelão no quarteirão elevado.
	_slum_neon(ns, "neon_REPAIR_flicker_2f", Vector2(STOREFRONTS["repair"], _storefront_sign_y("repair")), true, Vector2(240, 150), -48.0)
	_slum_neon(ns, "neon_HOTEL_vertical_flicker_2f", Vector2(3720, -300), false)  # fachada do T1
	_slum_neon(ns, "neon_repair_broken_vertical", Vector2(4760, -330), false)     # fachada da torre


func _add_terminals(lvl: Node) -> void:
	_data_terminals(lvl, [
		["slums_01_sine", Vector2(170, 16)],
		["slums_02_quota", Vector2(1860, -144)],
		["slums_03_variance", Vector2(3880, -48)],
		["slums_04_determinism", Vector2(260, _y(-20))],   # laje H10, antes da escada final
	])


func _add_kiosk_and_door(lvl: Node) -> void:
	lvl.add_child(_instance("res://scenes/objects/axioma_kiosk.tscn", "AxiomaKiosk", Vector2(2560, -48)))
	lvl.add_child(_instance("res://scenes/objects/security_door.tscn", "SecurityDoor", Vector2(146 * T + 40, -48)))


func _add_cameras(lvl: Node) -> void:
	var holder := _holder(lvl, "Cameras")
	# Câmera de parede na fachada esquerda do prédio T1, olhando para trás (esquerda).
	_camera(holder, false, "WallCamera", Vector2(105 * T + 16 - 35, -300),
		{"facing_left": true, "sweep_min_deg": 22.0, "sweep_max_deg": 58.0, "vision_range": 440.0})
	# Dome no teto do beco coberto (marquise T2, teto em y = -208).
	_camera(holder, true, "DomeCamera", Vector2(4300, _y(-7) + 24),
		{"sweep_min_deg": 55.0, "sweep_max_deg": 125.0, "vision_range": 260.0, "fov_deg": 30.0})
	# Poço: câmera na parede final varrendo os andares de grade.
	_camera(holder, false, "ShaftCamera", Vector2(166 * T + 16 - 35, _y(-16)),
		{"facing_left": true, "sweep_min_deg": 15.0, "sweep_max_deg": 65.0, "vision_range": 420.0})
	# Puxadinho da laje H4: câmera na face direita, vigiando quem chega pela laje.
	_camera(holder, false, "ShedCamera", Vector2(92 * T + 16 + 35, _y(-25)),
		{"facing_left": false, "sweep_min_deg": 12.0, "sweep_max_deg": 50.0, "vision_range": 380.0})


func _add_guards(lvl: Node) -> void:
	# [variante, x inicial, chão, waypoint A, waypoint B]
	_guards(lvl, [
		["v1", 1060.0, 16.0, 760.0, 1360.0],
		["v2", 2650.0, -48.0, 2300.0, 3000.0],
		["v1", 4400.0, -48.0, 4150.0, 4600.0],
		# 2º andar
		["v2", 3800.0, _y(-22), 3640.0, 3960.0],
		["v1", 1100.0, _y(-21), 1000.0, 1210.0],
		["v1", 700.0, _y(-19), 560.0, 860.0],
	])


func _add_exit(lvl: Node) -> void:
	# Topo da escada final: tudo escurece em volta e a fase termina.
	var dark := Polygon2D.new()
	dark.name = "ExitDarkness"
	dark.z_index = 20
	var top := _y(-36) - 400.0
	var fade_start := _y(-26)
	var fade_end := _y(-33)
	var xl := -400.0
	var xr := 26 * T
	dark.polygon = PackedVector2Array([
		Vector2(xl, fade_start), Vector2(xr, fade_start), Vector2(xr, fade_end), Vector2(xr, top),
		Vector2(xl, top), Vector2(xl, fade_end),
	])
	var c := Color(0.0, 0.0, 0.01)
	dark.vertex_colors = PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, 0.96), Color(c, 1.0),
		Color(c, 1.0), Color(c, 0.96)])
	lvl.add_child(dark)
	_exit(lvl, NEXT_STAGE, Vector2(4 * T + 16, _y(-36)))
