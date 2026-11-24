extends Node
## Base dos geradores de fase (tools/build_*_stage.gd). Cada fase herda daqui,
## implementa build() (monta e devolve a raiz) e out_path(); a base salva a cena
## e encerra. Rode como cena, para os autoloads existirem:
##   godot --headless --path . res://tools/build_<fase>_stage.tscn
##
## Coordenadas em tiles de 32 px. Um retângulo de células [x0, y0, x1, y1]
## pintado num terreno "Corners" tem a superfície em y0*32+16 e a face esquerda
## em x0*32+16 (as bordas caem no centro das células das pontas).
##
## As cenas de objetos (guarda, câmera, porta...) não são geradas aqui: ficam em
## tools/build_objects.gd, para regerar uma fase não mexer nelas.

const T := 32

## Tileset de passarelas/escadas (atlas: passarela 0..2 x 0, grade 0,1; viga 2,1;
## escada 1,1 / 3,1). Fases que trouxerem um tileset próprio usam o mesmo layout.
const STRUCT_TS := "res://assets/tilesets/slums/slums_structures.tres"

const DEFAULT_FLOOR_BAND_TEX := "res://assets/tilesets/slums/floor_band.png"
const DEFAULT_FLOOR_BAND_BACK := 22.0   # px acima da superfície (ver tools/gen_floor_band.py)
const DEFAULT_CATWALK_BAND_TEX := "res://assets/tilesets/slums/catwalk_band.png"
const DEFAULT_CATWALK_BAND_BACK := 14.0


func _ready() -> void:
	var lvl := build()
	_save(lvl, out_path())
	print("%s: OK" % get_script().resource_path.get_file().get_basename())
	get_tree().quit()


## Monta a fase e devolve a raiz (com o script level.gd). Sobrescrever.
func build() -> Node:
	push_error("build() não implementado")
	return Node2D.new()


## Caminho da cena gerada. Sobrescrever.
func out_path() -> String:
	return ""


# =============================================================================
# Utilidades
# =============================================================================

## Superfície (y do chão) de uma linha de tiles.
func _y(row: int) -> float:
	return row * T + 16.0


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
		var anim_name: StringName = a[0]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, a[3])
		sf.set_animation_loop(anim_name, a[4])
		for i in range(1, a[2] + 1):
			sf.add_frame(anim_name, load("%s/frame_%d.png" % [a[1], i]))
	return sf


func _hackable(display: String, pos: Vector2) -> Hackable:
	var h := Hackable.new()
	h.name = "Hackable"
	h.display_name = display
	h.position = pos
	return h


func _instance(path: String, node_name: String, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var n: Node2D = (load(path) as PackedScene).instantiate()
	n.name = node_name
	n.position = pos
	return n


func _holder(lvl: Node, node_name: String) -> Node2D:
	var h := Node2D.new()
	h.name = node_name
	lvl.add_child(h)
	return h


# =============================================================================
# Raiz da fase
# =============================================================================

func _new_level(node_name: String, floor_number: int, left: int, right: int, top: int, bottom: int) -> Node2D:
	var lvl := Node2D.new()
	lvl.name = node_name
	lvl.set_script(load("res://scripts/core/level.gd"))
	lvl.set("limit_left", left)
	lvl.set("limit_right", right)
	lvl.set("limit_top", top)
	lvl.set("limit_bottom", bottom)
	lvl.set("floor_number", floor_number)
	return lvl


# =============================================================================
# Terreno
# =============================================================================

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
	# O terreno sorteia variantes de tile: semente fixa por camada deixa a
	# regeração reproduzível (diff limpo no git quando nada mudou).
	seed(hash(layer.name))
	layer.set_cells_terrain_connect(cells, 0, 0, false)


## Camada de terreno (terrain set 0, terreno 0) pintada com retângulos de células.
func _terrain_layer(lvl: Node, node_name: String, tileset: String, rects: Array,
		tint: Color = Color.WHITE) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.tile_set = load(tileset)
	if tint != Color.WHITE:
		layer.self_modulate = tint
	lvl.add_child(layer)
	_paint(layer, rects)
	return layer


## Trechos de superfície andável de todos os retângulos sólidos: [x_esq, x_dir, y].
## Uma célula é superfície se a de cima está vazia; a borda do trecho vai até a
## face do vizinho mais alto (centro da célula vizinha).
func _surface_runs(rects: Array) -> Array:
	var solid := {}
	for r in rects:
		for x in range(r[0], r[2] + 1):
			for y in range(r[1], r[3] + 1):
				solid[Vector2i(x, y)] = true
	var tops := {}  # linha -> lista de x
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


## Faixa de chão em profundidade (falso 3D, sem colisão) sobre cada superfície.
func _floor_band(lvl: Node, runs: Array, tex_path: String = DEFAULT_FLOOR_BAND_TEX,
		back: float = DEFAULT_FLOOR_BAND_BACK) -> void:
	var holder := _holder(lvl, "FloorBand")
	var tex: Texture2D = load(tex_path)
	var i := 0
	for b in runs:
		i += 1
		var s := Sprite2D.new()
		s.name = "Band%d" % i
		s.texture = tex
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(b[0], 0, b[1] - b[0], tex.get_height())
		s.position = Vector2(b[0], b[2] - back)
		holder.add_child(s)


# =============================================================================
# Passarelas e escadas
# =============================================================================

## Camada "Structures" com as passarelas de grade (mão única):
## catwalks = [[x0, x1, linha, vigas de apoio?], ...]
func _structures(lvl: Node, catwalks: Array, tileset: String = STRUCT_TS) -> TileMapLayer:
	var st := TileMapLayer.new()
	st.name = "Structures"
	st.tile_set = load(tileset)
	lvl.add_child(st)
	for cw in catwalks:
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
	return st


## Faixa de grade em profundidade sob cada passarela.
func _catwalk_band(lvl: Node, catwalks: Array, tex_path: String = DEFAULT_CATWALK_BAND_TEX,
		back: float = DEFAULT_CATWALK_BAND_BACK) -> void:
	var holder := _holder(lvl, "CatwalkBand")
	var tex: Texture2D = load(tex_path)
	var i := 0
	for cw in catwalks:
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
		s.position = Vector2(x0, _y(cw[2]) - back)
		holder.add_child(s)


## Escadas: ladders = [[célula x, linha do topo, y da base], ...]. Desenha os
## degraus na camada "Structures" e cria a Area2D de cada uma.
func _ladders(lvl: Node, ladders: Array) -> void:
	var holder := _holder(lvl, "Ladders")
	var st := lvl.get_node("Structures") as TileMapLayer
	var i := 0
	for l in ladders:
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


# =============================================================================
# Props, esconderijos e neon
# =============================================================================

## Prop apoiado no chão. A base fica no meio da faixa de chão (desenhado em 3/4,
## pisa "dentro" da calçada).
func _prop(parent: Node, tex_path: String, x: float, ground_y: float, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = load(tex_path)
	s.position = Vector2(x, ground_y - s.texture.get_height() / 2.0 - 4.0)
	parent.add_child(s)
	return s


## Sprite preso numa parede/fachada, pelo centro.
func _wall_prop(parent: Node, tex_path: String, center: Vector2, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = load(tex_path)
	s.position = center
	parent.add_child(s)
	return s


func _hide_spot(parent: Node, x: float, ground_y: float, width: float, node_name: String) -> void:
	var a := Area2D.new()
	a.name = node_name
	a.set_script(load("res://scripts/objects/hide_spot.gd"))
	a.position = Vector2(x, ground_y)
	a.add_child(_rect_shape(Vector2(width, 90), Vector2(0, -45)))
	parent.add_child(a)


## Letreiro/luz neon. `light_size` > 0 cria a zona de luz (expõe o jogador)
## apoiada no chão em `light_ground`, com um cone de brilho de `glow`.
func _neon(parent: Node, tex_path: String, pos: Vector2, hackable: bool,
		light_size: Vector2 = Vector2.ZERO, light_ground: float = 0.0,
		glow: Color = Color(1.0, 0.6, 0.2, 0.07)) -> Sprite2D:
	var file := tex_path.get_file().get_basename()
	var s := Sprite2D.new()
	s.name = file.to_pascal_case()
	s.set_script(load("res://scripts/objects/neon_sign.gd"))
	s.texture = load(tex_path)
	if file.ends_with("_flicker_2f"):
		s.hframes = 2
	s.position = pos
	parent.add_child(s)
	if hackable:
		s.add_child(_hackable("LUZ NEON", Vector2.ZERO))
	if light_size != Vector2.ZERO:
		var light_offset := Vector2(0, light_ground - pos.y - light_size.y / 2.0)
		var lz := Area2D.new()
		lz.name = "LightZone"
		lz.monitorable = false
		lz.add_child(_rect_shape(light_size, light_offset))
		s.add_child(lz)
		var cone := Polygon2D.new()
		cone.name = "Glow"
		var hw := light_size.x / 2.0
		var top := 14.0
		var bot := light_offset.y + light_size.y / 2.0
		cone.polygon = PackedVector2Array([Vector2(-hw * 0.35, top), Vector2(hw * 0.35, top), Vector2(hw, bot), Vector2(-hw, bot)])
		cone.color = glow
		cone.show_behind_parent = true
		s.add_child(cone)
	return s


# =============================================================================
# Objetos interativos e inimigos
# =============================================================================

## Terminais de lore: list = [[id do JSON, posição], ...]
func _data_terminals(lvl: Node, list: Array) -> void:
	var holder := _holder(lvl, "DataTerminals")
	for e in list:
		var t := _instance("res://scenes/objects/data_terminal.tscn", "Terminal_" + String(e[0]), e[1])
		t.set("entry_id", e[0])
		holder.add_child(t)


## Câmera de segurança. props: facing_left, sweep_min_deg, sweep_max_deg,
## vision_range, fov_deg...
func _camera(parent: Node, dome: bool, node_name: String, pos: Vector2, props: Dictionary) -> Node2D:
	var path := "res://scenes/objects/security_camera_%s.tscn" % ("dome" if dome else "wall")
	var cam := _instance(path, node_name, pos)
	if dome:
		cam.set("model", SecurityCamera.Model.DOME)
	for k in props:
		cam.set(k, props[k])
	parent.add_child(cam)
	return cam


## Guardas patrulhando entre dois pontos:
## list = [[variante "v1"/"v2"/"cyborg", x inicial, chão, waypoint A, waypoint B], ...]
func _guards(lvl: Node, list: Array) -> void:
	var holder := _holder(lvl, "Guards")
	var wps := _holder(lvl, "Waypoints")
	var i := 0
	for g in list:
		i += 1
		var scene := "res://scenes/enemies/cyborg.tscn" if g[0] == "cyborg" else "res://scenes/enemies/guard_%s.tscn" % g[0]
		var guard := _instance(scene, "Guard%d" % i, Vector2(g[1], g[2]))
		holder.add_child(guard)
		var arr: Array[Node2D] = []
		for k in 2:
			var m := Marker2D.new()
			m.name = "G%d_WP%d" % [i, k + 1]
			m.position = Vector2(g[3 + k], g[2])
			wps.add_child(m)
			arr.append(m)
		guard.set("waypoints", arr)


## Saída da fase (LevelExit) apoiada no chão em `pos`.
func _exit(lvl: Node, next_stage: String, pos: Vector2, size: Vector2 = Vector2(120, 40)) -> Area2D:
	var exit := Area2D.new()
	exit.name = "LevelExit"
	exit.set_script(load("res://scripts/core/level_exit.gd"))
	exit.set("next_stage", next_stage)
	exit.position = pos
	exit.add_child(_rect_shape(size, Vector2(0, -size.y / 2.0)))
	lvl.add_child(exit)
	return exit


## Gatilho de diálogo (data/dialogue/*.json): área apoiada no chão em `pos`.
func _dialogue_trigger(lvl: Node, dialogue_id: String, pos: Vector2, size: Vector2 = Vector2(160, 128)) -> Area2D:
	var t := Area2D.new()
	t.name = "Dialogue_" + dialogue_id
	t.set_script(load("res://scripts/core/dialogue_trigger.gd"))
	t.set("dialogue_id", dialogue_id)
	t.position = pos
	t.add_child(_rect_shape(size, Vector2(0, -size.y / 2.0)))
	lvl.add_child(t)
	return t


## Guia passo a passo da SINE (Tutorial.guide) ao entrar na área.
func _tutorial_trigger(lvl: Node, guide_name: String, pos: Vector2, size: Vector2 = Vector2(96, 400)) -> Area2D:
	var t := _dialogue_trigger(lvl, "", pos, size)
	t.name = "Tutorial_" + guide_name
	t.set("guide", guide_name)
	return t


## Placa de saída: texto numa placa escura com borda neon (antes era texto solto
## no ar). `pos` é o canto de cima à esquerda, como no Label.
func _exit_sign(lvl: Node, sign_name: String, text: String, pos: Vector2, color: Color) -> Label:
	var sign := Label.new()
	sign.name = sign_name
	sign.text = text
	sign.position = pos
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", color)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.03, 0.035, 0.05, 0.92)
	plate.border_color = Color(color, 0.8)
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(2)
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 5
	plate.content_margin_bottom = 5
	plate.shadow_color = Color(color, 0.25)
	plate.shadow_size = 6
	sign.add_theme_stylebox_override("normal", plate)
	lvl.add_child(sign)
	return sign


## Varredura de Rotina, Eduardo e toda a interface (HUD, furtividade, hacking, lore).
func _player_and_ui(lvl: Node, spawn: Vector2) -> void:
	var sweep := Node2D.new()
	sweep.name = "RoutineSweep"
	sweep.set_script(load("res://scripts/core/routine_sweep.gd"))
	lvl.add_child(sweep)
	lvl.add_child(_instance_any("res://scenes/player/eduardo.tscn", "Eduardo", spawn))
	lvl.add_child(_instance_any("res://scenes/Hud/HUD.tscn", "HUD"))
	lvl.add_child(_instance_any("res://scenes/ui/stealth_hud.tscn", ""))
	var hacking := _instance_any("res://scenes/hacking_ui/HackingInterface.tscn", "HackingInterface")
	hacking.visible = false
	lvl.add_child(hacking)
	lvl.add_child(_instance_any("res://scenes/ui/lore_reader.tscn", ""))


## Instancia qualquer cena (Node2D, CanvasLayer, Control...). Nome vazio mantém o da cena.
func _instance_any(path: String, node_name: String, pos: Variant = null) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	if node_name != "":
		n.name = node_name
	if pos != null:
		n.set("position", pos)
	return n
