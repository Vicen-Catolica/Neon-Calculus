class_name LaserGridAttack
extends DuelAttack
## Grade de lasers: colunas verticais do teto ao chão em posições avisadas
## antes; fique nos vãos entre elas. (Substitui o "laser giratório" do plano:
## um feixe girando a partir do núcleo não teria como ser desviado no chão.)

@export var columns: Array[float] = [400.0, 800.0, 1200.0, 1600.0]
@export var column_width: float = 70.0


func _init() -> void:
	# Colunas acesas por 1 s: quem fica dentro leva um golpe só.
	active_time = 1.0


func column_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for x in columns:
		out.append(Rect2(x - column_width / 2.0, arena.position.y, column_width, arena.size.y))
	return out


func _hits_player(p: Node2D) -> bool:
	var body := DuelHit.body_rect(p)
	for r in column_rects():
		if r.intersects(body):
			return true
	return false


func _draw_attack() -> void:
	for r in column_rects():
		var lr := Rect2(to_local(r.position), r.size)
		if phase == Phase.TELEGRAPH:
			var a := _telegraph_alpha()
			draw_rect(lr, Color(RED, a * 0.25))
			draw_rect(Rect2(lr.position.x + lr.size.x / 2.0 - 1, lr.position.y, 2, lr.size.y), Color(RED, a))
		else:
			draw_rect(lr, Color(RED, 0.25))
			draw_rect(lr.grow_individual(-lr.size.x * 0.3, 0, -lr.size.x * 0.3, 0), Color(RED, 0.85))
			draw_rect(lr.grow_individual(-lr.size.x * 0.45, 0, -lr.size.x * 0.45, 0), Color(1, 0.85, 0.85, 0.9))
