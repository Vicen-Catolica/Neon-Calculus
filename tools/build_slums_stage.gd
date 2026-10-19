extends Node
## Gera as cenas de objetos e monta a Fase 1 (Favelas / "The Gutter").
## Roda como cena (para os autoloads existirem). Uso, na raiz do projeto:
##   Godot --headless --path . res://tools/build_slums_stage.tscn
## Reexecutar sobrescreve as cenas geradas (não edite-as à mão; edite este script).

const T := 32
const GROUND_TS := "res://assets/tilesets/slums/slums_ground.tres"
const STRUCT_TS := "res://assets/tilesets/slums/slums_structures.tres"
const OUT_LEVEL := "res://scenes/levels/slums/slums_stage1.tscn"
const NEXT_STAGE := "res://scenes/Stage2/stage2.tscn"

var _root: Node


func _ready() -> void:
	_build_object_scenes()
	_build_level()
	print("build_slums_stage: OK")
	get_tree().quit()


# =============================================================================
# Utilidades
# =============================================================================

func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	# Cena instanciada: só a raiz pertence ao nível; os filhos são da própria cena.
	# (Descer aqui duplica os nós internos ao carregar.)
	if node.scene_file_path != "":
		return
	for c in node.get_children():
		_own(c, owner_node)


func _save(root: Node, path: String) -> void:
	for c in root.get_children():
		_own(c, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack falhou: " + path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save falhou: " + path)
	print("  salvo ", path)
	root.free()


func _rect_shape(size: Vector2, pos: Vector2 = Vector2.ZERO) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = pos
	return cs


func _frames(anims: Array) -> SpriteFrames:
	# anims: [[nome, pasta, n, fps, loop], ...]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for a in anims:
		var name: StringName = a[0]
		sf.add_animation(name)
		sf.set_animation_speed(name, a[3])
		sf.set_animation_loop(name, a[4])
		for i in range(1, a[2] + 1):
			sf.add_frame(name, load("%s/frame_%d.png" % [a[1], i]))
	return sf


func _hackable(display: String, pos: Vector2) -> Hackable:
	var h := Hackable.new()
	h.name = "Hackable"
	h.display_name = display
	h.position = pos
	return h


# =============================================================================
# Cenas de objetos
# =============================================================================

func _build_object_scenes() -> void:
	_build_guard("v1", "res://scenes/enemies/guard_v1.tscn")
	_build_guard("v2", "res://scenes/enemies/guard_v2.tscn")
	_build_camera(SecurityCamera.Model.WALL, "res://scenes/objects/security_camera_wall.tscn")
	_build_camera(SecurityCamera.Model.DOME, "res://scenes/objects/security_camera_dome.tscn")
	_build_door()
	_build_kiosk()
	_build_data_terminal()
	_build_ui()


func _build_guard(variant: String, path: String) -> void:
	var g := CharacterBody2D.new()
	g.name = "Guard"
	g.set_script(load("res://Entities/Enemy/enemy.gd"))
	g.set("move_speed", 70.0)
	g.set("chase_speed", 165.0)
	g.set("vision_range", 320.0)
	g.set("vision_angle_deg", 55.0)
	g.set("attack_range", 210.0)
	g.set("taser_defense_drain", 34.0)
	g.set("eye_offset", Vector2(0, -102))
	g.set("show_debug_vision", false)
	g.set("show_vision_cone", true)

	var sensors := Node2D.new()
	sensors.name = "Sensors"
	g.add_child(sensors)
	var hearing := Area2D.new()
	hearing.name = "HearingArea"
	hearing.visible = false
	sensors.add_child(hearing)
	var hs := CollisionShape2D.new()
	hs.name = "HearingCollision"
	var circle := CircleShape2D.new()
	circle.radius = 300.0
	hs.shape = circle
	hs.position = Vector2(0, -60)
	hearing.add_child(hs)

	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	spr.sprite_frames = load("res://scenes/enemies/guard_%s_frames.tres" % variant)
	spr.position = Vector2(-2, -62)
	spr.animation = &"idle"
	spr.autoplay = "idle"
	g.add_child(spr)

	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 118.0
	body.shape = cap
	body.position = Vector2(0, -59)
	g.add_child(body)

	var nav := NavigationAgent2D.new()
	nav.name = "NavigationAgent2D"
	g.add_child(nav)

	var vis := VisibleOnScreenEnabler2D.new()
	vis.name = "VisibleOnScreenEnabler2D"
	vis.rect = Rect2(-900, -500, 1800, 800)
	g.add_child(vis)

	var timer := Timer.new()
	timer.name = "AttackTimer"
	timer.wait_time = 0.7
	g.add_child(timer)

	var sm := Node.new()
	sm.name = "StateMachine"
	sm.set_script(load("res://Entities/Enemy/StateMachine.gd"))
	g.add_child(sm)
	var states := {
		"Patrol": "StatePatrol", "Suspicious": "StateSuspicious", "Search": "StateSearch",
		"MaxAlert": "StateMaxAlert", "Distracted": "StateDistracted", "Investigate": "StateInvestigate",
	}
	for sname in states:
		var s := Node.new()
		s.name = sname
		s.set_script(load("res://Entities/Enemy/%s.gd" % states[sname]))
		sm.add_child(s)
	sm.set("initial_state", sm.get_node("Patrol"))

	var lbl := Label.new()
	lbl.name = "StateIndicator"
	lbl.custom_minimum_size = Vector2(40, 30)
	lbl.position = Vector2(-20, -160)
	lbl.size = Vector2(40, 30)
	lbl.pivot_offset = Vector2(20, 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.add_child(lbl)

	var line := Line2D.new()
	line.name = "TaserLine"
	line.visible = false
	line.width = 3.0
	line.default_color = Color(0, 0.94, 1, 1)
	g.add_child(line)

	g.add_child(_hackable("AGENTE", Vector2(0, -90)))
	_save(g, path)


func _build_camera(model: int, path: String) -> void:
	var cam := Node2D.new()
	cam.name = "SecurityCamera"
	cam.set_script(load("res://scripts/objects/security_camera.gd"))
	cam.set("model", model)
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	cam.add_child(spr)
	cam.add_child(_hackable("CÂMERA", Vector2(0, 0)))
	_save(cam, path)


func _build_door() -> void:
	var d := StaticBody2D.new()
	d.name = "SecurityDoor"
	d.set_script(load("res://scripts/objects/security_door.gd"))
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = load("res://assets/objects/door/door_sheet.png")
	spr.hframes = 7
	spr.position = Vector2(0, -72)
	d.add_child(spr)
	var sh := _rect_shape(Vector2(40, 136), Vector2(0, -68))
	sh.name = "Shape"
	d.add_child(sh)
	d.add_child(_hackable("PORTA BIOMÉTRICA", Vector2(0, -80)))
	_save(d, "res://scenes/objects/security_door.tscn")


func _build_kiosk() -> void:
	var k := Node2D.new()
	k.name = "AxiomaKiosk"
	k.set_script(load("res://scripts/objects/axioma_kiosk.gd"))
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = _frames([
		[&"locked", "res://assets/terminals/equation_locked", 2, 2.0, true],
		[&"hacking", "res://assets/terminals/equation_hacking", 4, 8.0, true],
	])
	spr.position = Vector2(0, -48)
	k.add_child(spr)
	k.add_child(_hackable("QUIOSQUE AXIOMA", Vector2(4, -66)))
	_save(k, "res://scenes/objects/axioma_kiosk.tscn")


func _build_data_terminal() -> void:
	var t := Area2D.new()
	t.name = "DataTerminal"
	t.set_script(load("res://scripts/lore/data_terminal.gd"))
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = _frames([
		[&"idle", "res://assets/terminals/data_idle", 2, 2.0, true],
		[&"reading", "res://assets/terminals/data_reading", 4, 8.0, false],
	])
	spr.position = Vector2(0, -40)
	t.add_child(spr)
	t.add_child(_rect_shape(Vector2(90, 100), Vector2(0, -50)))
	_save(t, "res://scenes/objects/data_terminal.tscn")


func _build_ui() -> void:
	var lr := CanvasLayer.new()
	lr.name = "LoreReader"
	lr.set_script(load("res://scripts/ui/lore_reader.gd"))
	_save(lr, "res://scenes/ui/lore_reader.tscn")
	var sh := CanvasLayer.new()
	sh.name = "StealthHUD"
	sh.set_script(load("res://scripts/ui/stealth_hud.gd"))
	_save(sh, "res://scenes/ui/stealth_hud.tscn")


# =============================================================================
# Fase 1 — Favelas
# =============================================================================
# Coordenadas em tiles (32 px). Um retângulo de células [x0..x1] x [y0..y1]
# pintado no terreno "Corners" tem a superfície em y0*32+16 e a face esquerda
# em x0*32+16 (as bordas caem no centro das células das pontas).
#
# Percurso: rua (térreo) da esquerda para a direita -> porta da torre -> poço
# vertical com escadas no canto direito -> lajes das casas de volta para a
# esquerda (2º andar da fase) -> escada no escuro no canto esquerdo -> fase 2.

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


func _y(row: int) -> float:
	return row * T + 16.0


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


func _build_level() -> void:
	var lvl := Node2D.new()
	lvl.name = "SlumsStage1"
	lvl.set_script(load("res://scripts/core/slums_level.gd"))
	lvl.set("limit_left", -48)
	lvl.set("limit_right", 166 * T + 16)
	lvl.set("limit_top", -1400)
	lvl.set("limit_bottom", 300)
	lvl.set("floor_number", 1)
	_root = lvl

	_add_background(lvl)
	_add_houses(lvl)
	_add_tiles(lvl)
	_add_ladders(lvl)
	_add_props(lvl)
	_add_neon(lvl)
	_add_terminals(lvl)
	_add_kiosk_and_door(lvl)
	_add_cameras(lvl)
	_add_guards(lvl)
	_add_exit(lvl)
	_add_player_and_ui(lvl)
	_save(lvl, OUT_LEVEL)


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
	var holder := Node2D.new()
	holder.name = "Houses"
	lvl.add_child(holder)
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


## Topo do letreiro da loja (para a placa de neon): y do centro do letreiro.
func _storefront_sign_y(shop: String) -> float:
	var tex: Texture2D = load(FACADE_DIR + "storefront_%s.png" % shop)
	var gy := _ground_y_at(STOREFRONTS[shop]) - 10.0
	var top := gy - tex.get_height()
	var board := {"24h": 43.0, "ramen": 15.0, "repair": 12.0}
	return top + float(board[shop])


func _paint(layer: TileMapLayer, rects: Array) -> void:
	var cells: Array[Vector2i] = []
	var seen := {}
	for r in rects:
		for x in range(r[0], r[2] + 1):
			for y in range(r[1], r[3] + 1):
				var c := Vector2i(x, y)
				if not seen.has(c):
					seen[c] = true
					cells.append(c)
	layer.set_cells_terrain_connect(cells, 0, 0, false)


func _add_tiles(lvl: Node) -> void:
	var buildings := TileMapLayer.new()
	buildings.name = "Buildings"
	buildings.tile_set = load(GROUND_TS)
	buildings.self_modulate = Color(0.42, 0.4, 0.5)
	lvl.add_child(buildings)
	_paint(buildings, BUILDING_RECTS)

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load(GROUND_TS)
	lvl.add_child(ground)
	_paint(ground, _all_ground_rects())

	_add_floor_band(lvl)

	var st := TileMapLayer.new()
	st.name = "Structures"
	st.tile_set = load(STRUCT_TS)
	lvl.add_child(st)
	for cw in CATWALKS:
		var x0: int = cw[0]
		var x1: int = cw[1]
		var row: int = cw[2]
		for x in range(x0, x1 + 1):
			var atlas := Vector2i(1, 0) if x % 2 == 0 else Vector2i(0, 1)
			if x == x0:
				atlas = Vector2i(0, 0)
			elif x == x1:
				atlas = Vector2i(2, 0)
			st.set_cell(Vector2i(x, row), 0, atlas)
		if cw[3]:
			# vigas de apoio sob a ponta direita
			for y in range(row + 1, 0):
				st.set_cell(Vector2i(x1 - 1, y), 0, Vector2i(2, 1))
	_add_catwalk_band(lvl)


# --- Faixas de chão em profundidade (falso 3D, sem colisão) ----------------

const FLOOR_BAND_TEX := "res://assets/tilesets/slums/floor_band.png"
const FLOOR_BAND_BACK := 22.0   # px acima da superfície (ver tools/gen_floor_band.py)
const CATWALK_BAND_TEX := "res://assets/tilesets/slums/catwalk_band.png"
const CATWALK_BAND_BACK := 14.0


## Calcula os trechos de superfície andável de todos os retângulos sólidos:
## [x_esq, x_dir, y]. Uma célula é superfície se a de cima está vazia; a borda
## do trecho vai até a face do vizinho mais alto (centro da célula vizinha).
func _surface_runs() -> Array:
	var solid := {}
	var rects := _all_ground_rects() + BUILDING_RECTS
	for r in rects:
		for x in range(r[0], r[2] + 1):
			for y in range(r[1], r[3] + 1):
				solid[Vector2i(x, y)] = true
	var tops := {}  # x -> lista de linhas de topo
	for c in solid.keys():
		var cell: Vector2i = c
		if not solid.has(cell + Vector2i(0, -1)):
			if not tops.has(cell.y):
				tops[cell.y] = []
			tops[cell.y].append(cell.x)
	var runs := []
	for row in tops.keys():
		var xs: Array = tops[row]
		xs.sort()
		var a: int = xs[0]
		var prev: int = a
		for i in range(1, xs.size() + 1):
			var x: int = xs[i] if i < xs.size() else 999999
			if x != prev + 1:
				var b := prev
				var l := float(a * T + 16)
				var r := float(b * T + 16)
				if solid.has(Vector2i(a - 1, row - 1)):
					l = (a - 1) * T + 16.0
				if solid.has(Vector2i(b + 1, row - 1)):
					r = (b + 1) * T + 16.0
				if r > l:
					runs.append([l, r, _y(row)])
				a = x
			prev = x
	return runs


func _add_floor_band(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "FloorBand"
	lvl.add_child(holder)
	var tex: Texture2D = load(FLOOR_BAND_TEX)
	var i := 0
	for b in _surface_runs():
		i += 1
		var s := Sprite2D.new()
		s.name = "Band%d" % i
		s.texture = tex
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(b[0], 0, b[1] - b[0], tex.get_height())
		s.position = Vector2(b[0], b[2] - FLOOR_BAND_BACK)
		holder.add_child(s)


func _add_catwalk_band(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "CatwalkBand"
	lvl.add_child(holder)
	var tex: Texture2D = load(CATWALK_BAND_TEX)
	var i := 0
	for cw in CATWALKS:
		i += 1
		var x0: float = cw[0] * T + 3.0
		var x1: float = (cw[1] + 1) * T - 4.0
		var s := Sprite2D.new()
		s.name = "Grate%d" % i
		s.texture = tex
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, x1 - x0, tex.get_height())
		s.position = Vector2(x0, _y(cw[2]) - CATWALK_BAND_BACK)
		holder.add_child(s)


# --- Escadas -----------------------------------------------------------------

func _add_ladders(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "Ladders"
	lvl.add_child(holder)
	var st := lvl.get_node("Structures") as TileMapLayer
	var i := 0
	for l in LADDERS:
		i += 1
		var lx: int = l[0]
		var row: int = l[1]
		var base_y: float = l[2]
		var base_row := int(floor((base_y - 16.0) / T))
		# começa abaixo da plataforma do topo (não abre buraco na grade)
		for y in range(row + 1, base_row):
			st.set_cell(Vector2i(lx, y), 0, Vector2i(1, 1) if y % 2 == 0 else Vector2i(3, 1))
		var ladder := Area2D.new()
		ladder.name = "Ladder" if i == 1 else "Ladder%d" % i
		ladder.set_script(load("res://scripts/objects/ladder.gd"))
		ladder.position = Vector2(lx * T + 16, base_y)
		var gap := base_y - _y(row)
		# A área vai até a superfície do topo: o Eduardo só "sai" da escada
		# quando os pés passam do topo, e cai em cima da plataforma de mão única.
		var h := gap + 4.0
		ladder.add_child(_rect_shape(Vector2(24, h), Vector2(0, -h / 2.0)))
		holder.add_child(ladder)


# --- Props e esconderijos ----------------------------------------------------

func _prop(parent: Node, tex: String, x: float, ground_y: float, name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name
	var path := "res://assets/props/slums/%s.png" % tex
	if not ResourceLoader.exists(path):
		path = FACADE_DIR + tex + ".png"
	s.texture = load(path)
	# Base do prop no meio da faixa de chão (desenhado em 3/4, pisa "dentro" da calçada).
	s.position = Vector2(x, ground_y - s.texture.get_height() / 2.0 - 4.0)
	parent.add_child(s)
	return s


func _hide_spot(parent: Node, x: float, ground_y: float, width: float, name: String) -> void:
	var a := Area2D.new()
	a.name = name
	a.set_script(load("res://scripts/objects/hide_spot.gd"))
	a.position = Vector2(x, ground_y)
	a.add_child(_rect_shape(Vector2(width, 90), Vector2(0, -45)))
	parent.add_child(a)


func _add_props(lvl: Node) -> void:
	var props := Node2D.new()
	props.name = "Props"
	lvl.add_child(props)
	var spots := Node2D.new()
	spots.name = "HideSpots"
	lvl.add_child(spots)
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
		_prop(props, p[0], p[1], p[2], "%s_%d" % [p[0], n])
		if p[3]:
			_hide_spot(spots, p[1], p[2], p[4], "Hide_%s_%d" % [p[0], n])
	# Presos nas fachadas (sobre os tiles do prédio, não no chão nem no ar):
	# canos no prédio T1 logo acima da boca do túnel; ar-condicionado na torre.
	_wall_prop(props, "pipes_cable", Vector2(110 * T, -190), "pipes_cable_wall")
	_wall_prop(props, "ac_unit", Vector2(151 * T, -250), "ac_unit_wall")


func _wall_prop(parent: Node, tex: String, center: Vector2, name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name
	s.texture = load("res://assets/props/slums/%s.png" % tex)
	s.position = center
	parent.add_child(s)
	return s


# --- Neon ----------------------------------------------------------------------

func _neon(parent: Node, tex: String, pos: Vector2, hackable: bool, light_size: Vector2 = Vector2.ZERO, light_ground: float = 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = tex.get_basename().to_pascal_case()
	s.set_script(load("res://scripts/objects/neon_sign.gd"))
	var path := "res://assets/neon/slums/%s.png" % tex
	s.texture = load(path)
	if tex.ends_with("_flicker_2f"):
		s.hframes = 2
	s.position = pos
	parent.add_child(s)
	if hackable:
		s.add_child(_hackable("LUZ NEON", Vector2.ZERO))
	if light_size != Vector2.ZERO:
		# zona de luz apoiada no chão, logo abaixo da placa
		var light_offset := Vector2(0, light_ground - pos.y - light_size.y / 2.0)
		var lz := Area2D.new()
		lz.name = "LightZone"
		lz.monitorable = false
		lz.add_child(_rect_shape(light_size, light_offset))
		s.add_child(lz)
		var glow := Polygon2D.new()
		glow.name = "Glow"
		var hw := light_size.x / 2.0
		var top := 14.0
		var bot := light_offset.y + light_size.y / 2.0
		glow.polygon = PackedVector2Array([Vector2(-hw * 0.35, top), Vector2(hw * 0.35, top), Vector2(hw, bot), Vector2(-hw, bot)])
		glow.color = Color(1.0, 0.35, 0.8, 0.07) if "RAMEN" in tex else Color(1.0, 0.6, 0.2, 0.07)
		glow.show_behind_parent = true
		s.add_child(glow)
	return s


func _add_neon(lvl: Node) -> void:
	var ns := Node2D.new()
	ns.name = "NeonSigns"
	lvl.add_child(ns)
	# Placas presas nas lojas/casas (antes flutuavam sobre o fundo).
	_neon(ns, "neon_OPEN_24H_flicker_2f", Vector2(STOREFRONTS["24h"], _storefront_sign_y("24h")), false)
	# RAMEN ilumina os caixotes: é preciso hackear a luz para se esconder ali.
	_neon(ns, "neon_RAMEN_flicker_2f", Vector2(STOREFRONTS["ramen"], _storefront_sign_y("ramen")), true, Vector2(260, 150), 16.0)
	_neon(ns, "neon_ramen_bowl", Vector2(1170, -150), false)
	_neon(ns, "neon_BAR_flicker_2f", Vector2(1700, -300), false)       # 2º andar da casa da passarela
	_neon(ns, "neon_hanging_sign_arrow", Vector2(2030, -250), false)   # parede da casa H6
	# REPAIR ilumina a caixa de papelão no quarteirão elevado.
	_neon(ns, "neon_REPAIR_flicker_2f", Vector2(STOREFRONTS["repair"], _storefront_sign_y("repair")), true, Vector2(240, 150), -48.0)
	_neon(ns, "neon_HOTEL_vertical_flicker_2f", Vector2(3720, -300), false)  # fachada do T1
	_neon(ns, "neon_repair_broken_vertical", Vector2(4760, -330), false)     # fachada da torre


func _add_terminals(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "DataTerminals"
	lvl.add_child(holder)
	var scene: PackedScene = load("res://scenes/objects/data_terminal.tscn")
	var list := [
		["slums_01_sine", Vector2(170, 16)],
		["slums_02_quota", Vector2(1860, -144)],
		["slums_03_variance", Vector2(3880, -48)],
		["slums_04_determinism", Vector2(260, _y(-20))],   # laje H10, antes da escada final
	]
	for e in list:
		var t := scene.instantiate()
		t.name = "Terminal_" + String(e[0])
		t.set("entry_id", e[0])
		t.position = e[1]
		holder.add_child(t)


func _add_kiosk_and_door(lvl: Node) -> void:
	var kiosk: Node2D = (load("res://scenes/objects/axioma_kiosk.tscn") as PackedScene).instantiate()
	kiosk.name = "AxiomaKiosk"
	kiosk.position = Vector2(2560, -48)
	lvl.add_child(kiosk)
	var door: Node2D = (load("res://scenes/objects/security_door.tscn") as PackedScene).instantiate()
	door.name = "SecurityDoor"
	door.position = Vector2(146 * T + 40, -48)
	lvl.add_child(door)


func _add_cameras(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "Cameras"
	lvl.add_child(holder)
	# Câmera de parede na fachada esquerda do prédio T1, olhando para trás (esquerda).
	var wall: Node2D = (load("res://scenes/objects/security_camera_wall.tscn") as PackedScene).instantiate()
	wall.name = "WallCamera"
	wall.set("facing_left", true)
	wall.set("sweep_min_deg", 22.0)
	wall.set("sweep_max_deg", 58.0)
	wall.set("vision_range", 440.0)
	wall.position = Vector2(105 * T + 16 - 35, -300)
	holder.add_child(wall)
	# Dome no teto do beco coberto (marquise T2, teto em y = -208).
	var dome: Node2D = (load("res://scenes/objects/security_camera_dome.tscn") as PackedScene).instantiate()
	dome.name = "DomeCamera"
	dome.set("model", SecurityCamera.Model.DOME)
	dome.set("sweep_min_deg", 55.0)
	dome.set("sweep_max_deg", 125.0)
	dome.set("vision_range", 260.0)
	dome.set("fov_deg", 30.0)
	dome.position = Vector2(4300, _y(-7) + 24)
	holder.add_child(dome)
	# Poço: câmera na parede final varrendo os andares de grade.
	var shaft: Node2D = (load("res://scenes/objects/security_camera_wall.tscn") as PackedScene).instantiate()
	shaft.name = "ShaftCamera"
	shaft.set("facing_left", true)
	shaft.set("sweep_min_deg", 15.0)
	shaft.set("sweep_max_deg", 65.0)
	shaft.set("vision_range", 420.0)
	shaft.position = Vector2(166 * T + 16 - 35, _y(-16))
	holder.add_child(shaft)
	# Puxadinho da laje H4: câmera na face direita, vigiando quem chega pela laje.
	var shed: Node2D = (load("res://scenes/objects/security_camera_wall.tscn") as PackedScene).instantiate()
	shed.name = "ShedCamera"
	shed.set("facing_left", false)
	shed.set("sweep_min_deg", 12.0)
	shed.set("sweep_max_deg", 50.0)
	shed.set("vision_range", 380.0)
	shed.position = Vector2(92 * T + 16 + 35, _y(-25))
	holder.add_child(shed)


func _add_guards(lvl: Node) -> void:
	var holder := Node2D.new()
	holder.name = "Guards"
	lvl.add_child(holder)
	var wps := Node2D.new()
	wps.name = "Waypoints"
	lvl.add_child(wps)
	# [variante, x inicial, chão, waypoint A, waypoint B]
	var list := [
		["v1", 1060.0, 16.0, 760.0, 1360.0],
		["v2", 2650.0, -48.0, 2300.0, 3000.0],
		["v1", 4400.0, -48.0, 4150.0, 4600.0],
		# 2º andar
		["v2", 3800.0, _y(-22), 3640.0, 3960.0],
		["v1", 1100.0, _y(-21), 1000.0, 1210.0],
		["v1", 700.0, _y(-19), 560.0, 860.0],
	]
	var i := 0
	for g in list:
		i += 1
		var guard: CharacterBody2D = (load("res://scenes/enemies/guard_%s.tscn" % g[0]) as PackedScene).instantiate()
		guard.name = "Guard%d" % i
		guard.position = Vector2(g[1], g[2])
		holder.add_child(guard)
		var arr: Array[Node2D] = []
		for k in 2:
			var m := Marker2D.new()
			m.name = "G%d_WP%d" % [i, k + 1]
			m.position = Vector2(g[3 + k], g[2])
			wps.add_child(m)
			arr.append(m)
		guard.set("waypoints", arr)


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

	var exit := Area2D.new()
	exit.name = "ExitToStage2"
	exit.set_script(load("res://scenes/Stage1/NextStage.gd"))
	exit.set("next_stage", NEXT_STAGE)
	exit.position = Vector2(4 * T + 16, _y(-36))
	exit.add_child(_rect_shape(Vector2(120, 40), Vector2(0, -20)))
	lvl.add_child(exit)


func _add_player_and_ui(lvl: Node) -> void:
	var sweep := Node2D.new()
	sweep.name = "RoutineSweep"
	sweep.set_script(load("res://scripts/core/routine_sweep.gd"))
	lvl.add_child(sweep)

	var player: Node2D = (load("res://scenes/player/eduardo.tscn") as PackedScene).instantiate()
	player.name = "Eduardo"
	player.position = Vector2(64, 16)
	lvl.add_child(player)

	var hud: Node = (load("res://scenes/Hud/HUD.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	lvl.add_child(hud)
	var stealth: Node = (load("res://scenes/ui/stealth_hud.tscn") as PackedScene).instantiate()
	lvl.add_child(stealth)
	var hacking: Node = (load("res://scenes/hacking_ui/HackingInterface.tscn") as PackedScene).instantiate()
	hacking.name = "HackingInterface"
	hacking.visible = false
	lvl.add_child(hacking)
	var reader: Node = (load("res://scenes/ui/lore_reader.tscn") as PackedScene).instantiate()
	lvl.add_child(reader)
