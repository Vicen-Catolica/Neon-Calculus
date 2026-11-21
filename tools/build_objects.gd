extends "res://tools/stage_builder_base.gd"
## Gera as cenas de objetos compartilhadas entre as fases: guardas (v1/v2),
## câmeras (parede/domo), porta biométrica, quiosque da Axioma, terminal de dados,
## válvula de vapor, esteira, drone de patrulha e a interface de furtividade/lore. Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_objects.tscn
## Reexecutar sobrescreve essas cenas (não edite-as à mão; edite este script).


func _ready() -> void:
	_build_object_scenes()
	print("build_objects: OK")
	get_tree().quit()


func _build_object_scenes() -> void:
	_build_guard("v1", "res://scenes/enemies/guard_v1.tscn")
	_build_guard("v2", "res://scenes/enemies/guard_v2.tscn")
	_build_guard("v2", "res://scenes/enemies/cyborg.tscn", true)
	_build_camera(SecurityCamera.Model.WALL, "res://scenes/objects/security_camera_wall.tscn")
	_build_camera(SecurityCamera.Model.DOME, "res://scenes/objects/security_camera_dome.tscn")
	_build_door()
	_build_kiosk()
	_build_data_terminal()
	_build_steam_valve()
	_build_conveyor()
	_build_drone()
	_build_laser()
	_build_holding_cell()
	_build_light_bridge()
	_build_ui()


## `cyborg`: Unidade Lógica (Fase 3) — sem ouvido, não cai em distração, barra
## de detecção bem mais rápida, hack = ponto cego. Arte provisória: guarda v2
## recolorido (tools/gen_rnd_art.py): armadura branca, visor vermelho da Axioma.
func _build_guard(variant: String, path: String, cyborg: bool = false) -> void:
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
	if cyborg:
		g.name = "Cyborg"
		g.set("enemy_type", Enemy.EnemyType.CYBORG)
		g.set("move_speed", 80.0)
		g.set("vision_range", 340.0)
		g.set("detect_time_far", 0.9)
		g.set("detect_time_near", 0.3)

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
	spr.sprite_frames = load("res://scenes/enemies/cyborg_frames.tres" if cyborg \
		else "res://scenes/enemies/guard_%s_frames.tres" % variant)
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

	g.add_child(_hackable("UNIDADE LÓGICA" if cyborg else "AGENTE", Vector2(0, -90)))
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


func _build_steam_valve() -> void:
	var v := Node2D.new()
	v.name = "SteamValve"
	v.set_script(load("res://scripts/objects/steam_valve.gd"))
	# Hackable no volante (nozzle_height padrão 210 + 46).
	v.add_child(_hackable("VÁLVULA DE VAPOR", Vector2(0, -256)))
	_save(v, "res://scenes/objects/steam_valve.tscn")


func _build_laser() -> void:
	var l := Node2D.new()
	l.name = "LaserBarrier"
	l.set_script(load("res://scripts/objects/laser_barrier.gd"))
	l.add_child(_hackable("BARREIRA LASER", Vector2(0, -182)))
	var beam := Area2D.new()
	beam.name = "Beam"
	beam.monitorable = false
	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	beam.add_child(cs)
	l.add_child(beam)
	_save(l, "res://scenes/objects/laser_barrier.tscn")


func _build_holding_cell() -> void:
	var c := Node2D.new()
	c.name = "HoldingCell"
	c.set_script(load("res://scripts/objects/holding_cell.gd"))
	c.add_child(_hackable("CELA — LAB 07", Vector2(89, -97)))
	var spr := Sprite2D.new()
	spr.name = "Prisoner"
	spr.texture = load("res://assets/props/rnd/vance.png")
	spr.position = Vector2(0, -62 - 4)
	c.add_child(spr)
	_save(c, "res://scenes/objects/holding_cell.tscn")


func _build_light_bridge() -> void:
	var b := Node2D.new()
	b.name = "LightBridge"
	b.set_script(load("res://scripts/objects/light_bridge.gd"))
	b.add_child(_hackable("PONTE DE LUZ", Vector2(6, -18)))
	var body := StaticBody2D.new()
	body.name = "Body"
	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	body.add_child(cs)
	b.add_child(body)
	_save(b, "res://scenes/objects/light_bridge.tscn")


func _build_conveyor() -> void:
	var c := StaticBody2D.new()
	c.name = "Conveyor"
	c.set_script(load("res://scripts/objects/conveyor.gd"))
	c.add_child(_hackable("ESTEIRA", Vector2(0, -24)))
	_save(c, "res://scenes/objects/conveyor.tscn")


func _build_drone() -> void:
	var d := Node2D.new()
	d.name = "PatrolDrone"
	d.set_script(load("res://scripts/enemies/patrol_drone.gd"))
	d.add_child(_hackable("DRONE DE PATRULHA", Vector2(0, 2)))
	_save(d, "res://scenes/enemies/patrol_drone.tscn")


func _build_ui() -> void:
	var lr := CanvasLayer.new()
	lr.name = "LoreReader"
	lr.set_script(load("res://scripts/ui/lore_reader.gd"))
	_save(lr, "res://scenes/ui/lore_reader.tscn")
	var sh := CanvasLayer.new()
	sh.name = "StealthHUD"
	sh.set_script(load("res://scripts/ui/stealth_hud.gd"))
	_save(sh, "res://scenes/ui/stealth_hud.tscn")
