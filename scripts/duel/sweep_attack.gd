class_name SweepAttack
extends DuelAttack
## Varredura do núcleo: uma barra de laser atravessa a arena com uma brecha.
##   DOWN:  barra horizontal desce do teto ao chão; a brecha é uma faixa em x
##          (vá para baixo dela).
##   RIGHT/LEFT: barra vertical cruza a arena; a brecha fica rente ao chão
##          (passe agachado).

enum Dir { DOWN, RIGHT, LEFT }

@export var dir: Dir = Dir.DOWN
## DOWN: centro x da brecha. RIGHT/LEFT: altura da brecha a partir do chão.
@export var gap_center: float = 960.0
@export var gap_size: float = 180.0
@export var floor_y: float = 16.0
const THICK := 16.0
## Altura da brecha rente ao chão nas varreduras laterais: só passa agachado
## (mesma regra dos dutos de 96 px).
const CROUCH_GAP := 96.0

var pos: float = 0.0


func start() -> void:
	super.start()
	pos = _from()


func _from() -> float:
	match dir:
		Dir.DOWN:
			return arena.position.y
		Dir.RIGHT:
			return arena.position.x
		_:
			return arena.end.x


func _to() -> float:
	match dir:
		Dir.DOWN:
			return floor_y
		Dir.RIGHT:
			return arena.end.x
		_:
			return arena.position.x


func _tick(_delta: float, k: float) -> void:
	pos = lerpf(_from(), _to(), k)


## Retângulos da barra (dois, por causa da brecha), em coordenadas globais.
func bar_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if dir == Dir.DOWN:
		var g0 := gap_center - gap_size / 2.0
		var g1 := gap_center + gap_size / 2.0
		out.append(Rect2(arena.position.x, pos - THICK / 2.0, g0 - arena.position.x, THICK))
		out.append(Rect2(g1, pos - THICK / 2.0, arena.end.x - g1, THICK))
	else:
		var gap_top := floor_y - gap_center
		out.append(Rect2(pos - THICK / 2.0, arena.position.y, THICK, gap_top - arena.position.y))
	return out


func _hits_player(p: Node2D) -> bool:
	var body := DuelHit.body_rect(p)
	for r in bar_rects():
		if r.intersects(body):
			return true
	return false


func _draw_attack() -> void:
	if phase == Phase.TELEGRAPH:
		# Aviso: a linha de partida e a brecha marcada.
		var a := _telegraph_alpha()
		if dir == Dir.DOWN:
			for r in bar_rects():
				draw_rect(Rect2(r.position.x, arena.position.y, r.size.x, 4), Color(RED, a))
			draw_rect(Rect2(gap_center - gap_size / 2.0, floor_y - 6, gap_size, 6), Color(0.0, 0.94, 1.0, a))
		else:
			var x0 := arena.position.x if dir == Dir.RIGHT else arena.end.x - 4
			draw_rect(Rect2(x0, arena.position.y, 4, floor_y - gap_center - arena.position.y), Color(RED, a))
			draw_rect(Rect2(arena.position.x, floor_y - gap_center, arena.size.x, 2), Color(0.0, 0.94, 1.0, a * 0.6))
		return
	for r in bar_rects():
		draw_rect(r.grow(6), Color(RED, 0.18))
		draw_rect(r, Color(RED, 0.9))
		draw_rect(r.grow(-THICK * 0.35), Color(1, 0.85, 0.85, 0.9))
