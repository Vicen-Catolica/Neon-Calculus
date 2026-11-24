class_name PulseAttack
extends DuelAttack
## Pulso em anel: um anel de energia sai do núcleo e cresce até as bordas da
## arena. Tem uma brecha (um setor angular sem energia): fique no ângulo dela.
## Com o Protocolo Vance a brecha é maior (a "porta" que ele deixou).

@export var center: Vector2 = Vector2(960, -400)
@export var gap_angle_deg: float = 90.0     # 90 = para baixo
@export var gap_width_deg: float = 50.0
@export var max_radius: float = 1400.0
const THICK := 22.0

var radius: float = 0.0


func start() -> void:
	super.start()
	radius = 0.0


func _tick(_delta: float, k: float) -> void:
	radius = lerpf(60.0, max_radius, k)


func in_gap(world: Vector2) -> bool:
	var ang := rad_to_deg((world - center).angle())
	return absf(wrapf(ang - gap_angle_deg, -180.0, 180.0)) <= gap_width_deg / 2.0


func _hits_player(p: Node2D) -> bool:
	var body := DuelHit.body_rect(p)
	var c := body.get_center()
	if in_gap(c):
		return false
	# O anel toca o corpo se o raio estiver entre a menor e a maior distância do retângulo.
	var near := Vector2(clampf(center.x, body.position.x, body.end.x), clampf(center.y, body.position.y, body.end.y)).distance_to(center)
	var far := 0.0
	for corner in [body.position, Vector2(body.end.x, body.position.y), Vector2(body.position.x, body.end.y), body.end]:
		far = maxf(far, (corner as Vector2).distance_to(center))
	return radius + THICK / 2.0 >= near and radius - THICK / 2.0 <= far


func _draw_attack() -> void:
	var g0 := deg_to_rad(gap_angle_deg + gap_width_deg / 2.0)
	var g1 := deg_to_rad(gap_angle_deg - gap_width_deg / 2.0 + 360.0)
	var lc := to_local(center)
	if phase == Phase.TELEGRAPH:
		var a := _telegraph_alpha()
		draw_arc(lc, 150.0, g0, g1, 48, Color(RED, a), 4.0)
		# a brecha em ciano
		draw_arc(lc, 150.0, deg_to_rad(gap_angle_deg - gap_width_deg / 2.0), deg_to_rad(gap_angle_deg + gap_width_deg / 2.0), 12, Color(0.0, 0.94, 1.0, a), 4.0)
		return
	draw_arc(lc, radius, g0, g1, 96, Color(RED, 0.2), THICK + 12.0)
	draw_arc(lc, radius, g0, g1, 96, Color(RED, 0.9), THICK)
	draw_arc(lc, radius, g0, g1, 96, Color(1, 0.85, 0.85, 0.9), 4.0)
